import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/recipe.dart';
import '../models/user_profile.dart';
import '../services/model_manager.dart';
import '../services/local_db_service.dart';
import '../services/recipe_export_service.dart';
import '../models/chat_message.dart';
import '../models/model_status.dart';
import '../services/hybrid_ai_service.dart';

class RecipeViewModel extends ChangeNotifier {
  final ModelManager _modelManager;
  final LocalDbService _db = LocalDbService.instance;
  final RecipeExportService _export = RecipeExportService();
  final _uuid = const Uuid();

  List<Recipe> _recipes = [];
  List<Recipe> _favorites = [];
  List<Recipe> _searchResults = [];
  int _offset = 0;
  bool _hasMore = true;
  String? _selectedLetter;
  String _selectedFilter = 'All';
  bool _isLoadingMore = false;
  
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isGenerating = false;
  String? _generatedRecipe;
  String? _errorMessage;
  String _lastIngredientInput = '';
  String _dietaryPreference = '';
  bool _makeItHealthy = false;

  List<Recipe> get recipes => _recipes;
  List<Recipe> get favorites => _favorites;
  List<Recipe> get searchResults => _searchResults;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  String? get generatedRecipe => _generatedRecipe;
  String? get errorMessage => _errorMessage;
  String get lastIngredientInput => _lastIngredientInput;
  String get dietaryPreference => _dietaryPreference;
  bool get makeItHealthy => _makeItHealthy;
  RecipeExportService get exportService => _export;
  
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  String? get selectedLetter => _selectedLetter;
  String get selectedFilter => _selectedFilter;

  RecipeViewModel(this._modelManager);

  Future<void> loadRecipes({bool refresh = false}) async {
    if (refresh) {
      _offset = 0;
      _hasMore = true;
    }
    if (!_hasMore || (_isLoading && !refresh)) return;

    if (refresh) _isLoading = true;
    if (!refresh) _isLoadingMore = true;
    notifyListeners();

    final newRecipes = await _db.getFilteredRecipes(
      query: _searchQuery,
      letter: _selectedLetter,
      filter: _selectedFilter,
      limit: 20,
      offset: _offset,
    );

    if (refresh) {
      _recipes = newRecipes;
    } else {
      _recipes.addAll(newRecipes);
    }

    _hasMore = newRecipes.length == 20;
    _offset += newRecipes.length;

    if (refresh) _favorites = await _db.getFavoriteRecipes();

    _isLoading = false;
    _isLoadingMore = false;
    notifyListeners();
  }

  void setFilters({String? letter, String? filter, String? query, bool clearLetter = false}) {
    bool changed = false;
    if (letter != null || clearLetter) {
      _selectedLetter = clearLetter ? null : letter;
      changed = true;
    }
    if (filter != null) {
      _selectedFilter = filter;
      changed = true;
    }
    if (query != null) {
      _searchQuery = query;
      changed = true;
    }
    if (changed) {
      loadRecipes(refresh: true);
    }
  }

  Future<void> search(String query) async {
    _searchQuery = query;
    if (query.isEmpty) {
      _searchResults = [];
    } else {
      _searchResults = await _db.searchRecipes(query);
    }
    notifyListeners();
  }

  Future<void> toggleFavorite(String recipeId) async {
    await _db.toggleFavorite(recipeId);
    _favorites = await _db.getFavoriteRecipes();
    final idx = _recipes.indexWhere((r) => r.id == recipeId);
    if (idx != -1) {
      _recipes[idx] = _recipes[idx].copyWith(isFavorite: !_recipes[idx].isFavorite);
    }
    notifyListeners();
  }

  Future<void> deleteRecipe(String recipeId) async {
    await _db.deleteRecipe(recipeId);
    await loadRecipes();
  }

  Future<String> generateRecipeFromIngredients({
    required String ingredients,
    String? preference,
    bool healthy = false,
    UserProfile? profile,
  }) async {
    if (_modelManager.status != ModelStatus.ready) {
      _errorMessage = 'AI Engine initializing. Please try again in a moment.';
      notifyListeners();
      return '';
    }

    _isGenerating = true;
    _generatedRecipe = null;
    _errorMessage = null;
    _lastIngredientInput = ingredients;
    _dietaryPreference = preference ?? '';
    _makeItHealthy = healthy;
    notifyListeners();

    try {
      String prompt = 'You are ChowGenie, an expert AI chef. ';
      prompt += 'Given these ingredients: $ingredients.';

      if (preference != null && preference.isNotEmpty) {
        prompt += '\nDietary preference: $preference.';
      }

      if (healthy) {
        prompt += '\nMake it healthy: reduce oil, add vegetables, suggest whole grain alternatives.';
      }

      if (profile != null && profile.healthConditions.isNotEmpty) {
        prompt += '\nUser has: ${profile.healthConditions.join(", ")}.';
        prompt += ' Avoid: ${profile.allergies.join(", ")}.';
        prompt += ' Target ${profile.dailyCalorieGoal.toStringAsFixed(0)} calories/day.';
      }

      prompt += '\nGenerate a complete recipe in a clean Markdown format (DO NOT use literal square brackets like [Title] or [Ingredients] in your response, use standard markdown headings instead):\n'
          '# Recipe Title\n'
          '**Calories:** [number] kcal per serving\n'
          '**Cooking Time:** [number] minutes\n'
          '## Ingredients\n'
          'List ingredients with bullet points\n'
          '## Directions\n'
          'List step-by-step instructions with numbers\n'
          '**Spice Level:** [1-5]/5\n'
          '## Cooking Tips\n'
          'List 3 cooking tips';

      final history = <ChatMessage>[];
      history.add(ChatMessage.system(
        content: 'You are ChowGenie, an expert AI chef. Generate only food recipes.',
      ));

      final response = await _modelManager.generateResponse(prompt, history: history);
      _generatedRecipe = response ?? 'Failed to generate recipe.';
    } catch (e) {
      _errorMessage = 'Error: $e';
      _generatedRecipe = null;
    }

    _isGenerating = false;
    notifyListeners();
    return _generatedRecipe ?? '';
  }

