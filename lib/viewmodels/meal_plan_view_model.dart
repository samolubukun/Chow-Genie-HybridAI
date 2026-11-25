import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/meal_plan.dart';
import '../models/user_profile.dart';
import '../models/shopping_item.dart';
import '../models/recipe.dart';
import '../services/model_manager.dart';
import '../services/local_db_service.dart';
import '../models/model_status.dart';

class MealPlanViewModel extends ChangeNotifier {
  final ModelManager _modelManager;
  final LocalDbService _db = LocalDbService.instance;
  final _uuid = const Uuid();

  List<MealPlanEntry> _entries = [];
  List<MealPlanEntry> _preppedEntries = [];
  String? _generatedPlan;
  String? _generatedPrepTimeline;
  bool _isGenerating = false;
  bool _isLoading = false;
  DateTime _currentWeekStart = _weekStart(DateTime.now());

  List<MealPlanEntry> get entries => _entries;
  List<MealPlanEntry> get preppedEntries => _preppedEntries;
  String? get generatedPlan => _generatedPlan;
  String? get generatedPrepTimeline => _generatedPrepTimeline;
  bool get isGenerating => _isGenerating;
  bool get isLoading => _isLoading;
  DateTime get currentWeekStart => _currentWeekStart;

  static DateTime _weekStart(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  MealPlanViewModel(this._modelManager);

  Future<void> loadWeek({DateTime? date}) async {
    _isLoading = true;
    notifyListeners();
    if (date != null) _currentWeekStart = _weekStart(date);
    final rawEntries = await _db.getMealPlanEntries(_currentWeekStart);

    // Deduplicate repeated entries for the same slot if duplicated previously
    final uniqueEntries = <MealPlanEntry>[];
    final seenKeys = <String>{};
    for (final e in rawEntries) {
      final key = '${e.date.toIso8601String().split('T')[0]}_${e.mealType.name}_${e.recipeTitle.toLowerCase().trim()}';
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        uniqueEntries.add(e);
      } else {
        // Clean up redundant duplicate row in database
        _db.deleteMealPlanEntry(e.id);
      }
    }

    _entries = uniqueEntries;
    _preppedEntries = _entries.where((e) => e.isPrepped).toList();
    _generatedPlan = await _db.getGeneratedWeeklyPlan(_currentWeekStart);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> navigateWeek(int weeks) async {
    final newStart = _currentWeekStart.add(Duration(days: 7 * weeks));
    await loadWeek(date: newStart);
  }

  Future<void> addEntry(MealPlanEntry entry) async {
    await _db.insertMealPlanEntry(entry);
    await loadWeek();
  }

  Future<void> removeEntry(String id) async {
    await _db.deleteMealPlanEntry(id);
    await loadWeek();
  }

  Future<void> togglePrepped(String id) async {
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final updated = _entries[idx].copyWith(isPrepped: !_entries[idx].isPrepped);
      await _db.insertMealPlanEntry(updated);
      await loadWeek();
    }
  }

  Future<int> applyWeeklyPlanEntries(List<MealPlanEntry> entries, {bool replaceWeek = true}) async {
    if (replaceWeek) {
      await _db.clearMealPlanEntriesForWeek(_currentWeekStart);
    }
    for (final entry in entries) {
      await _db.insertMealPlanEntry(entry);
    }
    await loadWeek();
    return entries.length;
  }

  Future<void> clearGeneratedPlan() async {
    _generatedPlan = null;
    await _db.saveGeneratedWeeklyPlan(_currentWeekStart, '');
    notifyListeners();
  }

