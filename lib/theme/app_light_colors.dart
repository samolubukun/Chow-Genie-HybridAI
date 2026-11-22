import 'package:flutter/material.dart';

class AppLightColors {
  // Brand (same across both themes)
  static const Color brand = Color(0xFFFF6D00);
  static const Color brandSoft = Color(0xFFFF9100);
  static const Color brandDim = Color(0xFFDD2C00);
  static const Color accent = Color(0xFF7C3AED);
  static const Color accentGlow = Color(0x337C3AED);

  // Backgrounds - warm light
  static const Color background = Color(0xFFFCF6F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFFFF0E6);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardElevated = Color(0xFFFFF8F3);
  static const Color scaffold = Color(0xFFFCF6F0);

  // Text
  static const Color textPrimary = Color(0xFF1F150E);
  static const Color textSecondary = Color(0xFF6B5B4B);
  static const Color textTertiary = Color(0xFF9B8B7B);
  static const Color textOnBrand = Color(0xFFFFFFFF);

  // State
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Nutrient categories
  static const Color nutrientHigh = Color(0xFF10B981);
  static const Color nutrientModerate = Color(0xFFF59E0B);
  static const Color nutrientLow = Color(0xFFEF4444);

  // Borders
  static const Color border = Color(0xFFE8DDD5);
  static const Color borderLight = Color(0xFFD5C8BE);

  // Gradients
  static const List<Color> brandGradient = [Color(0xFFFF6D00), Color(0xFFFF9100)];
  static const List<Color> accentGradient = [Color(0xFF7C3AED), Color(0xFFA855F7)];
  static const List<Color> surfaceGradient = [Color(0xFFFFFFFF), Color(0xFFFFF0E6)];
  static const List<Color> cardGradient = [Color(0xFFFFFFFF), Color(0xFFFFF8F3)];
}
