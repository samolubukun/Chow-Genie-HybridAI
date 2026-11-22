enum MealType { breakfast, lunch, dinner, snack }

class MealPlanEntry {
  final String id;
  final String recipeId;
  final String recipeTitle;
  final MealType mealType;
  final DateTime date;
  final int servings;
  final double? estimatedCalories;
  final bool isPrepped;

  const MealPlanEntry({
    required this.id,
    required this.recipeId,
    required this.recipeTitle,
    required this.mealType,
    required this.date,
    this.servings = 1,
    this.estimatedCalories,
    this.isPrepped = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'recipeId': recipeId,
    'recipeTitle': recipeTitle,
    'mealType': mealType.name,
    'date': date.toIso8601String().split('T')[0],
    'servings': servings,
    'estimatedCalories': estimatedCalories,
    'isPrepped': isPrepped ? 1 : 0,
  };

  factory MealPlanEntry.fromJson(Map<String, dynamic> json) => MealPlanEntry(
    id: json['id'] ?? '',
    recipeId: json['recipeId'] ?? '',
    recipeTitle: json['recipeTitle'] ?? '',
    mealType: MealType.values.firstWhere((m) => m.name == json['mealType']),
    date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String().split('T')[0]),
    servings: json['servings'] ?? 1,
    estimatedCalories: (json['estimatedCalories'] as num?)?.toDouble(),
    isPrepped: json['isPrepped'] == 1 || json['isPrepped'] == true,
  );

  MealPlanEntry copyWith({bool? isPrepped, int? servings}) => MealPlanEntry(
    id: id,
    recipeId: recipeId,
    recipeTitle: recipeTitle,
    mealType: mealType,
    date: date,
    servings: servings ?? this.servings,
    estimatedCalories: estimatedCalories,
    isPrepped: isPrepped ?? this.isPrepped,
  );
}

class WeeklyMealPlan {
  final String id;
  final DateTime weekStart;
  final List<MealPlanEntry> entries;
  final String? notes;
  final DateTime createdAt;

  const WeeklyMealPlan({
    required this.id,
    required this.weekStart,
    this.entries = const [],
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'weekStart': weekStart.toIso8601String().split('T')[0],
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
  };
}

class MealPrepPlan {
  final String id;
  final String weeklyPlanId;
  final List<PrepStep> steps;
  final List<String> shoppingListNotes;
  final String? storageGuide;
  final String? reheatingGuide;
  final DateTime createdAt;

  const MealPrepPlan({
    required this.id,
    required this.weeklyPlanId,
    this.steps = const [],
    this.shoppingListNotes = const [],
    this.storageGuide,
    this.reheatingGuide,
    required this.createdAt,
  });
}

class PrepStep {
  final String time;
  final String description;
  final int durationMinutes;
  final bool isCompleted;

  const PrepStep({
    required this.time,
    required this.description,
    required this.durationMinutes,
    this.isCompleted = false,
  });
}