  Future<String> generateRecipeFromImage(String imagePath) async {
    if (_modelManager.status != ModelStatus.ready) {
      _errorMessage = 'Model not ready.';
      notifyListeners();
      return '';
    }

    _isGenerating = true;
    _generatedRecipe = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final file = File(imagePath);
      if (!file.existsSync()) throw Exception('Image not found');
      final bytes = await file.readAsBytes();

      final prompt = 'Analyze this food/ingredient image. Identify all visible items. '
          'Then suggest a recipe that can be made with these ingredients. '
          'Format: # Title\n## Ingredients\n## Directions\n**Cooking Time:** [number] min\n**Calories:** [number] kcal\n(DO NOT use literal square brackets in your output)';

      final response = await _modelManager.generateMultimodalResponse(prompt, bytes);
      _generatedRecipe = response ?? 'Could not identify the food.';
    } catch (e) {
      _errorMessage = 'Error: $e';
    }

    _isGenerating = false;
    notifyListeners();
    return _generatedRecipe ?? '';
  }

  Recipe parseRecipeText(String text, String id, String titleFallback) {
    final lines = text.split('\n');
    String title = '';
    final List<String> ingredients = [];
    final List<String> directions = [];
    double? calories;
    int? cookingTime;
    int? spiceLevel;

    String currentSection = '';

    String cleanLine(String line) {
      return line
          .replaceAll(RegExp(r'^[\s#*>\-\d+\.\s]+'), '')
          .replaceAll(RegExp(r'[\[\]]'), '')
          .trim();
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final lowerLine = line.toLowerCase();

      // Check section headers
      if (lowerLine.contains('ingredients')) {
        currentSection = 'ingredients';
        continue;
      } else if (lowerLine.contains('step-by-step') || lowerLine.contains('directions') || lowerLine.contains('instructions')) {
        currentSection = 'directions';
        continue;
      } else if (lowerLine.contains('cooking tips') || lowerLine.contains('tips')) {
        currentSection = 'tips';
        continue;
      }

      // Metadata extraction
      if (lowerLine.contains('calories')) {
        final match = RegExp(r'\d+').firstMatch(line);
        if (match != null) {
          calories = double.tryParse(match.group(0)!);
        }
        continue;
      } else if (lowerLine.contains('cooking time') || lowerLine.contains('cook time')) {
        final match = RegExp(r'\d+').firstMatch(line);
        if (match != null) {
          cookingTime = int.tryParse(match.group(0)!);
        }
        continue;
      } else if (lowerLine.contains('spice level')) {
        final match = RegExp(r'\d+').firstMatch(line);
        if (match != null) {
          spiceLevel = int.tryParse(match.group(0)!);
        }
        continue;
      }

      // Title detection
      if (title.isEmpty) {
        if (!line.startsWith('[') && !line.startsWith('##') && !lowerLine.contains('calories') && !lowerLine.contains('time')) {
          title = cleanLine(line);
          continue;
        } else if (line.startsWith('[')) {
          title = cleanLine(line);
          continue;
        }
      }

      // Collect section items
      if (currentSection == 'ingredients') {
        if (line.startsWith('*') || line.startsWith('-') || line.startsWith('•')) {
          ingredients.add(line.replaceFirst(RegExp(r'^[\*\-•]\s*'), '').trim());
        } else {
          ingredients.add(line);
        }
      } else if (currentSection == 'directions') {
        directions.add(line.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim());
      } else if (currentSection == 'tips') {
        directions.add('Tip: ${line.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim()}');
      }
    }

    if (title.isEmpty) {
      title = cleanLine(titleFallback);
    }
    if (ingredients.isEmpty) {
      ingredients.add('Check directions');
    }
    if (directions.isEmpty) {
      directions.add(text);
    }

    return Recipe(
      id: id,
      title: title,
      ingredients: ingredients,
      directions: directions,
      calories: calories,
      cookingTimeMinutes: cookingTime,
      spiceLevel: spiceLevel,
      isUserGenerated: true,
      createdAt: DateTime.now(),
    );
  }

  Future<Recipe?> saveGeneratedRecipe(String title) async {
    if (_generatedRecipe == null) return null;
    final parsed = parseRecipeText(_generatedRecipe!, _uuid.v4(), title);
    await _db.insertRecipe(parsed);
    await loadRecipes();
    return parsed;
  }

  Future<Recipe?> saveCustomRecipe(String title, String recipeText) async {
    final parsed = parseRecipeText(recipeText, _uuid.v4(), title);
    await _db.insertRecipe(parsed);
    await loadRecipes();
    return parsed;
  }

  Future<void> saveImportedRecipe(Recipe recipe) async {
    await _db.insertRecipe(recipe);
    await loadRecipes(refresh: true);
  }

  Future<String> askAiAboutRecipe({
    required Recipe recipe,
    required String question,
    required List<ChatMessage> chatHistory,
  }) async {
    if (_modelManager.status != ModelStatus.ready) {
      return 'AI Model is not ready yet.';
    }

    final List<ChatMessage> fullHistory = [];
    
    // Inject recipe context
    final recipeContext = 'Recipe Title: ${recipe.title}\n'
        'Ingredients:\n${recipe.ingredients.map((i) => "- $i").join("\n")}\n'
        'Directions:\n${recipe.directions.map((d) => "- $d").join("\n")}';
    
    fullHistory.add(ChatMessage.system(
      content: 'You are ChowGenie, an expert AI chef. The user wants to ask questions or customize this recipe:\n\n$recipeContext\n\nProvide direct, helpful, and concise culinary guidance. Answer the user question contextually.',
    ));
    fullHistory.addAll(chatHistory);

    try {
      final response = await _modelManager.generateResponse(question, history: fullHistory);
      return response ?? 'Failed to get answer from AI chef.';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<Recipe?> saveConversationAsRecipe({
    required Recipe originalRecipe,
    required List<ChatMessage> chatHistory,
  }) async {
    if (_modelManager.status != ModelStatus.ready) return null;

    final historyText = chatHistory.map((m) {
      final role = m.type == MessageType.user ? 'User' : 'ChowGenie';
      return '$role: ${m.content}';
    }).join('\n\n');

    final originalRecipeText = 'Title: ${originalRecipe.title}\n'
        'Ingredients:\n${originalRecipe.ingredients.map((i) => "- $i").join("\n")}\n'
        'Directions:\n${originalRecipe.directions.map((d) => "- $d").join("\n")}';

    final prompt = 'Based on the original recipe:\n$originalRecipeText\n\n'
        'And this customization conversation:\n$historyText\n\n'
        'Generate a single consolidated recipe that incorporates all discussed changes.\n'
        'Format in clean Markdown: use # Title, ## Ingredients, and ## Directions. Do NOT use literal square brackets.';

    try {
      final response = await _modelManager.generateResponse(prompt);
      if (response != null) {
        final title = 'Modified ${originalRecipe.title}';
        final parsed = parseRecipeText(response, _uuid.v4(), title);
        await _db.insertRecipe(parsed);
        await loadRecipes();
        return parsed;
      }
    } catch (_) {}
    return null;
  }

  /// Feature 3: One-Tap Recipe "Transforms" (Gemini Nano On-Device)
  /// Instantly adapts recipes to Vegan, High-Protein, Gluten-Free, Budget Swap, or Quick 15m.
  Future<Recipe?> transformRecipe({
    required Recipe recipe,
    required String transformType,
  }) async {
    _isGenerating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prompt = '''You are ChowGenie, an expert AI chef powered by Firebase AI Logic.
Transform this recipe into an authentic "$transformType" version.
Original Recipe:
Title: ${recipe.title}
Ingredients:
${recipe.ingredients.map((i) => "- $i").join("\n")}
Directions:
${recipe.directions.map((d) => "- $d").join("\n")}

Respond ONLY in clean Markdown:
# ${recipe.title} ($transformType)
**Calories:** [number] kcal
**Cooking Time:** [number] mins
## Ingredients
- [List modified ingredients with accurate quantities]
## Directions
1. [Step-by-step instructions adapted for $transformType]
**Spice Level:** [1-5]/5
## Cooking Tips
- [Culinary tip for this variation]
''';

      final result = await HybridAiService.instance.generateContent(prompt: prompt);
      final newTitle = '${recipe.title} ($transformType)';
      final transformed = parseRecipeText(result.text, _uuid.v4(), newTitle);

      _isGenerating = false;
      notifyListeners();
      return transformed;
    } catch (e) {
      _errorMessage = 'Failed to transform recipe: $e';
      _isGenerating = false;
      notifyListeners();
      return null;
    }
  }
}