  Future<String> generateWeeklyPlan(UserProfile? profile) async {
    _isGenerating = true;
    _generatedPlan = null;
    notifyListeners();

    try {
      String prompt = '''You are ChowGenie, an expert AI culinary nutritionist.
Generate a structured, personalized 7-day weekly meal plan (Monday to Sunday) with Breakfast, Lunch, Dinner, and Snack for each day.
Format each day strictly like this:

### Monday
- Breakfast: [Meal Name & Brief Description]
- Lunch: [Meal Name & Brief Description]
- Dinner: [Meal Name & Brief Description]
- Snack: [Healthy Snack]

### Tuesday
- Breakfast: [Meal Name & Brief Description]
- Lunch: [Meal Name & Brief Description]
- Dinner: [Meal Name & Brief Description]
- Snack: [Healthy Snack]

(Repeat strictly for Wednesday, Thursday, Friday, Saturday, Sunday)
Make all meals creative, balanced, delicious, and strictly aligned with user preferences.
''';

      if (profile != null) {
        prompt += '\nUser profile: ${profile.healthSummary}';
        prompt += '\nDiet preferences: ${profile.dietaryPreferences.join(", ")}';
        if (profile.allergies.isNotEmpty) {
          prompt += '\nAllergies to strictly avoid: ${profile.allergies.join(", ")}';
        }
      }

      final response = await _modelManager.generateResponse(prompt);
      if (response != null && response.isNotEmpty) {
        _generatedPlan = response;
        await _db.saveGeneratedWeeklyPlan(_currentWeekStart, response);
      } else {
        _generatedPlan = 'Failed to generate plan.';
      }
    } catch (e) {
      _generatedPlan = 'Error: $e';
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
    return _generatedPlan ?? '';
  }

  Future<String> generatePrepTimeline({
    required List<MealPlanEntry> weekEntries,
    required String availableTime,
    UserProfile? profile,
  }) async {
    _isGenerating = true;
    _generatedPrepTimeline = null;
    notifyListeners();

    try {
      final meals = weekEntries.map((e) =>
          '${e.date.toIso8601String().split('T')[0]} - ${e.mealType.name}: ${e.recipeTitle}'
      ).join('\n');

      String prompt = 'Create a meal prep timeline for:\n$meals\n';
      prompt += 'Available prep time: $availableTime\n';
      prompt += 'Provide a step-by-step prep schedule with times.';

      if (profile != null) {
        prompt += '\nConsider: ${profile.healthSummary}';
      }

      final response = await _modelManager.generateResponse(prompt);
      _generatedPrepTimeline = response ?? 'Failed to generate timeline.';
    } catch (e) {
      _generatedPrepTimeline = 'Error: $e';
    }

    _isGenerating = false;
    notifyListeners();
    return _generatedPrepTimeline ?? '';
  }

  Future<String> analyzeNutrition(UserProfile? profile) async {
    if (_entries.isEmpty) return 'No meals planned.';

    final meals = _entries.map((e) =>
        '${e.mealType.name}: ${e.recipeTitle} (${e.estimatedCalories?.toStringAsFixed(0) ?? "?"} cal)'
    ).join('\n');

    String prompt = 'Analyze this weekly meal plan for nutritional balance:\n$meals\n';
    prompt += 'Identify deficiencies and suggest improvements.';

    if (profile != null) {
      prompt += '\nUser target: ${profile.dailyCalorieGoal.toStringAsFixed(0)} cal/day, '
          'Protein: ${profile.dailyProteinGoal.toStringAsFixed(0)}g, '
          'Carbs: ${profile.dailyCarbsGoal.toStringAsFixed(0)}g, '
          'Fat: ${profile.dailyFatGoal.toStringAsFixed(0)}g';
    }

    return await _modelManager.generateResponse(prompt) ?? '';
  }

  /// Feature 4: Smart Missing-Item Shopping List
  /// Scans all scheduled meals in the current week, cross-checks against pantry stock,
  /// and utilizes Hybrid AI (Gemini Nano / Gemini Flash) to generate clean, consolidated
  /// grocery shopping list items (excluding pantry inventory).
  Future<Map<String, dynamic>> generateSmartShoppingList() async {
    _isLoading = true;
    notifyListeners();

    try {
      final pantryItems = await _db.getPantryItems();
      final pantryNames = pantryItems.map((p) => p.name.toLowerCase().trim()).toList();

      final List<String> missingItems = [];
      int pantryCount = 0;

      // Prepare meal summaries and pantry descriptions
      final mealsDescription = _entries.map((e) =>
        '- ${e.mealType.name.toUpperCase()} (${e.date.toIso8601String().split('T')[0]}): ${e.recipeTitle}'
      ).join('\n');
      final pantryDescription = pantryItems.isEmpty ? 'Pantry is currently empty' : pantryItems.map((p) => p.name).join(', ');

      // 1. Hybrid AI Analysis (Gemini Nano on-device / Gemini Flash cloud fallback)
      bool aiSucceeded = false;
      if (_entries.isNotEmpty) {
        final aiPrompt = '''You are ChowGenie, an expert AI grocery planning and culinary assistant.
Analyze these planned meals for the week and the user's pantry inventory to generate a clean, practical grocery shopping list.

PLANNED MEALS FOR THE WEEK:
$mealsDescription

CURRENT PANTRY INVENTORY (DO NOT BUY THESE IF ALREADY OWNED):
$pantryDescription

STRICT RULES:
1. Identify all core culinary ingredients needed to cook these planned meals.
2. Standardize every ingredient into clean, concise grocery store product names:
   - Convert "a small wedge of sharp cheddar cheese" -> "Sharp Cheddar Cheese"
   - Convert "a ripe pear" -> "Pears"
   - Convert "a drizzle of zucchini" -> "Zucchini"
   - Convert "a drizzle of extra virgin olive oil" -> "Olive Oil"
   - Convert "1.5 lbs boneless skinless chicken breast" -> "Chicken Breast"
3. DO NOT include any item that the user already has in their pantry inventory.
4. Consolidate duplicates so each grocery item appears once with standard grocery naming.
5. Return ONLY a valid JSON object strictly matching this schema:
{
  "pantryFoundCount": 2,
  "missingItems": [
    {"name": "Sharp Cheddar Cheese", "quantity": 1, "unit": "pack"},
    {"name": "Pears", "quantity": 3, "unit": "pieces"},
    {"name": "Zucchini", "quantity": 2, "unit": "pieces"}
  ]
}
Do not write markdown fences, conversational notes, or preamble. Output valid JSON only.''';

        try {
          final aiResponse = await _modelManager.generateResponse(aiPrompt);
          if (aiResponse != null && aiResponse.isNotEmpty) {
            String cleaned = aiResponse.trim();
            if (cleaned.startsWith('```')) {
              final lines = cleaned.split('\n');
              if (lines.isNotEmpty && lines.first.startsWith('```')) lines.removeAt(0);
              if (lines.isNotEmpty && lines.last.startsWith('```')) lines.removeLast();
              cleaned = lines.join('\n').trim();
            }

            final jsonStart = cleaned.indexOf('{');
            final jsonEnd = cleaned.lastIndexOf('}');
            if (jsonStart != -1 && jsonEnd != -1) {
              cleaned = cleaned.substring(jsonStart, jsonEnd + 1);
            }

            final data = jsonDecode(cleaned) as Map<String, dynamic>;
            pantryCount = (data['pantryFoundCount'] as num?)?.toInt() ?? 0;
            final rawMissing = data['missingItems'] as List? ?? [];

            for (final item in rawMissing) {
              String name = '';
              double qty = 1.0;
              String unit = 'unit';

              if (item is Map) {
                name = item['name']?.toString().trim() ?? '';
                qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
                unit = item['unit']?.toString().trim() ?? 'unit';
              } else if (item is String) {
                name = item.trim();
              }

              final normalized = _normalizeGroceryItem(name);
              if (normalized.isNotEmpty && !missingItems.contains(normalized)) {
                missingItems.add(normalized);
                final shoppingItem = ShoppingItem(
                  id: _uuid.v4(),
                  name: normalized,
                  quantity: qty,
                  unit: unit,
                  source: ShoppingItemSource.mealPlan,
                  createdAt: DateTime.now(),
                );
                await _db.insertShoppingItem(shoppingItem);
              }
            }

            if (missingItems.isNotEmpty) {
              aiSucceeded = true;
            }
          }
        } catch (aiError) {
          if (kDebugMode) {
            print('[MealPlanViewModel] AI grocery generation fallback: $aiError');
          }
        }
      }

      // 2. Offline / Heuristic Fallback with smart culinary cleaning
      if (!aiSucceeded) {
        final allIngredients = <String>[];
        for (final entry in _entries) {
          Recipe? recipe;
          if (entry.recipeId.isNotEmpty) {
            recipe = await _db.getRecipe(entry.recipeId);
          }
          if (recipe != null && recipe.ingredients.isNotEmpty) {
            allIngredients.addAll(recipe.ingredients);
          } else {
            final extracted = _extractIngredientsFromTitle(entry.recipeTitle);
            allIngredients.addAll(extracted);
          }
        }

        final List<String> inPantryItems = [];
        for (final ing in allIngredients) {
          final clean = _normalizeGroceryItem(ing);
          if (clean.isEmpty) continue;
          final cleanLower = clean.toLowerCase();

          final existsInPantry = pantryNames.any((p) =>
              p.contains(cleanLower) ||
              cleanLower.contains(p) ||
              (cleanLower.length > 3 && p.split(' ').any((word) => word.length > 2 && cleanLower.contains(word))));

          if (existsInPantry) {
            if (!inPantryItems.contains(clean)) inPantryItems.add(clean);
          } else {
            if (!missingItems.contains(clean)) {
              missingItems.add(clean);
              final shoppingItem = ShoppingItem(
                id: _uuid.v4(),
                name: clean,
                quantity: 1,
                unit: 'unit',
                source: ShoppingItemSource.mealPlan,
                createdAt: DateTime.now(),
              );
              await _db.insertShoppingItem(shoppingItem);
            }
          }
        }
        pantryCount = inPantryItems.length;
      }

      _isLoading = false;
      notifyListeners();

      return {
        'mealCount': _entries.length,
        'pantryCount': pantryCount,
        'missingAdded': missingItems,
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {
        'mealCount': _entries.length,
        'pantryCount': 0,
        'missingAdded': <String>[],
        'error': e.toString(),
      };
    }
  }

  String _normalizeGroceryItem(String raw) {
    String clean = raw
        .replaceAll(RegExp(r'^\d+(\/\d+|\.\d+)?\s*(cups?|tbsp|tsp|tablespoons?|teaspoons?|g|kg|ml|oz|ounces?|lbs?|pounds?|cloves?|pinches?|pinch|cans?|pack|pieces?|bunch|slices?|stalks?|sprigs?)?\s*(of\s*)?', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(a small wedge of|a wedge of|a drizzle of|a pinch of|a handful of|a ripe|freshly chopped|chopped|diced|minced|sliced|grated|peeled|cooked|warm|cold|raw|organic|fresh|extra virgin)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\*\-•\(\)\[\]]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (clean.isEmpty || clean.length < 2) return '';
    return clean.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '').join(' ').trim();
  }

  List<String> _extractIngredientsFromTitle(String title) {
    if (title.trim().isEmpty) return [];

    String cleaned = title
        .replaceAll(RegExp(r'\b(fresh|steamed|baked|grilled|roasted|sauteed|sautéed|boiled|crispy|fried|pan-seared|slow-cooked|homemade|healthy|quick|easy|spicy|sweet|warm|creamy)\b', caseSensitive: false), '')
        .trim();

    final parts = cleaned.split(RegExp(r'\s+(?:with|and|&|served with|topped with|over|on|in)\s+', caseSensitive: false));
    final result = <String>[];
    for (final p in parts) {
      final subparts = p.split(',');
      for (var s in subparts) {
        s = s.replaceAll(RegExp(r'[\(\)\[\]\*]'), '').trim();
        if (s.isNotEmpty && s.length > 2) {
          result.add(s);
        }
      }
    }
    return result.isNotEmpty ? result : [title.trim()];
  }

  /// Suggests a single meal tailored to slot & dietary preferences via Hybrid AI
  /// and automatically inserts it into SQLite and the active meal plan.
  Future<MealPlanEntry?> suggestAndAddMealForSlot({
    required MealType type,
    required DateTime date,
    UserProfile? profile,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final typeName = type.name[0].toUpperCase() + type.name.substring(1);
      final dietPrefs = (profile != null && profile.dietaryPreferences.isNotEmpty)
          ? 'Dietary preferences: ${profile.dietaryPreferences.join(", ")}.'
          : '';
      final calGoal = profile != null
          ? 'Target calorie goal per meal around ${(profile.dailyCalorieGoal / 3).round()} kcal.'
          : '';

      final prompt = '''
You are an expert master chef. Create an inspiring, delicious, and healthy new culinary recipe for $typeName.
$dietPrefs $calGoal
Generate a completely original dish with fresh ingredients and step-by-step cooking directions.
Return ONLY valid raw JSON with this exact structure:
{
  "title": "Creative Dish Name",
  "calories": 450,
  "ingredients": ["1 cup ingredient", "2 tbsp ingredient"],
  "directions": ["Step 1 instructions", "Step 2 instructions"]
}
Do not write markdown code fences or extra text, just raw JSON.
''';

      final response = await _modelManager.generateResponse(prompt);
      if (response != null && response.isNotEmpty) {
        String cleaned = response.trim();
        if (cleaned.startsWith('```')) {
          final lines = cleaned.split('\n');
          if (lines.isNotEmpty && lines.first.startsWith('```')) lines.removeAt(0);
          if (lines.isNotEmpty && lines.last.startsWith('```')) lines.removeLast();
          cleaned = lines.join('\n').trim();
        }

        final data = jsonDecode(cleaned) as Map<String, dynamic>;
        final title = data['title']?.toString() ?? '$typeName Suggestion';
        final calories = (data['calories'] as num?)?.toDouble() ?? 450.0;
        final ingredients = (data['ingredients'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final directions = (data['directions'] as List?)?.map((e) => e.toString()).toList() ?? [];

        final recipeId = 'suggested_${_uuid.v4()}';
        final recipe = Recipe(
          id: recipeId,
          title: title,
          ingredients: ingredients,
          directions: directions,
          calories: calories,
          source: 'AI Suggestion',
          isUserGenerated: true,
          createdAt: DateTime.now(),
        );
        await _db.insertRecipe(recipe);

        final entry = MealPlanEntry(
          id: _uuid.v4(),
          recipeId: recipeId,
          recipeTitle: title,
          mealType: type,
          date: date,
          estimatedCalories: calories,
        );

        await _db.insertMealPlanEntry(entry);
        await loadWeek(date: date);
        return entry;
      }
    } catch (e) {
      debugPrint('[MealPlanViewModel] suggestAndAddMealForSlot error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  /// Generates a complete 4-slot meal plan (Breakfast, Lunch, Dinner, Snack) for a specific single day using Hybrid AI.
  Future<List<MealPlanEntry>> generateMealsForDay(DateTime date, {UserProfile? profile}) async {
    _isLoading = true;
    notifyListeners();

    final dayName = DateFormat('EEEE').format(date);
    final results = <MealPlanEntry>[];

    try {
      final dietPrefs = (profile != null && profile.dietaryPreferences.isNotEmpty)
          ? 'Dietary preferences: ${profile.dietaryPreferences.join(", ")}.'
          : '';
      final calGoal = profile != null
          ? 'Daily calorie goal: ${profile.dailyCalorieGoal.round()} kcal.'
          : '';
      final allergies = (profile != null && profile.allergies.isNotEmpty)
          ? 'Allergies to strictly avoid: ${profile.allergies.join(", ")}.'
          : '';

      final prompt = '''You are ChowGenie, an expert AI culinary nutritionist.
Create a complete, delicious, healthy 1-day meal plan for $dayName with 4 slots: Breakfast, Lunch, Dinner, and Snack.
$dietPrefs $calGoal $allergies

Return ONLY valid raw JSON with this exact structure:
{
  "meals": [
    {"slot": "breakfast", "title": "Dish Name", "calories": 400, "ingredients": ["item 1", "item 2"], "directions": ["step 1"]},
    {"slot": "lunch", "title": "Dish Name", "calories": 550, "ingredients": ["item 1", "item 2"], "directions": ["step 1"]},
    {"slot": "dinner", "title": "Dish Name", "calories": 600, "ingredients": ["item 1", "item 2"], "directions": ["step 1"]},
    {"slot": "snack", "title": "Dish Name", "calories": 200, "ingredients": ["item 1", "item 2"], "directions": ["step 1"]}
  ]
}
Do not write markdown fences or extra text, just raw JSON.''';

      final response = await _modelManager.generateResponse(prompt);
      if (response != null && response.isNotEmpty) {
        String cleaned = response.trim();
        if (cleaned.startsWith('```')) {
          final lines = cleaned.split('\n');
          if (lines.isNotEmpty && lines.first.startsWith('```')) lines.removeAt(0);
          if (lines.isNotEmpty && lines.last.startsWith('```')) lines.removeLast();
          cleaned = lines.join('\n').trim();
        }

        final jsonStart = cleaned.indexOf('{');
        final jsonEnd = cleaned.lastIndexOf('}');
        if (jsonStart != -1 && jsonEnd != -1) {
          cleaned = cleaned.substring(jsonStart, jsonEnd + 1);
        }

        final data = jsonDecode(cleaned) as Map<String, dynamic>;
        final mealsList = data['meals'] as List? ?? [];

        for (final m in mealsList) {
          if (m is Map) {
            final slotStr = m['slot']?.toString().toLowerCase() ?? 'breakfast';
            MealType slot = MealType.breakfast;
            if (slotStr.contains('lunch')) slot = MealType.lunch;
            else if (slotStr.contains('dinner')) slot = MealType.dinner;
            else if (slotStr.contains('snack')) slot = MealType.snack;

            final title = m['title']?.toString() ?? 'Daily Meal';
            final cal = (m['calories'] as num?)?.toDouble() ?? 450.0;
            final ingredients = (m['ingredients'] as List?)?.map((e) => e.toString()).toList() ?? [];
            final directions = (m['directions'] as List?)?.map((e) => e.toString()).toList() ?? [];

            final recipeId = 'day_${_uuid.v4()}';
            final recipe = Recipe(
              id: recipeId,
              title: title,
              ingredients: ingredients,
              directions: directions,
              calories: cal,
              source: 'AI Day Plan',
              isUserGenerated: true,
              createdAt: DateTime.now(),
            );
            await _db.insertRecipe(recipe);

            final entry = MealPlanEntry(
              id: _uuid.v4(),
              recipeId: recipeId,
              recipeTitle: title,
              mealType: slot,
              date: date,
              estimatedCalories: cal,
            );

            // Replace existing slot entry
            final existing = _entries.where((e) =>
                e.date.year == date.year &&
                e.date.month == date.month &&
                e.date.day == date.day &&
                e.mealType == slot).toList();
            for (final ex in existing) {
              await _db.deleteMealPlanEntry(ex.id);
            }

            await _db.insertMealPlanEntry(entry);
            results.add(entry);
          }
        }
        await loadWeek(date: date);
      }
    } catch (e) {
      debugPrint('[MealPlanViewModel] generateMealsForDay error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return results;
  }
}
