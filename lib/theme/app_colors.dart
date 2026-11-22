import 'package:flutter/material.dart';

/// Immutable set of surface/text/border colors for one brightness mode.
class AppColorSet {
  final Color scaffold;
  final Color surface;
  final Color surfaceAlt;
  final Color card;
  final Color cardElevated;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnBrand;
  final Color border;
  final Color borderLight;
  final List<Color> surfaceGradient;
  final List<Color> cardGradient;

  const AppColorSet({
    required this.scaffold,
    required this.surface,
    required this.surfaceAlt,
    required this.card,
    required this.cardElevated,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnBrand,
    required this.border,
    required this.borderLight,
    required this.surfaceGradient,
    required this.cardGradient,
  });
}

class AppColors {
  // ── Brand / State / Nutrient (same in both themes) ──────────────────
  static const Color brand         = Color(0xFFFF6D00);  // Warm Ember
  static const Color brandSoft     = Color(0xFFFF9100);  // Amber Glow
  static const Color brandDim      = Color(0xFFDD2C00);  // Deep Chili
  static const Color accent        = Color(0xFF7C3AED);  // Genie Purple
  static const Color accentGlow    = Color(0x337C3AED);

  static const Color success       = Color(0xFF10B981);
  static const Color warning       = Color(0xFFF59E0B);
  static const Color error         = Color(0xFFEF4444);
  static const Color info          = Color(0xFF3B82F6);

  static const Color nutrientHigh     = Color(0xFF10B981);
  static const Color nutrientModerate = Color(0xFFF59E0B);
  static const Color nutrientLow      = Color(0xFFEF4444);

  static const List<Color> brandGradient  = [Color(0xFFFF6D00), Color(0xFFFF9100)];
  static const List<Color> accentGradient = [Color(0xFF7C3AED), Color(0xFFA855F7)];
  static const List<Color> genieGradient  = [
    Color(0xFF5B21B6), // Deep Genie Purple
    Color(0xFF831843), // Deep Wine/Rose
    Color(0xFFEA580C), // Rich Orange-Red
    Color(0xFFFF9100), // Prominent Amber Orange
  ];

  // ── Dark theme statics ──────────────────────────────────────────────
  static const Color scaffold     = Color(0xFF0D0808);
  static const Color surface      = Color(0xFF161010);
  static const Color surfaceAlt   = Color(0xFF1E1616);
  static const Color card         = Color(0xFF261E1E);
  static const Color cardElevated = Color(0xFF2E2626);
  static const Color background   = Color(0xFF0D0808);
  static const Color textPrimary  = Color(0xFFFCF6F0);
  static const Color textSecondary= Color(0xFFA09080);
  static const Color textTertiary = Color(0xFF706050);
  static const Color textOnBrand  = Color(0xFFFFFFFF);
  static const Color border       = Color(0xFF2E2626);
  static const Color borderLight  = Color(0xFF3E3636);
  static const List<Color> surfaceGradient = [Color(0xFF161010), Color(0xFF1E1616)];
  static const List<Color> cardGradient    = [Color(0xFF261E1E), Color(0xFF2E2626)];

  // ── Context-aware lookup ─────────────────────────────────────────────
  static AppColorSet of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? _dark : _light;
  }

  static const _dark = AppColorSet(
    scaffold:      Color(0xFF0D0808),
    surface:       Color(0xFF161010),
    surfaceAlt:    Color(0xFF1E1616),
    card:          Color(0xFF261E1E),
    cardElevated:  Color(0xFF2E2626),
    background:    Color(0xFF0D0808),
    textPrimary:   Color(0xFFFCF6F0),
    textSecondary: Color(0xFFA09080),
    textTertiary:  Color(0xFF706050),
    textOnBrand:   Color(0xFFFFFFFF),
    border:        Color(0xFF2E2626),
    borderLight:   Color(0xFF3E3636),
    surfaceGradient: [Color(0xFF161010), Color(0xFF1E1616)],
    cardGradient:    [Color(0xFF261E1E), Color(0xFF2E2626)],
  );

  static const _light = AppColorSet(
    scaffold:      Color(0xFFFCF6F0),
    surface:       Color(0xFFFFFFFF),
    surfaceAlt:    Color(0xFFFFF0E6),
    card:          Color(0xFFFFFFFF),
    cardElevated:  Color(0xFFFFF8F3),
    background:    Color(0xFFFCF6F0),
    textPrimary:   Color(0xFF1F150E),
    textSecondary: Color(0xFF6B5B4B),
    textTertiary:  Color(0xFF9B8B7B),
    textOnBrand:   Color(0xFFFFFFFF),
    border:        Color(0xFFE8DDD5),
    borderLight:   Color(0xFFD5C8BE),
    surfaceGradient: [Color(0xFFFFFFFF), Color(0xFFFFF0E6)],
    cardGradient:    [Color(0xFFFFFFFF), Color(0xFFFFF8F3)],
  );
}
