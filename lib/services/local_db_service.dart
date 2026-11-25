import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/recipe.dart';
import '../models/user_profile.dart';
import '../models/nutrition_info.dart';
import '../models/pantry_item.dart';
import '../models/shopping_item.dart';
import '../models/meal_plan.dart';
import '../models/mesh_peer.dart';
import '../models/mesh_message.dart';
import '../models/ingrediguard_result.dart';

class LocalDbService {
  static final LocalDbService instance = LocalDbService._();
  LocalDbService._();
  Database? _db;

  // SharedPrefs keys (for settings & lightweight data)
  static const _profileKey = 'smf_user_profile';
  static const _intakeKey = 'smf_daily_intake_';
  static const _intakeListKey = 'smf_intake_dates';
  static const _waterKey = 'smf_water_intake_';
  static const _meshIdentityKey = 'smf_mesh_identity';
  static const _modelSetupSkippedKey = 'smf_model_setup_skipped';

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'chowgenie.db');
    
    final exists = await File(path).exists();
    bool shouldCopy = !exists;
    if (exists) {
      try {
        final tempDb = await openDatabase(path, readOnly: true);
        final countResult = await tempDb.rawQuery('SELECT count(*) as count FROM recipes');
        final count = Sqflite.firstIntValue(countResult) ?? 0;
        await tempDb.close();
        if (count < 100) {
          shouldCopy = true;
        }
      } catch (_) {
        shouldCopy = true;
      }
    }

    if (shouldCopy) {
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}
      
      try {
        final data = await rootBundle.load('assets/recipes.db.gz');
        final compressedBytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        final decompressedBytes = gzip.decode(compressedBytes);
        await File(path).writeAsBytes(decompressedBytes, flush: true);
      } catch (e) {
        // Fallback or print error
      }
    }
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> saveGeneratedWeeklyPlan(DateTime weekStart, String plan) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'smf_weekly_plan_${weekStart.toIso8601String().substring(0, 10)}';
    await prefs.setString(key, plan);

    final mealCount = RegExp(r'^\s*[-*]\s*(Breakfast|Lunch|Dinner|Snack)\s*:', multiLine: true, caseSensitive: false)
        .allMatches(plan).length;
    final history = prefs.getStringList('smf_weekly_plan_history') ?? <String>[];
    final record = '${weekStart.toIso8601String().substring(0, 10)}|${weekStart.add(const Duration(days: 6)).toIso8601String().substring(0, 10)}|$mealCount|${DateTime.now().toIso8601String()}';
    history.removeWhere((item) => item.startsWith('${weekStart.toIso8601String().substring(0, 10)}|'));
    history.insert(0, record);
    await prefs.setStringList('smf_weekly_plan_history', history);
  }

  Future<List<Map<String, dynamic>>> getWeeklyPlanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final records = prefs.getStringList('smf_weekly_plan_history') ?? <String>[];
    return records.map((record) {
      final parts = record.split('|');
      return <String, dynamic>{
        'weekStart': parts.isNotEmpty ? parts[0] : '',
        'weekEnd': parts.length > 1 ? parts[1] : '',
        'mealCount': parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
        'createdAt': parts.length > 3 ? parts[3] : '',
      };
    }).toList();
  }

  Future<String?> getGeneratedWeeklyPlan(DateTime weekStart) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'smf_weekly_plan_${weekStart.toIso8601String().substring(0, 10)}';
    return prefs.getString(key);
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        ingredients TEXT NOT NULL,
        directions TEXT NOT NULL,
        tags TEXT,
        source TEXT,
        url TEXT,
        imagePath TEXT,
        calories REAL,
        cookingTimeMinutes INTEGER,
        spiceLevel INTEGER,
        difficulty TEXT,
        dietaryTags TEXT,
        isFavorite INTEGER DEFAULT 0,
        isUserGenerated INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pantry_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        expiryDate TEXT,
        price REAL,
        category TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shopping_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        isChecked INTEGER DEFAULT 0,
        source TEXT,
        sourceRecipeId TEXT,
        category TEXT,
        estimatedPrice REAL,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS meal_plan_entries (
        id TEXT PRIMARY KEY,
        recipeId TEXT NOT NULL,
        recipeTitle TEXT NOT NULL,
        mealType TEXT NOT NULL,
        date TEXT NOT NULL,
        servings INTEGER DEFAULT 1,
        estimatedCalories REAL,
        isPrepped INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS weekly_plans (
        id TEXT PRIMARY KEY,
        weekStart TEXT NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mesh_peers (
        id TEXT PRIMARY KEY,
        displayName TEXT NOT NULL,
        deviceId TEXT,
        connectionMethod TEXT,
        isOnline INTEGER DEFAULT 0,
        lastSeen TEXT NOT NULL,
        publicKey TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mesh_messages (
        id TEXT PRIMARY KEY,
        senderId TEXT NOT NULL,
        senderName TEXT NOT NULL,
        receiverId TEXT,
        groupId TEXT,
        messageType TEXT,
        content TEXT NOT NULL,
        attachmentPath TEXT,
        recipeJson TEXT,
        timestamp TEXT NOT NULL,
        isRead INTEGER DEFAULT 0,
        isDelivered INTEGER DEFAULT 0,
        isRelayed INTEGER DEFAULT 0,
        replyToId TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mesh_groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        creatorId TEXT NOT NULL,
        memberIds TEXT,
        createdAt TEXT NOT NULL,
        inviteCode TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS nutrition_log (
        id TEXT PRIMARY KEY,
        recipeId TEXT,
        recipeTitle TEXT,
        date TEXT NOT NULL,
        calories REAL,
        protein REAL,
        carbs REAL,
        fat REAL,
        fiber REAL,
        mealType TEXT,
        imagePath TEXT,
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_recipes_title ON recipes(title)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_recipes_tags ON recipes(tags)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pantry_name ON pantry_items(name)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_meal_plan_date ON meal_plan_entries(date)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_nutrition_log_date ON nutrition_log(date)
    ''');
  }

  // ==================== RECIPES ====================

  Future<void> insertRecipe(Recipe recipe) async {
    final db = await database;
    final map = recipe.toJson();
    map['ingredients'] = jsonEncode(recipe.ingredients);
    map['directions'] = jsonEncode(recipe.directions);
    map['tags'] = jsonEncode(recipe.tags);
    map['dietaryTags'] = jsonEncode(recipe.dietaryTags ?? []);
    await db.insert('recipes', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertRecipesBatch(List<Recipe> recipes) async {
    final db = await database;
    final batch = db.batch();
    for (final r in recipes) {
      final map = r.toJson();
      map['ingredients'] = jsonEncode(r.ingredients);
      map['directions'] = jsonEncode(r.directions);
      map['tags'] = jsonEncode(r.tags);
      map['dietaryTags'] = jsonEncode(r.dietaryTags ?? []);
      batch.insert('recipes', map, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteRecipe(String id) async {
    final db = await database;
    await db.delete('recipes', where: 'id = ?', whereArgs: [id]);
  }

  Future<Recipe?> getRecipe(String id) async {
    final db = await database;
    final maps = await db.query('recipes', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Recipe.fromJson(maps.first);
  }

  Future<List<Recipe>> getAllRecipes({int? limit, int? offset}) async {
    final db = await database;
    final maps = await db.query('recipes', limit: limit, offset: offset, orderBy: 'isUserGenerated DESC, isFavorite DESC, title ASC');
    return maps.map((m) => Recipe.fromJson(m)).toList();
  }

  Future<List<Recipe>> searchRecipes(String query) async {
    final db = await database;
    final maps = await db.query('recipes',
      where: 'title LIKE ? OR ingredients LIKE ? OR tags LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'isUserGenerated DESC, title ASC',
      limit: 100,
    );
    return maps.map((m) => Recipe.fromJson(m)).toList();
  }

  Future<List<Recipe>> getFilteredRecipes({
    String? query,
    String? letter,
    String filter = 'All',
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;
    
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (query != null && query.isNotEmpty) {
      whereClauses.add('(title LIKE ? OR ingredients LIKE ? OR tags LIKE ?)');
      whereArgs.addAll(['%$query%', '%$query%', '%$query%']);
    }

    if (letter != null && letter.isNotEmpty) {
      whereClauses.add('title LIKE ?');
      whereArgs.add('$letter%');
    }

    if (filter == 'My Recipes') {
      whereClauses.add('isUserGenerated = 1');
    } else if (filter == 'Favorites') {
      whereClauses.add('isFavorite = 1');
    } else if (filter == 'Quick (<30min)') {
      whereClauses.add('cookingTimeMinutes < 30');
    } else if (filter == 'Vegetarian') {
      whereClauses.add('(dietaryTags LIKE ? OR tags LIKE ?)');
      whereArgs.addAll(['%vegetarian%', '%vegetarian%']);
    }

    String? whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final maps = await db.query('recipes',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      limit: limit,
      offset: offset,
      orderBy: 'isUserGenerated DESC, isFavorite DESC, title ASC',
    );
    return maps.map((m) => Recipe.fromJson(m)).toList();
  }

  Future<List<Recipe>> getFavoriteRecipes() async {
    final db = await database;
    final maps = await db.query('recipes', where: 'isFavorite = 1', orderBy: 'title ASC');
    return maps.map((m) => Recipe.fromJson(m)).toList();
  }

  Future<void> toggleFavorite(String recipeId) async {
    final db = await database;
    final recipe = await getRecipe(recipeId);
    if (recipe == null) return;
    await db.update('recipes', {'isFavorite': recipe.isFavorite ? 0 : 1},
      where: 'id = ?', whereArgs: [recipeId]);
  }

  Future<List<Recipe>> getRecipesByIngredients(List<String> ingredients) async {
    final db = await database;
    final all = await db.query('recipes', limit: 500);
    return all.map((m) => Recipe.fromJson(m)).where((r) {
      final recipeIngredients = r.ingredients.map((i) => i.toLowerCase()).join(' ');
      return ingredients.any((ing) => recipeIngredients.contains(ing.toLowerCase()));
    }).toList();
  }

  Future<int> getRecipeCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM recipes');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== PANTRY ====================

  Future<void> insertPantryItem(PantryItem item) async {
    final db = await database;
    await db.insert('pantry_items', item.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PantryItem>> getPantryItems() async {
    final db = await database;
    final maps = await db.query('pantry_items', orderBy: 'name ASC');
    return maps.map((m) => PantryItem.fromJson(m)).toList();
  }

  Future<List<PantryItem>> getExpiringItems() async {
    final items = await getPantryItems();
    return items.where((i) => i.isExpiringSoon || i.isExpired).toList();
  }

  Future<void> deletePantryItem(String id) async {
    final db = await database;
    await db.delete('pantry_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePantryItem(PantryItem item) async {
    final db = await database;
    await db.update('pantry_items', item.toJson(), where: 'id = ?', whereArgs: [item.id]);
  }

  // ==================== SHOPPING LIST ====================

  Future<void> insertShoppingItem(ShoppingItem item) async {
    final db = await database;
    await db.insert('shopping_items', item.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ShoppingItem>> getShoppingItems() async {
    final db = await database;
    final maps = await db.query('shopping_items', orderBy: 'isChecked ASC, createdAt DESC');
    return maps.map((m) => ShoppingItem.fromJson(m)).toList();
  }

  Future<void> toggleShoppingItem(String id) async {
    final db = await database;
    final maps = await db.query('shopping_items', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return;
    final item = ShoppingItem.fromJson(maps.first);
    await db.update('shopping_items', {'isChecked': item.isChecked ? 0 : 1},
      where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteShoppingItem(String id) async {
    final db = await database;
    await db.delete('shopping_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearCheckedItems() async {
    final db = await database;
    await db.delete('shopping_items', where: 'isChecked = 1');
  }

  Future<void> addIngredientsToShoppingList(String recipeId, List<String> ingredients) async {
    final db = await database;
    final batch = db.batch();
    for (final ing in ingredients) {
      batch.insert('shopping_items', {
        'id': 'shop_${DateTime.now().microsecondsSinceEpoch}_${ing.hashCode}',
        'name': ing,
        'quantity': 1,
        'unit': 'unit',
        'isChecked': 0,
        'source': 'recipe',
        'sourceRecipeId': recipeId,
        'createdAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  // ==================== MEAL PLANS ====================

  Future<void> insertMealPlanEntry(MealPlanEntry entry) async {
    final db = await database;
    await db.insert('meal_plan_entries', entry.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearMealPlanEntriesForWeek(DateTime weekStart) async {
    final db = await database;
    final dateStr = weekStart.toIso8601String().split('T')[0];
    final endStr = weekStart.add(const Duration(days: 7)).toIso8601String().split('T')[0];
    await db.delete('meal_plan_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [dateStr, endStr],
    );
  }

  Future<List<MealPlanEntry>> getMealPlanEntries(DateTime weekStart) async {
    final db = await database;
    final dateStr = weekStart.toIso8601String().split('T')[0];
    final endStr = weekStart.add(const Duration(days: 7)).toIso8601String().split('T')[0];
    final maps = await db.query('meal_plan_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [dateStr, endStr],
      orderBy: 'date ASC, mealType ASC',
    );
    return maps.map((m) => MealPlanEntry.fromJson(m)).toList();
  }

  Future<void> deleteMealPlanEntry(String id) async {
    final db = await database;
    await db.delete('meal_plan_entries', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== NUTRITION LOG ====================

  Future<void> logNutrition({
    required String id,
    String? recipeId,
    required String recipeTitle,
    required DateTime date,
    double calories = 0,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
    double fiber = 0,
    String mealType = 'meal',
    String? imagePath,
    String? notes,
  }) async {
    final db = await database;
    await db.insert('nutrition_log', {
      'id': id,
      'recipeId': recipeId,
      'recipeTitle': recipeTitle,
      'date': date.toIso8601String().split('T')[0],
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'mealType': mealType,
      'imagePath': imagePath,
      'notes': notes,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getNutritionLogs(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    return await db.query('nutrition_log',
      where: 'date = ?', whereArgs: [dateStr],
      orderBy: 'mealType ASC',
    );
  }

  Future<Map<String, double>> getDailyTotals(DateTime date) async {
    final logs = await getNutritionLogs(date);
    double cal = 0, pro = 0, carb = 0, fat = 0, fib = 0;
    for (final log in logs) {
      cal += (log['calories'] ?? 0).toDouble();
      pro += (log['protein'] ?? 0).toDouble();
      carb += (log['carbs'] ?? 0).toDouble();
      fat += (log['fat'] ?? 0).toDouble();
      fib += (log['fiber'] ?? 0).toDouble();
    }
    return {'calories': cal, 'protein': pro, 'carbs': carb, 'fat': fat, 'fiber': fib};
  }

  Future<List<Map<String, dynamic>>> getWeeklyLogs(DateTime weekStart) async {
    final db = await database;
    final start = weekStart.toIso8601String().split('T')[0];
    final end = weekStart.add(const Duration(days: 7)).toIso8601String().split('T')[0];
    return await db.query('nutrition_log',
      where: 'date >= ? AND date < ?',
      whereArgs: [start, end],
      orderBy: 'date ASC',
    );
  }

  // ==================== WATER TRACKER ====================

  Future<int> getWaterIntake(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _waterKey + date.toIso8601String().split('T')[0];
    return prefs.getInt(key) ?? 0;
  }

  Future<void> addWaterIntake(DateTime date, int glasses) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _waterKey + date.toIso8601String().split('T')[0];
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + glasses);
  }

  // ==================== MESH PEERS ====================

  Future<void> insertPeer(MeshPeer peer) async {
    final db = await database;
    await db.insert('mesh_peers', peer.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MeshPeer>> getPeers() async {
    final db = await database;
    final maps = await db.query('mesh_peers', orderBy: 'lastSeen DESC');
    return maps.map((m) => MeshPeer.fromJson(m)).toList();
  }

  Future<void> removePeer(String id) async {
    final db = await database;
    await db.delete('mesh_peers', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== MESH MESSAGES ====================

  Future<void> insertMeshMessage(MeshMessage msg) async {
    final db = await database;
    await db.insert('mesh_messages', msg.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MeshMessage>> getMeshMessages(String peerId) async {
    final db = await database;
    final maps = await db.query('mesh_messages',
      where: '(senderId = ? OR receiverId = ?) AND (groupId IS NULL OR groupId = "")',
      whereArgs: [peerId, peerId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => MeshMessage.fromJson(m)).toList();
  }

  Future<List<MeshMessage>> getGroupMessages(String groupId) async {
    final db = await database;
    final maps = await db.query('mesh_messages',
      where: 'groupId = ?', whereArgs: [groupId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => MeshMessage.fromJson(m)).toList();
  }

  Future<List<MeshMessage>> getUndeliveredMessages() async {
    final db = await database;
    final maps = await db.query('mesh_messages',
      where: 'isDelivered = 0',
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => MeshMessage.fromJson(m)).toList();
  }

  Future<void> markMessageDelivered(String id) async {
    final db = await database;
    await db.update('mesh_messages', {'isDelivered': 1}, where: 'id = ?', whereArgs: [id]);
  }

  // ==================== MESH GROUPS ====================

  Future<void> insertGroup(MeshGroup group) async {
    final db = await database;
    await db.insert('mesh_groups', group.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MeshGroup>> getGroups() async {
    final db = await database;
    final maps = await db.query('mesh_groups', orderBy: 'createdAt DESC');
    return maps.map((m) => MeshGroup.fromJson(m)).toList();
  }

  // ==================== LEGACY SHAREDPREFS (PROFILE + INTAKE) ====================

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  Future<UserProfile?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return null;
    return UserProfile.fromJson(jsonDecode(raw));
  }

  Future<bool> hasProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_profileKey);
  }

  Future<bool> isModelSetupSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_modelSetupSkippedKey) ?? false;
  }

  Future<void> setModelSetupSkipped(bool skipped) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_modelSetupSkippedKey, skipped);
  }

  Future<void> saveFoodIntake(NutritionInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _intakeKey + info.date.toIso8601String().split('T')[0];
    final existing = prefs.getString(dateKey);
    final List<dynamic> items = existing != null ? jsonDecode(existing) : [];
    items.add(info.toJson());
    await prefs.setString(dateKey, jsonEncode(items));
    final dates = prefs.getStringList(_intakeListKey) ?? [];
    final dateStr = info.date.toIso8601String().split('T')[0];
    if (!dates.contains(dateStr)) {
      dates.add(dateStr);
      await prefs.setStringList(_intakeListKey, dates);
    }
  }

  Future<List<NutritionInfo>> getFoodIntake(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _intakeKey + date.toIso8601String().split('T')[0];
    final raw = prefs.getString(dateKey);
    if (raw == null) return [];
    final List<dynamic> items = jsonDecode(raw);
    return items.map((e) => NutritionInfo.fromJson(e)).toList();
  }

  Future<Map<String, double>> getTotalNutrients(DateTime date) async {
    final items = await getFoodIntake(date);
    if (items.isEmpty) return {};
    double calories = 0, protein = 0, carbs = 0, fat = 0, fiber = 0;
    for (final item in items) {
      calories += item.calories;
      protein += item.protein;
      carbs += item.carbs;
      fat += item.fat;
      fiber += item.fiber;
    }
    return {'calories': calories, 'protein': protein, 'carbs': carbs, 'fat': fat, 'fiber': fiber};
  }

  Future<List<String>> getDatesWithIntake() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_intakeListKey) ?? [];
  }

  Future<void> deleteFoodIntake(String id, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _intakeKey + date.toIso8601String().split('T')[0];
    final raw = prefs.getString(dateKey);
    if (raw == null) return;
    final List<dynamic> items = jsonDecode(raw);
    items.removeWhere((e) => (e as Map)['id'] == id);
    await prefs.setString(dateKey, jsonEncode(items));
  }

  Future<void> updateFoodIntake(NutritionInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _intakeKey + info.date.toIso8601String().split('T')[0];
    final raw = prefs.getString(dateKey);
    if (raw == null) return;
    final List<dynamic> items = jsonDecode(raw);
    final idx = items.indexWhere((e) => (e as Map)['id'] == info.id);
    if (idx != -1) {
      items[idx] = info.toJson();
      await prefs.setString(dateKey, jsonEncode(items));
    }
  }

  Future<List<NutritionInfo>> getAllScanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final dates = prefs.getStringList(_intakeListKey) ?? [];
    final List<NutritionInfo> all = [];
    for (final dateStr in dates) {
      final dateKey = _intakeKey + dateStr;
      final raw = prefs.getString(dateKey);
      if (raw == null) continue;
      final List<dynamic> items = jsonDecode(raw);
      for (final item in items) {
        final info = NutritionInfo.fromJson(item);
        if (info.source == NutritionSource.scanLabel || info.source == NutritionSource.scanFood) {
          all.add(info);
        }
      }
    }
    return all;
  }

  static const _ingrediGuardKey = 'smf_ingrediguard_scans';

  Future<void> saveIngrediGuardResult(IngrediGuardResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_ingrediGuardKey);
    final List<dynamic> items = existing != null ? jsonDecode(existing) : [];
    items.add(result.toJson());
    await prefs.setString(_ingrediGuardKey, jsonEncode(items));
  }

  Future<List<IngrediGuardResult>> getIngrediGuardHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ingrediGuardKey);
    if (raw == null) return [];
    final List<dynamic> items = jsonDecode(raw);
    return items.map((e) => IngrediGuardResult.fromJson(e)).toList();
  }

  Future<void> clearIngrediGuardHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ingrediGuardKey);
  }

  // ==================== MESH IDENTITY ====================

  Future<Map<String, String>> getMeshIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_meshIdentityKey);
    if (raw != null) return Map<String, String>.from(jsonDecode(raw));
    final id = 'user_${DateTime.now().microsecondsSinceEpoch}';
    final identity = {'id': id, 'displayName': 'Chef_${id.substring(id.length - 4)}'};
    await prefs.setString(_meshIdentityKey, jsonEncode(identity));
    return identity;
  }

  Future<void> setMeshDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final identity = await getMeshIdentity();
    identity['displayName'] = name;
    await prefs.setString(_meshIdentityKey, jsonEncode(identity));
  }

  // ==================== INDEX RECIPES FROM ASSETS ====================

  Future<int> indexRecipesFromAssets() async {
    return await getRecipeCount();
  }

  Future<void> indexRecipeFromAsset(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      final json = jsonDecode(content) as Map<String, dynamic>;
      json['id'] = Recipe.extractIdFromAssetPath(assetPath);
      json['createdAt'] = DateTime.now().subtract(const Duration(days: 365)).toIso8601String();
      final recipe = Recipe.fromJson(json);
      await insertRecipe(recipe);
    } catch (_) {}
  }
}
