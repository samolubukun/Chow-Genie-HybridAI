import 'package:flutter/material.dart';

/// A Material 3 badge displaying runtime Firebase AI Logic Hybrid Inference source.
class HybridAiBadge extends StatelessWidget {
  final bool isOnDevice;
  final int? latencyMs;
  final String? modelName;

  const HybridAiBadge({
    super.key,
    required this.isOnDevice,
    this.latencyMs,
    this.modelName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = isOnDevice
        ? const Color(0xFF00C853) // Green for fast on-device Gemini Nano
        : const Color(0xFF0091EA); // Blue for cloud Gemini Flash fallback

    final backgroundColor = isDark
        ? primaryColor.withValues(alpha: 0.15)
        : primaryColor.withValues(alpha: 0.10);

    return Tooltip(
      message: isOnDevice
          ? 'Executed locally on-device via Gemini Nano (Zero latency, full privacy, offline)'
          : 'Executed via Firebase AI Logic Cloud Fallback (Gemini Flash)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOnDevice ? Icons.bolt_rounded : Icons.cloud_done_rounded,
              size: 14,
              color: primaryColor,
            ),
            const SizedBox(width: 5),
            Text(
              isOnDevice
                  ? '⚡ Gemini Nano (On-Device)'
                  : '☁️ Gemini Flash (Cloud Fallback)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: primaryColor,
                letterSpacing: 0.2,
              ),
            ),
            if (latencyMs != null && latencyMs! > 0) ...[
              const SizedBox(width: 4),
              Text(
                '• ${latencyMs}ms',
                style: TextStyle(
                  fontSize: 10,
                  color: primaryColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
