import 'dart:convert';

class Recipe {
  final String id;
  final String title;
  final List<String> ingredients;
  final List<String> directions;
  final List<String> tags;
  final String? source;
  final String? url;
  final String? imagePath;
  final double? calories;
  final int? cookingTimeMinutes;
  final int? spiceLevel;
  final String? difficulty;
  final List<String>? dietaryTags;
  final bool isFavorite;
  final bool isUserGenerated;
  final DateTime createdAt;

  const Recipe({
    required this.id,
    required this.title,
    required this.ingredients,
    required this.directions,
    this.tags = const [],
    this.source,
    this.url,
    this.imagePath,
    this.calories,
    this.cookingTimeMinutes,
    this.spiceLevel,
    this.difficulty,
    this.dietaryTags,
    this.isFavorite = false,
    this.isUserGenerated = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'ingredients': ingredients,
    'directions': directions,
    'tags': tags,
    'source': source,
    'url': url,
    'imagePath': imagePath,
    'calories': calories,
    'cookingTimeMinutes': cookingTimeMinutes,
    'spiceLevel': spiceLevel,
    'difficulty': difficulty,
    'dietaryTags': dietaryTags,
    'isFavorite': isFavorite ? 1 : 0,
    'isUserGenerated': isUserGenerated ? 1 : 0,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final createdAtStr = json['createdAt'] as String?;
    
    List<String> parseList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.cast<String>();
      if (val is String) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) return decoded.cast<String>();
        } catch (_) {}
      }
      return [];
    }

    return Recipe(
      id: json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] ?? 'Untitled',
      ingredients: parseList(json['ingredients']),
      directions: parseList(json['directions']),
      tags: parseList(json['tags']),
      source: json['source'],
      url: json['url'],
      imagePath: json['imagePath'],
      calories: (json['calories'] as num?)?.toDouble(),
      cookingTimeMinutes: json['cookingTimeMinutes'] as int?,
      spiceLevel: json['spiceLevel'] as int?,
      difficulty: json['difficulty'],
      dietaryTags: parseList(json['dietaryTags']),
      isFavorite: json['isFavorite'] == 1 || json['isFavorite'] == true,
      isUserGenerated: json['isUserGenerated'] == 1 || json['isUserGenerated'] == true,
      createdAt: createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now(),
    );
  }

  Recipe copyWith({
    String? id,
    String? title,
    List<String>? ingredients,
    List<String>? directions,
    List<String>? tags,
    String? source,
    String? url,
    String? imagePath,
    double? calories,
    int? cookingTimeMinutes,
    int? spiceLevel,
    String? difficulty,
    List<String>? dietaryTags,
    bool? isFavorite,
    bool? isUserGenerated,
    DateTime? createdAt,
  }) => Recipe(
    id: id ?? this.id,
    title: title ?? this.title,
    ingredients: ingredients ?? this.ingredients,
    directions: directions ?? this.directions,
    tags: tags ?? this.tags,
    source: source ?? this.source,
    url: url ?? this.url,
    imagePath: imagePath ?? this.imagePath,
    calories: calories ?? this.calories,
    cookingTimeMinutes: cookingTimeMinutes ?? this.cookingTimeMinutes,
    spiceLevel: spiceLevel ?? this.spiceLevel,
    difficulty: difficulty ?? this.difficulty,
    dietaryTags: dietaryTags ?? this.dietaryTags,
    isFavorite: isFavorite ?? this.isFavorite,
    isUserGenerated: isUserGenerated ?? this.isUserGenerated,
    createdAt: createdAt ?? this.createdAt,
  );

  static String extractIdFromAssetPath(String assetPath) {
    final uri = Uri.parse(assetPath);
    final segments = uri.pathSegments;
    final filename = segments.last;
    return filename.replaceAll('.json', '');
  }

  static Future<Recipe> fromAsset(String assetPath, String assetContent) async {
    final json = jsonDecode(assetContent) as Map<String, dynamic>;
    json['id'] = extractIdFromAssetPath(assetPath);
    json['createdAt'] = DateTime.now().subtract(const Duration(days: 365)).toIso8601String();
    return Recipe.fromJson(json);
  }
}
