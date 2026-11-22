import 'dart:convert';

enum RiskLevel { low, moderate, high }

class AdditiveHazard {
  final String name;
  final RiskLevel risk;
  final String category;
  final List<String> hazards;
  final String description;

  AdditiveHazard({
    required this.name,
    required this.risk,
    required this.category,
    required this.hazards,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'risk': risk.name,
    'category': category,
    'hazards': hazards,
    'description': description,
  };

  factory AdditiveHazard.fromJson(Map<String, dynamic> json) {
    return AdditiveHazard(
      name: json['name'] ?? '',
      risk: RiskLevel.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['risk'] ?? 'low').toString().toLowerCase(),
        orElse: () => RiskLevel.low,
      ),
      category: json['category'] ?? 'Other',
      hazards: List<String>.from(json['hazards'] ?? []),
      description: json['description'] ?? '',
    );
  }
}

class IngrediGuardResult {
  final String id;
  final String productName;
  final double healthScore;
  final String novaGroup; // e.g. "NOVA 4" or "NOVA 1"
  final String processingDescription;
  final bool hasSeedOils;
  final List<String> detectedSeedOils;
  final List<AdditiveHazard> harmfulAdditives;
  final List<String> cleanSwaps;
  final String imagePath;
  final DateTime scannedAt;

  IngrediGuardResult({
    required this.id,
    required this.productName,
    required this.healthScore,
    required this.novaGroup,
    required this.processingDescription,
    required this.hasSeedOils,
    required this.detectedSeedOils,
    required this.harmfulAdditives,
    required this.cleanSwaps,
    required this.imagePath,
    required this.scannedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'productName': productName,
    'healthScore': healthScore,
    'novaGroup': novaGroup,
    'processingDescription': processingDescription,
    'hasSeedOils': hasSeedOils ? 1 : 0,
    'detectedSeedOils': jsonEncode(detectedSeedOils),
    'harmfulAdditives': jsonEncode(harmfulAdditives.map((a) => a.toJson()).toList()),
    'cleanSwaps': jsonEncode(cleanSwaps),
    'imagePath': imagePath,
    'scannedAt': scannedAt.toIso8601String(),
  };

  factory IngrediGuardResult.fromDb(Map<String, dynamic> json) {
    List<AdditiveHazard> additives = [];
    if (json['harmfulAdditives'] != null) {
      try {
        final list = jsonDecode(json['harmfulAdditives']) as List;
        additives = list.map((a) => AdditiveHazard.fromJson(a as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    List<String> seedOils = [];
    if (json['detectedSeedOils'] != null) {
      try {
        final list = jsonDecode(json['detectedSeedOils']) as List;
        seedOils = List<String>.from(list);
      } catch (_) {}
    }

    List<String> swaps = [];
    if (json['cleanSwaps'] != null) {
      try {
        final list = jsonDecode(json['cleanSwaps']) as List;
        swaps = List<String>.from(list);
      } catch (_) {}
    }

    return IngrediGuardResult(
      id: json['id'] ?? '',
      productName: json['productName'] ?? 'Unknown Product',
      healthScore: (json['healthScore'] ?? 100).toDouble(),
      novaGroup: json['novaGroup'] ?? 'NOVA 1',
      processingDescription: json['processingDescription'] ?? '',
      hasSeedOils: json['hasSeedOils'] == 1,
      detectedSeedOils: seedOils,
      harmfulAdditives: additives,
      cleanSwaps: swaps,
      imagePath: json['imagePath'] ?? '',
      scannedAt: DateTime.parse(json['scannedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  factory IngrediGuardResult.fromJson(Map<String, dynamic> json) {
    List<AdditiveHazard> additives = [];
    if (json['harmfulAdditives'] != null) {
      try {
        final list = json['harmfulAdditives'] as List;
        additives = list.map((a) => AdditiveHazard.fromJson(a as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    List<String> seedOils = [];
    if (json['detectedSeedOils'] != null) {
      try {
        final list = json['detectedSeedOils'] as List;
        seedOils = List<String>.from(list);
      } catch (_) {}
    }

    List<String> swaps = [];
    if (json['cleanSwaps'] != null) {
      try {
        final list = json['cleanSwaps'] as List;
        swaps = List<String>.from(list);
      } catch (_) {}
    }

    return IngrediGuardResult(
      id: json['id'] ?? '',
      productName: json['productName'] ?? 'Unknown Product',
      healthScore: (json['healthScore'] ?? 100).toDouble(),
      novaGroup: json['novaGroup'] ?? 'NOVA 1',
      processingDescription: json['processingDescription'] ?? '',
      hasSeedOils: json['hasSeedOils'] == true,
      detectedSeedOils: seedOils,
      harmfulAdditives: additives,
      cleanSwaps: swaps,
      imagePath: json['imagePath'] ?? '',
      scannedAt: DateTime.parse(json['scannedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
