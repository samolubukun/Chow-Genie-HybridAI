enum ShoppingItemSource { manual, pantryRefill, mealPlan, recipe }

class ShoppingItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final bool isChecked;
  final ShoppingItemSource source;
  final String? sourceRecipeId;
  final String? category;
  final double? estimatedPrice;
  final DateTime createdAt;

  const ShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.isChecked = false,
    this.source = ShoppingItemSource.manual,
    this.sourceRecipeId,
    this.category,
    this.estimatedPrice,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'isChecked': isChecked ? 1 : 0,
    'source': source.name,
    'sourceRecipeId': sourceRecipeId,
    'category': category,
    'estimatedPrice': estimatedPrice,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    quantity: (json['quantity'] ?? 0).toDouble(),
    unit: json['unit'] ?? '',
    isChecked: json['isChecked'] == 1 || json['isChecked'] == true,
    source: ShoppingItemSource.values.firstWhere(
      (s) => s.name == json['source'],
      orElse: () => ShoppingItemSource.manual,
    ),
    sourceRecipeId: json['sourceRecipeId'],
    category: json['category'],
    estimatedPrice: (json['estimatedPrice'] as num?)?.toDouble(),
    createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
  );

  ShoppingItem copyWith({bool? isChecked, double? quantity}) => ShoppingItem(
    id: id,
    name: name,
    quantity: quantity ?? this.quantity,
    unit: unit,
    isChecked: isChecked ?? this.isChecked,
    source: source,
    sourceRecipeId: sourceRecipeId,
    category: category,
    estimatedPrice: estimatedPrice,
    createdAt: createdAt,
  );
}
