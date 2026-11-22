import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recipe.dart';

class RecipeExportService {
  Future<String> exportToJson(Recipe recipe) async {
    final json = recipe.toJson();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }

  Future<File> exportToFile(Recipe recipe) async {
    final dir = await getApplicationDocumentsDirectory();
    final sanitized = recipe.title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final file = File('${dir.path}/$sanitized.json');
    final json = await exportToJson(recipe);
    await file.writeAsString(json);
    return file;
  }

  Future<void> shareRecipe(Recipe recipe) async {
    final json = await exportToJson(recipe);
    await Share.share(json, subject: 'Recipe: ${recipe.title} - Shared from ChowGenie');
  }

  Future<void> shareRecipeAsFile(Recipe recipe) async {
    final file = await exportToFile(recipe);
    await Share.shareXFiles([XFile(file.path)], subject: 'Recipe: ${recipe.title} - Shared from ChowGenie');
  }

  Recipe importFromJson(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return Recipe.fromJson(data);
  }

  Future<Recipe?> importFromFile(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      return importFromJson(content);
    } catch (e) {
      debugPrint('Error importing recipe: $e');
      return null;
    }
  }

  String generateQrData(Recipe recipe) {
    final data = {
      'type': 'chowgenie_recipe',
      'version': 2,
      'recipe': recipe.toJson(),
    };
    final jsonStr = jsonEncode(data);
    final bytes = utf8.encode(jsonStr);
    final compressed = zlib.encode(bytes);
    return base64Encode(compressed);
  }

  Recipe? parseQrData(String qrData) {
    final sanitizedData = qrData.trim();
    if (sanitizedData.isEmpty) return null;

    // Fallback 1: Direct JSON parsing check
    if (sanitizedData.startsWith('{') && sanitizedData.endsWith('}')) {
      return _parseRawQrJson(sanitizedData);
    }

    try {
      final bytes = base64Decode(sanitizedData);
      String jsonStr;
      
      try {
        final decompressed = zlib.decode(bytes);
        jsonStr = utf8.decode(decompressed);
      } catch (_) {
        // Fallback 2: Base64 encoded but not compressed
        jsonStr = utf8.decode(bytes);
      }
      return _parseRawQrJson(jsonStr);
    } catch (e) {
      // Fallback 3: Treat as raw JSON if Base64 decoding fails completely
      return _parseRawQrJson(sanitizedData);
    }
  }

  Recipe? _parseRawQrJson(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (data['type'] == 'chowgenie_recipe') {
        return Recipe.fromJson(data['recipe'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error parsing QR raw JSON: $e');
      return null;
    }
  }
}
