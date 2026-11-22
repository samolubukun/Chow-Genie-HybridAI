import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Interactive modal bottom sheet for smart cooking countdown timers with audio-haptic feedback.
class CookingTimerBottomSheet extends StatefulWidget {
  final int initialMinutes;
  final String label;

  const CookingTimerBottomSheet({
    super.key,
    this.initialMinutes = 5,
    this.label = 'Cooking Timer',
  });

  static Future<void> show(
    BuildContext context, {
    int initialMinutes = 5,
    String label = 'Cooking Timer',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CookingTimerBottomSheet(
        initialMinutes: initialMinutes,
        label: label,
      ),
    );
  }

  @override
  State<CookingTimerBottomSheet> createState() => _CookingTimerBottomSheetState();
}

class _CookingTimerBottomSheetState extends State<CookingTimerBottomSheet> {
  late int _totalSeconds;
  late int _remainingSeconds;
  Timer? _timer;
  bool _isRunning = false;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.initialMinutes > 0 ? widget.initialMinutes * 60 : 300;
    _remainingSeconds = _totalSeconds;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = true;
      _isFinished = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _isRunning = false;
          _isFinished = true;
        });
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
    HapticFeedback.lightImpact();
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = _totalSeconds;
      _isRunning = false;
      _isFinished = false;
    });
    HapticFeedback.mediumImpact();
  }

  void _addMinutes(int minutes) {
    setState(() {
      _totalSeconds += minutes * 60;
      _remainingSeconds += minutes * 60;
      _isFinished = false;
    });
    HapticFeedback.selectionClick();
    if (!_isRunning) {
      _startTimer();
    }
  }

  void _setMinutes(int minutes) {
    _timer?.cancel();
    setState(() {
      _totalSeconds = minutes * 60;
      _remainingSeconds = _totalSeconds;
      _isFinished = false;
    });
    HapticFeedback.selectionClick();
    _startTimer();
  }

  String _formatTime(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progressPercent {
    if (_totalSeconds <= 0) return 0.0;
    final progress = (_totalSeconds - _remainingSeconds) / _totalSeconds;
    return progress.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.timer_outlined, color: AppColors.brand, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: AppTextStyles.heading3.copyWith(color: colors.textPrimary),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: colors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Circular countdown indicator
          CircularPercentIndicator(
            radius: 95.0,
            lineWidth: 10.0,
            percent: _progressPercent,
            animation: false,
            circularStrokeCap: CircularStrokeCap.round,
            backgroundColor: colors.surfaceAlt,
            progressColor: _isFinished ? AppColors.success : AppColors.brand,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatTime(_remainingSeconds),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: _isFinished ? AppColors.success : colors.textPrimary,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isFinished
                      ? '🎉 Step Complete!'
                      : _isRunning
                          ? 'Cooking...'
                          : 'Paused',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: _isFinished
                        ? AppColors.success
                        : _isRunning
                            ? AppColors.brand
                            : colors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick presets
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPresetChip('3m', 3, colors),
                const SizedBox(width: 8),
                _buildPresetChip('5m', 5, colors),
                const SizedBox(width: 8),
                _buildPresetChip('10m', 10, colors),
                const SizedBox(width: 8),
                _buildPresetChip('15m', 15, colors),
                const SizedBox(width: 8),
                _buildPresetChip('25m', 25, colors),
                const SizedBox(width: 8),
                _buildAddMinutesChip('+1m', 1, colors),
                const SizedBox(width: 8),
                _buildAddMinutesChip('+5m', 5, colors),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Controls
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetTimer,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reset'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                    side: BorderSide(color: colors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_isFinished) {
                      _resetTimer();
                    } else if (_isRunning) {
                      _pauseTimer();
                    } else {
                      _startTimer();
                    }
                  },
                  icon: Icon(
                    _isFinished
                        ? Icons.replay
                        : _isRunning
                            ? Icons.pause
                            : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  label: Text(
                    _isFinished
                        ? 'Restart'
                        : _isRunning
                            ? 'Pause'
                            : 'Start',
                    style: AppTextStyles.buttonMedium.copyWith(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFinished ? AppColors.success : AppColors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, int minutes, AppColorSet colors) {
    final isCurrent = (_totalSeconds == minutes * 60) && !_isFinished;
    return GestureDetector(
      onTap: () => _setMinutes(minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.brand.withOpacity(0.2) : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCurrent ? AppColors.brand : colors.border,
            width: isCurrent ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isCurrent ? AppColors.brand : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildAddMinutesChip(String label, int minutes, AppColorSet colors) {
    return GestureDetector(
      onTap: () => _addMinutes(minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.brand,
          ),
        ),
      ),
    );
  }
}
