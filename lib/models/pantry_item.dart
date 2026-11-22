class PantryItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final DateTime? expiryDate;
  final double? price;
  final String? category;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PantryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.expiryDate,
    this.price,
    this.category,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());
  bool get isExpiringSoon => expiryDate != null &&
      expiryDate!.isAfter(DateTime.now()) &&
      expiryDate!.difference(DateTime.now()).inDays <= 3;
  String get normalizedName => name.trim().toLowerCase();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'expiryDate': expiryDate?.toIso8601String(),
    'price': price,
    'category': category,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory PantryItem.fromJson(Map<String, dynamic> json) => PantryItem(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    quantity: (json['quantity'] ?? 0).toDouble(),
    unit: json['unit'] ?? '',
    expiryDate: json['expiryDate'] != null ? DateTime.parse(json['expiryDate']) : null,
    price: (json['price'] as num?)?.toDouble(),
    category: json['category'],
    notes: json['notes'],
    createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
  );

  PantryItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    DateTime? expiryDate,
    double? price,
    String? category,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PantryItem(
    id: id ?? this.id,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    expiryDate: expiryDate ?? this.expiryDate,
    price: price ?? this.price,
    category: category ?? this.category,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
