import 'dart:convert';
import 'package:flutter/foundation.dart';
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
    _entries = await _db.getMealPlanEntries(_currentWeekStart);
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

  Future<int> applyWeeklyPlanEntries(List<MealPlanEntry> entries) async {
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
  /// and automatically adds missing ingredients to the shopping list.
  Future<Map<String, dynamic>> generateSmartShoppingList() async {
    _isLoading = true;
    notifyListeners();

    try {
      final pantryItems = await _db.getPantryItems();
      final pantryNames = pantryItems.map((p) => p.name.toLowerCase().trim()).toList();

      final allIngredients = <String>[];
      for (final entry in _entries) {
        final recipe = await _db.getRecipe(entry.recipeId);
        if (recipe != null) {
          allIngredients.addAll(recipe.ingredients);
        }
      }

      final List<String> missingItems = [];
      final List<String> inPantryItems = [];

      for (final ing in allIngredients) {
        final clean = ing
            .replaceAll(RegExp(r'^\d+(\/\d+|\.\d+)?\s*(cups?|tbsp|tsp|g|kg|ml|oz|lb|cloves?|pinches?|pinch|cans?|pack|pieces?|bunch)?\s*(of\s*)?', caseSensitive: false), '')
            .replaceAll(RegExp(r'[\*\-•]'), '')
            .trim();

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

      _isLoading = false;
      notifyListeners();

      return {
        'mealCount': _entries.length,
        'pantryCount': inPantryItems.length,
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
}
