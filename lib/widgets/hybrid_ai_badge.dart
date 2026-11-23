import 'package:flutter/material.dart';

/// A sleek Material 3 micro-pill badge displaying runtime Firebase AI Logic Hybrid Inference source.
/// Pure vector icon design with zero emojis for a clean, professional finish.
class HybridAiBadge extends StatelessWidget {
  final bool isOnDevice;
  final bool isOffline;
  final int? latencyMs;
  final String? modelName;

  const HybridAiBadge({
    super.key,
    required this.isOnDevice,
    this.isOffline = false,
    this.latencyMs,
    this.modelName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color primaryColor;
    final IconData icon;
    final String label;

    if (isOffline) {
      primaryColor = const Color(0xFF94A3B8); // Sleek slate for offline storage
      icon = Icons.storage_rounded;
      label = 'Offline Library';
    } else if (isOnDevice) {
      primaryColor = const Color(0xFF10B981); // Emerald green for Gemini Nano on-device
      icon = Icons.bolt_rounded;
      label = 'Gemini Nano';
    } else {
      primaryColor = const Color(0xFF38BDF8); // Electric sky blue for Cloud Gemini Flash
      icon = Icons.cloud_done_rounded;
      label = modelName ?? 'Gemini 3.8 Flash';
    }

    final backgroundColor = isDark
        ? primaryColor.withValues(alpha: 0.14)
        : primaryColor.withValues(alpha: 0.09);

    return Tooltip(
      message: isOffline
          ? 'Retrieved from local offline SQLite library (73k+ recipes)'
          : (isOnDevice
              ? 'Executed locally on-device via Gemini Nano (AICore)'
              : 'Executed via Firebase AI Logic Cloud Fallback (Gemini 3.8 Flash)'),
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.30),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: primaryColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: primaryColor,
                letterSpacing: 0.1,
              ),
            ),
            if (latencyMs != null && latencyMs! > 0 && !isOffline) ...[
              const SizedBox(width: 4),
              Text(
                '• ${latencyMs}ms',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: primaryColor.withValues(alpha: 0.85),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
