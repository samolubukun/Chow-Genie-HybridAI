import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/ingrediguard_result.dart';
import '../services/model_manager.dart';
import '../services/image_service.dart';
import '../services/local_db_service.dart';

class IngrediGuardViewModel extends ChangeNotifier {
  final ModelManager _modelManager;
  final ImageService _imageService;
  final LocalDbService _db;

  File? _image;
  bool _isAnalyzing = false;
  IngrediGuardResult? _result;
  String? _errorMessage;
  List<IngrediGuardResult> _history = [];

  IngrediGuardViewModel(this._modelManager, this._imageService, this._db) {
    loadHistory();
  }

  File? get image => _image;
  bool get isAnalyzing => _isAnalyzing;
  bool get hasImage => _image != null;
  bool get hasResult => _result != null;
  IngrediGuardResult? get result => _result;
  String? get errorMessage => _errorMessage;
  List<IngrediGuardResult> get history => _history;

  Future<void> loadHistory() async {
    try {
      _history = await _db.getIngrediGuardHistory();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading IngrediGuard history: $e');
    }
  }

  Future<void> pickImage() async {
    final path = await _imageService.pickFromGallery();
    if (path != null) {
      _image = File(path);
      clearResults();
      notifyListeners();
    }
  }

  Future<void> takePhoto() async {
    final path = await _imageService.pickFromCamera();
    if (path != null) {
      _image = File(path);
      clearResults();
      notifyListeners();
    }
  }

  void clearImage() {
    _image = null;
    clearResults();
    notifyListeners();
  }

  void clearResults() {
    _result = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> clearHistory() async {
    try {
      await _db.clearIngrediGuardHistory();
      _history = [];
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing history: $e');
    }
  }

  Future<void> analyze() async {
    if (_image == null || _isAnalyzing) return;
    _isAnalyzing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final bytes = await _image!.readAsBytes();

      const prompt = '''
You are an expert food safety biochemist and nutritionist specializing in ingredient safety, chemical exposures, and NOVA food processing classifications.
Analyze this food product ingredient label image. Extract and return ONLY valid JSON with this exact structure:
{
  "productName": "Estimated product name or category",
  "healthScore": 0-100,
  "novaGroup": "NOVA 1" | "NOVA 2" | "NOVA 3" | "NOVA 4",
  "processingDescription": "Brief explanation of why it fits this NOVA group (1 sentence).",
  "hasSeedOils": true | false,
  "detectedSeedOils": ["seed oil names", ...],
  "harmfulAdditives": [
    {
      "name": "Additive name / E-number (e.g. Carrageenan)",
      "risk": "High" | "Moderate" | "Low",
      "category": "Preservative" | "Emulsifier" | "Sweetener" | "Color" | "Thickener" | "Other",
      "hazards": ["gut inflammation", "carcinogen risk", "hormone disruptor"],
      "description": "Short explanation of this additive (1 sentence)."
    }
  ],
  "cleanSwaps": [
    "Suggested natural or less-processed swap 1",
    "Suggested natural or less-processed swap 2"
  ]
}

Ensure all lists and fields are fully populated based on ingredients detected. If seed oils like canola, soybean, corn, safflower, or sunflower oil are found, set hasSeedOils to true.
Return ONLY raw valid JSON. Do not include markdown code block formatting (like ```json), explanations, or headers.''';

      final response = await _modelManager.generateMultimodalResponse(prompt, bytes);
      if (response != null) {
        final parsed = _parseResultJson(response);
        if (parsed != null) {
          _result = parsed;
          await _db.saveIngrediGuardResult(parsed);
          await loadHistory();
        } else {
          _setError('Could not extract food safety data. Please ensure the label is clearly visible.');
        }
      } else {
        _setError('Analysis failed. Make sure the local AI model is fully downloaded.');
      }
    } catch (e) {
      _setError('Analysis error: $e');
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  IngrediGuardResult? _parseResultJson(String raw) {
    try {
      debugPrint('RAW GEMMA OUTPUT FOR INGREDI GUARD:\n$raw');
      // Clean gemma code block wrappers if present
      String cleaned = raw.trim();
      if (cleaned.startsWith('```')) {
        final lines = cleaned.split('\n');
        if (lines.first.startsWith('```json') || lines.first.startsWith('```')) {
          lines.removeAt(0);
        }
        if (lines.isNotEmpty && lines.last.startsWith('```')) {
          lines.removeLast();
        }
        cleaned = lines.join('\n').trim();
      }

      final Map<String, dynamic> data = jsonDecode(cleaned);
      final id = 'ig_${DateTime.now().millisecondsSinceEpoch}';
      data['id'] = id;
      data['imagePath'] = _image?.path ?? '';
      data['scannedAt'] = DateTime.now().toIso8601String();
      
      return IngrediGuardResult.fromJson(data);
    } catch (e) {
      debugPrint('JSON Parsing error: $e');
      return null;
    }
  }

  void _setError(String msg) {
    _errorMessage = msg;
    notifyListeners();
  }
}
