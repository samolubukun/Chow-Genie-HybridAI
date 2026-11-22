class UserProfile {
  final String name;
  final int? age;
  final double? weightKg;
  final double? heightCm;
  final String? gender;
  final double dailyCalorieGoal;
  final double dailyProteinGoal;
  final double dailyCarbsGoal;
  final double dailyFatGoal;
  final List<String> healthConditions;
  final List<String> allergies;
  final List<String> dietaryPreferences;
  final List<String> cuisinePreferences;
  final String? dietGoal;
  final double? targetWeightKg;
  final double dailyWaterGoal;
  final bool onboardingComplete;

  const UserProfile({
    required this.name,
    this.age,
    this.weightKg,
    this.heightCm,
    this.gender,
    this.dailyCalorieGoal = 2000,
    this.dailyProteinGoal = 50,
    this.dailyCarbsGoal = 250,
    this.dailyFatGoal = 65,
    this.healthConditions = const [],
    this.allergies = const [],
    this.dietaryPreferences = const [],
    this.cuisinePreferences = const [],
    this.dietGoal,
    this.targetWeightKg,
    this.dailyWaterGoal = 8,
    this.onboardingComplete = false,
  });

  String get healthSummary {
    final parts = <String>[];
    if (healthConditions.isNotEmpty) parts.add('Health: ${healthConditions.join(", ")}');
    if (allergies.isNotEmpty) parts.add('Avoid: ${allergies.join(", ")}');
    if (dietGoal != null) parts.add('Goal: $dietGoal');
    parts.add('Target: ${dailyCalorieGoal.toStringAsFixed(0)} cal/day');
    if (cuisinePreferences.isNotEmpty) parts.add('Cuisine: ${cuisinePreferences.join(", ")}');
    return parts.join('. ');
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
    'weightKg': weightKg,
    'heightCm': heightCm,
    'gender': gender,
    'dailyCalorieGoal': dailyCalorieGoal,
    'dailyProteinGoal': dailyProteinGoal,
    'dailyCarbsGoal': dailyCarbsGoal,
    'dailyFatGoal': dailyFatGoal,
    'healthConditions': healthConditions,
    'allergies': allergies,
    'dietaryPreferences': dietaryPreferences,
    'cuisinePreferences': cuisinePreferences,
    'dietGoal': dietGoal,
    'targetWeightKg': targetWeightKg,
    'dailyWaterGoal': dailyWaterGoal,
    'onboardingComplete': onboardingComplete,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] ?? '',
    age: json['age'],
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    heightCm: (json['heightCm'] as num?)?.toDouble(),
    gender: json['gender'],
    dailyCalorieGoal: (json['dailyCalorieGoal'] ?? 2000).toDouble(),
    dailyProteinGoal: (json['dailyProteinGoal'] ?? 50).toDouble(),
    dailyCarbsGoal: (json['dailyCarbsGoal'] ?? 250).toDouble(),
    dailyFatGoal: (json['dailyFatGoal'] ?? 65).toDouble(),
    healthConditions: List<String>.from(json['healthConditions'] ?? []),
    allergies: List<String>.from(json['allergies'] ?? []),
    dietaryPreferences: List<String>.from(json['dietaryPreferences'] ?? []),
    cuisinePreferences: List<String>.from(json['cuisinePreferences'] ?? []),
    dietGoal: json['dietGoal'],
    targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
    dailyWaterGoal: (json['dailyWaterGoal'] ?? 8).toDouble(),
    onboardingComplete: json['onboardingComplete'] ?? false,
  );

  UserProfile copyWith({
    String? name,
    int? age,
    double? weightKg,
    double? heightCm,
    String? gender,
    double? dailyCalorieGoal,
    double? dailyProteinGoal,
    double? dailyCarbsGoal,
    double? dailyFatGoal,
    List<String>? healthConditions,
    List<String>? allergies,
    List<String>? dietaryPreferences,
    List<String>? cuisinePreferences,
    String? dietGoal,
    double? targetWeightKg,
    double? dailyWaterGoal,
    bool? onboardingComplete,
  }) => UserProfile(
    name: name ?? this.name,
    age: age ?? this.age,
    weightKg: weightKg ?? this.weightKg,
    heightCm: heightCm ?? this.heightCm,
    gender: gender ?? this.gender,
    dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
    dailyProteinGoal: dailyProteinGoal ?? this.dailyProteinGoal,
    dailyCarbsGoal: dailyCarbsGoal ?? this.dailyCarbsGoal,
    dailyFatGoal: dailyFatGoal ?? this.dailyFatGoal,
    healthConditions: healthConditions ?? this.healthConditions,
    allergies: allergies ?? this.allergies,
    dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
    cuisinePreferences: cuisinePreferences ?? this.cuisinePreferences,
    dietGoal: dietGoal ?? this.dietGoal,
    targetWeightKg: targetWeightKg ?? this.targetWeightKg,
    dailyWaterGoal: dailyWaterGoal ?? this.dailyWaterGoal,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
  );
}
