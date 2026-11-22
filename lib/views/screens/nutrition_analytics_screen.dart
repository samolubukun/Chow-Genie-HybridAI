import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/nutrition_view_model.dart';
import '../../services/local_db_service.dart';
import '../../services/model_manager.dart';
import '../../services/image_service.dart';

class NutritionAnalyticsScreen extends StatefulWidget {
  const NutritionAnalyticsScreen({super.key});

  @override
  State<NutritionAnalyticsScreen> createState() => _NutritionAnalyticsScreenState();
}

class _NutritionAnalyticsScreenState extends State<NutritionAnalyticsScreen> {
  bool _showWeekly = false;
  bool _isExtracting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NutritionViewModel>().loadDay();
      context.read<NutritionViewModel>().loadWeek(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.scaffold,
      body: Consumer<NutritionViewModel>(
        builder: (context, vm, _) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: colors.scaffold,
                surfaceTintColor: Colors.transparent,
                title: Text('Nutrition', style: AppTextStyles.heading2),
                centerTitle: true,
              ),
              SliverToBoxAdapter(child: _buildDateSelector(context, vm, colors)),
              SliverToBoxAdapter(child: _buildSummaryCard(context, vm, colors)),
              SliverToBoxAdapter(child: _buildWaterTracker(context, vm, colors)),
              SliverToBoxAdapter(child: _buildMacroProgress(context, vm, colors)),
              SliverToBoxAdapter(child: _buildChartToggle(context, vm, colors)),
              if (_showWeekly)
                SliverToBoxAdapter(child: _buildWeeklyChart(context, vm, colors))
              else
                SliverToBoxAdapter(child: _buildMealLogList(context, vm, colors)),
              SliverToBoxAdapter(child: _buildInsightSection(context, vm, colors)),
              SliverToBoxAdapter(child: const SizedBox(height: 80)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMealSheet(context, colors),
        backgroundColor: AppColors.brand,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context, NutritionViewModel vm, AppColorSet colors) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.brand),
            onPressed: () => vm.loadDay(date: vm.selectedDate.subtract(const Duration(days: 1))),
          ),
          Column(
            children: [
              Text(
                DateFormat('EEEE, MMM d').format(vm.selectedDate),
                style: AppTextStyles.labelLarge.copyWith(color: colors.textPrimary),
              ),
              Text(
                DateFormat('yyyy').format(vm.selectedDate),
                style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.brand),
            onPressed: () => vm.loadDay(date: vm.selectedDate.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, NutritionViewModel vm, AppColorSet colors) {
    final totals = vm.dailyTotals;
    final calories = totals['calories'] ?? 0;
    final protein = totals['protein'] ?? 0;
    final carbs = totals['carbs'] ?? 0;
    final fat = totals['fat'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: CircularPercentIndicator(
              radius: 50,
              lineWidth: 10,
              percent: calories > 0 ? (calories / 2000).clamp(0, 1) : 0,
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${calories.toStringAsFixed(0)}',
                    style: AppTextStyles.numericSmall.copyWith(color: AppColors.brand, fontSize: 22),
                  ),
                  Text('kcal', style: AppTextStyles.labelSmall.copyWith(color: colors.textTertiary)),
                ],
              ),
              progressColor: AppColors.brand,
              backgroundColor: colors.surfaceAlt,
              circularStrokeCap: CircularStrokeCap.round,
              animation: true,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                _macroBar('Protein', protein, AppColors.success, colors),
                const SizedBox(height: 8),
                _macroBar('Carbs', carbs, AppColors.info, colors),
                const SizedBox(height: 8),
                _macroBar('Fat', fat, AppColors.warning, colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroBar(String label, double value, Color color, AppColorSet colors) {
    final maxVal = label == 'Protein' ? 100.0 : label == 'Carbs' ? 300.0 : 80.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.labelSmall.copyWith(color: colors.textSecondary)),
            Text('${value.toStringAsFixed(1)}g', style: AppTextStyles.labelSmall.copyWith(color: colors.textPrimary)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (value / maxVal).clamp(0, 1),
            backgroundColor: colors.surfaceAlt,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildWaterTracker(BuildContext context, NutritionViewModel vm, AppColorSet colors) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
              const Icon(Icons.water_drop, color: AppColors.info, size: 20),
              const SizedBox(width: 8),
              Text('Water Intake', style: AppTextStyles.labelLarge.copyWith(color: colors.textPrimary)),
              const Spacer(),
              Text('${vm.waterIntake}/8 glasses', style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(8, (i) {
              final isFilled = i < vm.waterIntake;
              return GestureDetector(
                onTap: () => vm.addWater(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isFilled ? AppColors.info : colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFilled ? AppColors.info : colors.border,
                    ),
                  ),
                  child: Icon(
                    Icons.water_drop,
                    color: isFilled ? Colors.white : colors.textTertiary,
                    size: 20,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroProgress(BuildContext context, NutritionViewModel vm, AppColorSet colors) {
    final totals = vm.dailyTotals;
    final cal = totals['calories'] ?? 0;
    final pro = totals['protein'] ?? 0;
    final carb = totals['carbs'] ?? 0;
    final fat = totals['fat'] ?? 0;
    final total = cal + pro * 4 + carb * 4 + fat * 9;
    final calPct = total > 0 ? (cal / total).clamp(0, 1) : 0.25;
    final proPct = total > 0 ? (pro * 4 / total).clamp(0, 1) : 0.25;
    final carbPct = total > 0 ? (carb * 4 / total).clamp(0, 1) : 0.25;
    final fatPct = total > 0 ? (fat * 9 / total).clamp(0, 1) : 0.25;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Macro Distribution', style: AppTextStyles.labelLarge.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Flexible(flex: (calPct * 100).round(), child: Container(color: AppColors.brand)),
                  Flexible(flex: (proPct * 100).round(), child: Container(color: AppColors.success)),
                  Flexible(flex: (carbPct * 100).round(), child: Container(color: AppColors.info)),
                  Flexible(flex: (fatPct * 100).round(), child: Container(color: AppColors.warning)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _macroDot('Cal', AppColors.brand, colors),
              _macroDot('Pro', AppColors.success, colors),
              _macroDot('Carbs', AppColors.info, colors),
              _macroDot('Fat', AppColors.warning, colors),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroDot(String label, Color color, AppColorSet colors) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: colors.textSecondary)),
      ],
    );
  }

  Widget _buildChartToggle(BuildContext context, NutritionViewModel vm, AppColorSet colors) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showWeekly = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_showWeekly ? AppColors.brand : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                ),
                child: Text(
                  'Meals',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: !_showWeekly ? Colors.white : colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _showWeekly = true);
                vm.loadWeek(DateTime.now());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _showWeekly ? AppColors.brand : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(15)),
                ),
                child: Text(
                  'Weekly',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: _showWeekly ? Colors.white : colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealLogList(BuildContext context, NutritionViewModel vm, AppColorSet colors) {
    final logs = vm.todayLogs;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (logs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.restaurant, color: colors.textTertiary, size: 36),
                  const SizedBox(height: 8),
                  Text('No meals logged today', style: AppTextStyles.bodyMedium.copyWith(color: colors.textTertiary)),
                ],
              ),
            )
          else
            ...logs.map((log) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log['recipeTitle'] ?? 'Meal', style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          '${log['mealType'] ?? 'meal'} • ${log['calories']?.toStringAsFixed(0) ?? '0'} cal',
                          style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${log['protein']?.toStringAsFixed(1) ?? '0'}g P',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.success),
                      ),
                      Text(
                        '${log['carbs']?.toStringAsFixed(1) ?? '0'}g C',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.info),
                      ),
                    ],
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(BuildContext context, NutritionViewModel vm, AppColorSet colors) {
    final logs = vm.weeklyLogs;

    Map<int, double> dailyCalories = {};
    for (final log in logs) {
      final date = DateTime.parse(log['date'] as String);
      final cal = (log['calories'] ?? 0).toDouble();
      dailyCalories[date.weekday] = (dailyCalories[date.weekday] ?? 0) + cal;
    }

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Calories This Week', style: AppTextStyles.labelLarge.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 2500,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = dayNames[group.x.toInt() - 1];
                      return BarTooltipItem(
                        '$day\n${rod.toY.toStringAsFixed(0)} cal',
                        TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt() - 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            dayNames[idx >= 0 && idx < dayNames.length ? idx : 0],
                            style: TextStyle(color: colors.textTertiary, fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(color: colors.textTertiary, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 500,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: colors.border.withValues(alpha: 0.3),
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: weekDays.map((day) {
                  final cal = dailyCalories[day.weekday] ?? 0;
                  return BarChartGroupData(
                    x: day.weekday,
                    barRods: [
                      BarChartRodData(
                        toY: cal.clamp(0, 2500),
                        color: AppColors.brand,
                        width: 18,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightSection(BuildContext context, NutritionViewModel vm, AppColorSet colors) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: vm.isGeneratingInsight
                  ? null
                  : () => vm.generateInsight(null),
              icon: vm.isGeneratingInsight
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(vm.isGeneratingInsight ? 'Analyzing...' : 'Generate Health Insight'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          if (vm.healthInsight != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.1),
                    AppColors.brand.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.psychology, color: AppColors.accent, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text('AI Insight', style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    vm.healthInsight!,
                    style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _captureMeal(
    BuildContext context,
    ImageSource source,
    StateSetter setSheetState,
    TextEditingController titleCtrl,
    TextEditingController calCtrl,
    TextEditingController proCtrl,
    TextEditingController carbCtrl,
    TextEditingController fatCtrl,
    AppColorSet colors,
  ) async {
    final mm = Provider.of<ModelManager>(context, listen: false);
    if (!mm.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("AI Model is not ready. Please download/initialize it in Settings.")),
      );
      return;
    }

    final imageService = Provider.of<ImageService>(context, listen: false);
    String? path;
    try {
      path = source == ImageSource.camera
          ? await imageService.pickFromCamera()
          : await imageService.pickFromGallery();
    } catch (e) {
      debugPrint("Error picking image: $e");
    }

    if (path == null) return;

    final bytes = await imageService.getBytes(path);
    if (bytes == null) return;

    setSheetState(() {
      _isExtracting = true;
    });

    const prompt = "Analyze this meal photo. Estimate the meal title, calories (kcal), protein (g), carbs (g), and fat (g). Output a JSON object ONLY containing: "
        "{\"title\": \"Name of the meal\", \"calories\": 350.0, \"protein\": 20.0, \"carbs\": 40.0, \"fat\": 10.0}. "
        "Do not write any markdown code blocks, explanation or additional text. Just output valid raw JSON.";

    try {
      final response = await mm.generateMultimodalResponse(prompt, bytes);
      if (response != null) {
        var cleaned = response.trim();
        if (cleaned.startsWith('```')) {
          final lines = cleaned.split('\n');
          if (lines.first.startsWith('```')) {
            lines.removeAt(0);
          }
          if (lines.isNotEmpty && lines.last.startsWith('```')) {
            lines.removeLast();
          }
          cleaned = lines.join('\n').trim();
        }

        final map = jsonDecode(cleaned) as Map<String, dynamic>;
        titleCtrl.text = map['title']?.toString() ?? '';
        calCtrl.text = map['calories']?.toString() ?? '0';
        proCtrl.text = map['protein']?.toString() ?? '0';
        carbCtrl.text = map['carbs']?.toString() ?? '0';
        fatCtrl.text = map['fat']?.toString() ?? '0';
      }
    } catch (e) {
      debugPrint("Error parsing/extracting meal: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not extract meal data. Please try another image or enter details manually.")),
      );
    } finally {
      setSheetState(() {
        _isExtracting = false;
      });
    }
  }

  void _showAddMealSheet(BuildContext context, AppColorSet colors) {
    final titleCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final proCtrl = TextEditingController();
    final carbCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    String selectedType = 'meal';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: colors.textTertiary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Log Meal', style: AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isExtracting
                              ? null
                              : () => _captureMeal(
                                  ctx,
                                  ImageSource.camera,
                                  setSheetState,
                                  titleCtrl,
                                  calCtrl,
                                  proCtrl,
                                  carbCtrl,
                                  fatCtrl,
                                  colors,
                                ),
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text('Snap Meal'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.brand.withValues(alpha: 0.5)),
                            foregroundColor: AppColors.brand,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isExtracting
                              ? null
                              : () => _captureMeal(
                                  ctx,
                                  ImageSource.gallery,
                                  setSheetState,
                                  titleCtrl,
                                  calCtrl,
                                  proCtrl,
                                  carbCtrl,
                                  fatCtrl,
                                  colors,
                                ),
                          icon: const Icon(Icons.photo_library, size: 18),
                          label: const Text('Upload Photo'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
                            foregroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isExtracting) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Gemma extracting meal data...',
                            style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _sheetField(titleCtrl, 'Meal Title', Icons.restaurant, colors),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _sheetField(calCtrl, 'Calories', Icons.local_fire_department, colors, number: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _sheetField(proCtrl, 'Protein (g)', Icons.fitness_center, colors, number: true)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _sheetField(carbCtrl, 'Carbs (g)', Icons.breakfast_dining, colors, number: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _sheetField(fatCtrl, 'Fat (g)', Icons.opacity, colors, number: true)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    dropdownColor: colors.surfaceAlt,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Meal Type',
                      prefixIcon: const Icon(Icons.schedule, color: AppColors.brand),
                      filled: true,
                      fillColor: colors.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: ['breakfast', 'lunch', 'dinner', 'snack', 'meal'].map((t) =>
                      DropdownMenuItem(value: t, child: Text(t[0].toUpperCase() + t.substring(1))),
                    ).toList(),
                    onChanged: (v) => setSheetState(() => selectedType = v ?? 'meal'),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final vm = context.read<NutritionViewModel>();
                        await vm.logMeal(
                          recipeTitle: titleCtrl.text.isNotEmpty ? titleCtrl.text : 'Quick Meal',
                          calories: double.tryParse(calCtrl.text) ?? 0,
                          protein: double.tryParse(proCtrl.text) ?? 0,
                          carbs: double.tryParse(carbCtrl.text) ?? 0,
                          fat: double.tryParse(fatCtrl.text) ?? 0,
                          mealType: selectedType,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Log Meal'),
                    ),
                  ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String label, IconData icon, AppColorSet colors, {bool number = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.brand, size: 20),
        filled: true,
        fillColor: colors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
