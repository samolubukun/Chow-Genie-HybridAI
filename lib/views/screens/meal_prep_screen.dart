import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/meal_plan_view_model.dart';

class MealPrepScreen extends StatefulWidget {
  const MealPrepScreen({super.key});

  @override
  State<MealPrepScreen> createState() => _MealPrepScreenState();
}

class _MealPrepScreenState extends State<MealPrepScreen> {
  final List<PrepStepUI> _steps = [];
  int? _activeTimerIndex;
  int _currentStepIndex = 0;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _initSteps();
  }

  void _initSteps() {
    _steps.addAll([
      PrepStepUI(time: '08:00', description: 'Wash and chop all vegetables', duration: 15),
      PrepStepUI(time: '08:15', description: 'Marinate proteins (chicken/tofu)', duration: 20),
      PrepStepUI(time: '08:35', description: 'Cook grains (rice/quinoa)', duration: 25),
      PrepStepUI(time: '09:00', description: 'Prepare sauces and dressings', duration: 10),
      PrepStepUI(time: '09:10', description: 'Cook main dishes', duration: 30),
      PrepStepUI(time: '09:40', description: 'Portion into meal containers', duration: 15),
      PrepStepUI(time: '09:55', description: 'Label and refrigerate', duration: 10),
    ]);
  }

  @override
  void dispose() {
    for (final step in _steps) {
      step.timer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.scaffold,
      body: Consumer<MealPlanViewModel>(
        builder: (context, vm, _) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: colors.scaffold,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text('Meal Prep', style: AppTextStyles.heading2),
                centerTitle: true,
              ),
              SliverToBoxAdapter(child: _buildHeader(context, colors)),
              SliverToBoxAdapter(child: _buildTimerSection(context, colors)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Prep Steps', style: AppTextStyles.heading3.copyWith(color: colors.textPrimary)),
                ),
              ),
              if (vm.generatedPrepTimeline != null)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.brand.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: Text(
                      vm.generatedPrepTimeline!,
                      style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, height: 1.5),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildStepCard(context, index, colors),
                    childCount: _steps.length,
                  ),
                ),
              SliverToBoxAdapter(child: _buildGuideSections(context, colors)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildActionButton(context, vm, colors),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppColorSet colors) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brand, AppColors.brandSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.kitchen, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly Meal Prep', style: AppTextStyles.heading2.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('${_steps.length} steps • ~${_totalDuration()} min', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _completedCount() / _steps.length,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_completedCount()} of ${_steps.length} steps completed',
            style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerSection(BuildContext context, AppColorSet colors) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.timer, color: AppColors.brand, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active Timer', style: AppTextStyles.labelLarge.copyWith(color: colors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  _activeTimerIndex != null
                      ? _steps[_activeTimerIndex!].description
                      : 'Tap play on a step to start',
                  style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          if (_activeTimerIndex != null) ...[
            Text(
              _formatTime(_steps[_activeTimerIndex!].remainingSeconds),
              style: AppTextStyles.numericMedium.copyWith(color: AppColors.brand, fontSize: 24),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined, color: AppColors.error),
              onPressed: () => _stopTimer(_activeTimerIndex!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepCard(BuildContext context, int index, AppColorSet colors) {
    final step = _steps[index];
    final isCurrent = index == _currentStepIndex;
    final isCompleted = step.isCompleted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.brand.withValues(alpha: 0.08) : colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent ? AppColors.brand : colors.border,
            width: isCurrent ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _toggleStep(index),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.success : colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCompleted ? AppColors.success : colors.border,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(step.time, style: AppTextStyles.labelSmall.copyWith(color: AppColors.brand, fontSize: 10)),
                      ),
                      const SizedBox(width: 8),
                      Text('${step.duration} min', style: AppTextStyles.labelSmall.copyWith(color: colors.textTertiary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.description,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (_activeTimerIndex == index) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 1 - (step.remainingSeconds / (step.duration * 60)),
                        backgroundColor: colors.surfaceAlt,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _activeTimerIndex == index ? _stopTimer(index) : _startTimer(index),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _activeTimerIndex == index
                      ? AppColors.error.withValues(alpha: 0.15)
                      : AppColors.brand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _activeTimerIndex == index ? Icons.stop : Icons.play_arrow_rounded,
                  color: _activeTimerIndex == index ? AppColors.error : AppColors.brand,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideSections(BuildContext context, AppColorSet colors) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGuideCard(
            context,
            icon: Icons.inventory_2_outlined,
            title: 'Storage Guide',
            color: AppColors.info,
            items: [
              'Store cooked grains in airtight containers for up to 5 days',
              'Keep dressings and sauces separate from greens',
              'Use glass containers for microwave-safe reheating',
              'Label each container with date and contents',
            ],
            colors: colors,
          ),
          const SizedBox(height: 12),
          _buildGuideCard(
            context,
            icon: Icons.restart_alt,
            title: 'Reheating Guide',
            color: AppColors.warning,
            items: [
              'Microwave: 2-3 min, stir halfway through',
              'Stovetop: medium heat, add splash of water',
              'Oven: 350°F for 10-15 min covered',
              'Never reheat more than once per portion',
            ],
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required List<String> items,
    required AppColorSet colors,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: AppTextStyles.heading3.copyWith(color: colors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item, style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, MealPlanViewModel vm, AppColorSet colors) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isGenerating
            ? null
            : () {
                setState(() => _isGenerating = true);
                vm.generatePrepTimeline(
                  weekEntries: vm.entries,
                  availableTime: '3 hours',
                ).then((_) {
                  if (mounted) setState(() => _isGenerating = false);
                });
              },
        icon: _isGenerating
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.auto_awesome, size: 20),
        label: Text(_isGenerating ? 'Generating...' : 'Generate Prep Plan'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  void _toggleStep(int index) {
    setState(() {
      _steps[index].isCompleted = !_steps[index].isCompleted;
      if (_steps[index].isCompleted && index == _currentStepIndex) {
        _currentStepIndex = (_currentStepIndex + 1) % _steps.length;
      }
    });
  }

  void _startTimer(int index) {
    final step = _steps[index];
    if (step.remainingSeconds <= 0) return;
    setState(() => _activeTimerIndex = index);
    step.timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (step.remainingSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            step.remainingSeconds = 0;
            _activeTimerIndex = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.alarm, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('${step.description} — Time\'s up!'),
                ],
              ),
              backgroundColor: AppColors.brand,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        setState(() => step.remainingSeconds--);
      }
    });
  }

  void _stopTimer(int index) {
    _steps[index].timer?.cancel();
    setState(() => _activeTimerIndex = null);
  }

  int _totalDuration() => _steps.fold(0, (sum, s) => sum + s.duration);
  int _completedCount() => _steps.where((s) => s.isCompleted).length;

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class PrepStepUI {
  final String time;
  final String description;
  final int duration;
  int remainingSeconds;
  bool isCompleted;
  Timer? timer;

  PrepStepUI({
    required this.time,
    required this.description,
    required this.duration,
  })  : remainingSeconds = duration * 60,
        isCompleted = false;
}
