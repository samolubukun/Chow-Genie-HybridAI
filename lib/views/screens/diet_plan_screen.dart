import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/meal_plan.dart';
import '../../models/recipe.dart';
import '../../viewmodels/meal_plan_view_model.dart';
import '../../services/local_db_service.dart';
import '../../services/model_manager.dart';
import '../../widgets/hybrid_ai_badge.dart';
import '../screens/profile_edit_screen.dart';
import '../screens/meal_plan_screen.dart';

class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({super.key});

  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends State<DietPlanScreen> {
  bool _isPlanExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {}

  Future<void> _generatePlan() async {
    final vm = context.read<MealPlanViewModel>();
    final profile = await LocalDbService.instance.getProfile();
    setState(() => _isPlanExpanded = true);
    await vm.generateWeeklyPlan(profile);
  }

  Future<void> _savePlanEntry(String entryText) async {
    if (entryText.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Plan entry saved!'),
        backgroundColor: AppColors.of(context).surfaceAlt,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
    );
    if (result == true) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final vm = context.watch<MealPlanViewModel>();

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        title: const Text('Diet Plan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: colors.textSecondary, size: 22),
            tooltip: 'Edit Profile',
            onPressed: _navigateToEditProfile,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileSummary(colors),
            const SizedBox(height: 24),
            _buildDietPreferences(colors),
            const SizedBox(height: 24),
            _buildGenerateSection(colors, vm),
            if (vm.generatedPlan != null && !vm.isGenerating) ...[
              const SizedBox(height: 24),
              _buildGeneratedPlan(colors, vm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSummary(AppColorSet colors) {
    return FutureBuilder(
      future: LocalDbService.instance.getProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
            gradient: LinearGradient(
              colors: colors.cardGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: AppColors.brandGradient),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.person_rounded, color: colors.textOnBrand, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.name ?? 'Your Profile',
                          style: AppTextStyles.heading3.copyWith(color: colors.textPrimary),
                        ),
                        if (profile?.age != null)
                          Text(
                            '${profile!.age} years',
                            style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _navigateToEditProfile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Edit',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.brand),
                      ),
                    ),
                  ),
                ],
              ),
              if (profile != null) ...[
                const SizedBox(height: 16),
                Divider(color: colors.border, height: 1),
                const SizedBox(height: 16),
                _statRow(
                  colors: colors,
                  icon: Icons.local_fire_department_rounded,
                  label: 'Daily Goal',
                  value: '${profile.dailyCalorieGoal.toStringAsFixed(0)} kcal',
                ),
                const SizedBox(height: 8),
                _statRow(
                  colors: colors,
                  icon: Icons.monitor_weight_outlined,
                  label: 'Weight',
                  value: profile.weightKg != null
                      ? '${profile.weightKg!.toStringAsFixed(1)} kg'
                      : 'Not set',
                ),
                if (profile.heightCm != null) ...[
                  const SizedBox(height: 8),
                  _statRow(
                    colors: colors,
                    icon: Icons.height_rounded,
                    label: 'Height',
                    value: '${profile.heightCm!.toStringAsFixed(0)} cm',
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _statRow({
    required AppColorSet colors,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.textTertiary),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.labelLarge.copyWith(color: colors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildDietPreferences(AppColorSet colors) {
    return FutureBuilder(
      future: LocalDbService.instance.getProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final prefs = profile?.dietaryPreferences ?? [];
        final conditions = profile?.healthConditions ?? [];
        final allergies = profile?.allergies ?? [];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.restaurant_menu_rounded, color: AppColors.brand, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Dietary Profile',
                    style: AppTextStyles.heading3.copyWith(color: colors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (prefs.isEmpty && conditions.isEmpty && allergies.isEmpty)
                Text(
                  'No preferences set. Tap Edit to configure your diet profile.',
                  style: AppTextStyles.bodyMedium.copyWith(color: colors.textTertiary),
                ),
              if (prefs.isNotEmpty) ...[
                Text(
                  'Preferences',
                  style: AppTextStyles.labelLarge.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: prefs.map((p) => _chip(colors, p, AppColors.brand)).toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (conditions.isNotEmpty) ...[
                Text(
                  'Health Conditions',
                  style: AppTextStyles.labelLarge.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: conditions.map((c) => _chip(colors, c, AppColors.accent)).toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (allergies.isNotEmpty) ...[
                Text(
                  'Allergies / Avoid',
                  style: AppTextStyles.labelLarge.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: allergies.map((a) => _chip(colors, a, AppColors.error)).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _chip(AppColorSet colors, String label, Color chipColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: chipColor),
      ),
    );
  }

  Widget _buildGenerateSection(AppColorSet colors, MealPlanViewModel vm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Weekly Meal Plan',
                style: AppTextStyles.heading3.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Generate a personalized 7-day meal plan based on your dietary profile and health goals.',
            style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: vm.isGenerating ? null : _generatePlan,
              icon: vm.isGenerating
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 20),
              label: Text(vm.isGenerating ? 'Generating...' : 'Generate Weekly Plan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: colors.textOnBrand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedPlan(AppColorSet colors, MealPlanViewModel vm) {
    final plan = vm.generatedPlan!;
    final lines = plan.split('\n');
    final days = <String, List<_ParsedMeal>>{};
    String? currentDay;
    final nonDayLines = <String>[];
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      String? detectedDay;
      for (final d in dayNames) {
        final dayPattern = RegExp(
          r'(?:Day\s*\d+\s*[-:]\s*)?(?:[#*_\-\s\[(]*)\b' + d + r'\b(?:[#*_\-\s\]):]*)',
          caseSensitive: false,
        );
        final lower = trimmed.toLowerCase();
        if (dayPattern.hasMatch(trimmed) &&
            !lower.startsWith('breakfast') &&
            !lower.startsWith('lunch') &&
            !lower.startsWith('dinner') &&
            !lower.startsWith('snack')) {
          detectedDay = d;
          break;
        }
      }

      if (detectedDay != null) {
        currentDay = detectedDay;
        days.putIfAbsent(currentDay, () => []);
        continue;
      }

      if (currentDay != null) {
        final lower = trimmed.toLowerCase();
        MealType mealType = MealType.dinner;
        if (lower.contains('breakfast')) {
          mealType = MealType.breakfast;
        } else if (lower.contains('lunch')) {
          mealType = MealType.lunch;
        } else if (lower.contains('dinner')) {
          mealType = MealType.dinner;
        } else if (lower.contains('snack')) {
          mealType = MealType.snack;
        }

        final title = trimmed
            .replaceAll(RegExp(r'^(?:[-*•\d.]+\s*)?(?:\*\*)?(?:Breakfast|Lunch|Dinner|Snack)(?:\*\*)?[:\-]?\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'^\*+|\*+$'), '')
            .trim();

        if (title.isNotEmpty) {
          days[currentDay]!.add(_ParsedMeal(type: mealType, title: title));
        }
      } else {
        nonDayLines.add(trimmed);
      }
    }

    final totalMeals = days.values.fold<int>(0, (sum, list) => sum + list.length);
    final weekStart = vm.currentWeekStart;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final dateRangeStr = '${DateFormat('MMM d').format(weekStart)} – ${DateFormat('MMM d').format(weekEnd)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.auto_awesome, color: AppColors.brand, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Your Weekly Plan',
                      style: AppTextStyles.heading2.copyWith(color: colors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (totalMeals > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$totalMeals meals',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.brand),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Consumer<ModelManager>(
                            builder: (_, mm, __) => HybridAiBadge(
                              isOnDevice: mm.isLatestOnDevice,
                              modelName: mm.latestModelName,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _isPlanExpanded ? 'Collapse plan' : 'Expand plan',
                icon: Icon(
                  _isPlanExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: colors.textSecondary,
                  size: 24,
                ),
                onPressed: () => setState(() => _isPlanExpanded = !_isPlanExpanded),
              ),
              IconButton(
                tooltip: 'Close plan',
                icon: Icon(Icons.close_rounded, color: colors.textSecondary, size: 20),
                onPressed: () async {
                  await vm.clearGeneratedPlan();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (!_isPlanExpanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 20, color: colors.textTertiary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$dateRangeStr • 7-Day Plan ($totalMeals Meals)',
                        style: AppTextStyles.labelLarge.copyWith(color: colors.textPrimary),
                      ),
                      Text(
                        'Tap to expand and view full daily meals or apply to calendar.',
                        style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _isPlanExpanded = true),
                  child: const Text('View Plan', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

        if (_isPlanExpanded) ...[
          // Action Banner: Apply to Interactive Calendar
          if (totalMeals > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.brand.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.calendar_month_rounded, color: AppColors.brand, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$dateRangeStr • 7-Day Plan ($totalMeals Meals)',
                              style: AppTextStyles.labelLarge.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Apply these meals into your interactive weekly calendar to track prep & groceries.',
                              style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _applyPlanToCalendar(context, vm, days),
                      icon: const Icon(Icons.add_task_rounded, size: 20),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Apply Plan to Weekly Calendar',
                          maxLines: 1,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: colors.textOnBrand,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (nonDayLines.isNotEmpty && days.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: MarkdownBody(
                data: nonDayLines.join('\n'),
                styleSheet: MarkdownStyleSheet(
                  p: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
                  strong: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          ...days.entries.map((entry) => _buildDayCard(colors, entry.key, entry.value, vm)),
        ],
      ],
    );
  }

  Future<void> _applyPlanToCalendar(
    BuildContext context,
    MealPlanViewModel vm,
    Map<String, List<_ParsedMeal>> days,
  ) async {
    const uuid = Uuid();
    final entries = <MealPlanEntry>[];

    for (final entry in days.entries) {
      final offset = _dayOffset(entry.key);
      final date = vm.currentWeekStart.add(Duration(days: offset));
      for (final meal in entry.value) {
        final recipeId = 'plan_${uuid.v4()}';
        final parsedIngredients = _extractIngredients(meal.title);

        final recipe = Recipe(
          id: recipeId,
          title: meal.title,
          ingredients: parsedIngredients,
          directions: ['Prepare ${meal.title} with balanced nutrition.', 'Cook thoroughly and serve fresh.'],
          calories: meal.type == MealType.snack ? 180.0 : (meal.type == MealType.breakfast ? 420.0 : 560.0),
          source: 'Weekly Meal Plan',
          isUserGenerated: true,
          createdAt: DateTime.now(),
        );
        await LocalDbService.instance.insertRecipe(recipe);

        entries.add(MealPlanEntry(
          id: uuid.v4(),
          recipeId: recipeId,
          recipeTitle: meal.title,
          mealType: meal.type,
          date: date,
          servings: 2,
          estimatedCalories: recipe.calories,
        ));
      }
    }

    await vm.applyWeeklyPlanEntries(entries, replaceWeek: true);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved ${entries.length} meals to your weekly meal planner!'),
          backgroundColor: AppColors.of(context).surfaceAlt,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'View Planner',
            textColor: AppColors.brand,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MealPlanScreen()));
            },
          ),
        ),
      );
    }
  }

  List<String> _extractIngredients(String title) {
    if (title.trim().isEmpty) return [];

    String cleaned = title
        .replaceAll(RegExp(r'\b(fresh|steamed|baked|grilled|roasted|sauteed|sautéed|boiled|crispy|fried|pan-seared|slow-cooked|homemade|healthy|quick|easy|spicy|sweet|warm|creamy)\b', caseSensitive: false), '')
        .trim();

    final parts = cleaned.split(RegExp(r'\s+(?:with|and|&|served with|topped with|over|on|in)\s+', caseSensitive: false));
    final result = <String>[];
    for (final p in parts) {
      final subparts = p.split(',');
      for (var s in subparts) {
        s = s.replaceAll(RegExp(r'[\(\)\[\]\*]'), '').trim();
        if (s.isNotEmpty && s.length > 2) {
          result.add(s);
        }
      }
    }
    return result.isNotEmpty ? result : [title.trim()];
  }

  Widget _buildDayCard(
    AppColorSet colors,
    String day,
    List<_ParsedMeal> meals,
    MealPlanViewModel vm,
  ) {
    final dayColor = _dayColor(day);
    final offset = _dayOffset(day);
    final dayDate = vm.currentWeekStart.add(Duration(days: offset));
    final dateFormatted = '${dayDate.month}/${dayDate.day}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dayColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: dayColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: dayColor.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dayColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  day,
                  style: AppTextStyles.heading3.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  dateFormatted,
                  style: AppTextStyles.labelSmall.copyWith(color: colors.textTertiary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: dayColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${meals.length} meals',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: dayColor),
                  ),
                ),
              ],
            ),
          ),

          // Meal Slots
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: meals.map((meal) => _buildMealSlotRow(colors, meal)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealSlotRow(AppColorSet colors, _ParsedMeal meal) {
    final typeColor = _mealTypeColor(meal.type);
    final icon = _mealTypeIcon(meal.type);
    final typeLabel = meal.type.name.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: typeColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: typeColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meal.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _mealTypeColor(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return const Color(0xFFF59E0B);
      case MealType.lunch:
        return const Color(0xFF10B981);
      case MealType.dinner:
        return const Color(0xFF6366F1);
      case MealType.snack:
        return const Color(0xFFEC4899);
    }
  }

  IconData _mealTypeIcon(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return Icons.wb_sunny_rounded;
      case MealType.lunch:
        return Icons.restaurant_rounded;
      case MealType.dinner:
        return Icons.dinner_dining_rounded;
      case MealType.snack:
        return Icons.apple_rounded;
    }
  }

  int _dayOffset(String day) {
    switch (day.toLowerCase()) {
      case 'monday': return 0;
      case 'tuesday': return 1;
      case 'wednesday': return 2;
      case 'thursday': return 3;
      case 'friday': return 4;
      case 'saturday': return 5;
      case 'sunday': return 6;
      default: return 0;
    }
  }

  Color _dayColor(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return const Color(0xFFFF6D00);
      case 'tuesday':
        return const Color(0xFF7C3AED);
      case 'wednesday':
        return const Color(0xFF10B981);
      case 'thursday':
        return const Color(0xFF3B82F6);
      case 'friday':
        return const Color(0xFFF59E0B);
      case 'saturday':
        return const Color(0xFFEF4444);
      case 'sunday':
        return const Color(0xFFEC4899);
      default:
        return AppColors.brand;
    }
  }
}

class _ParsedMeal {
  final MealType type;
  final String title;

  const _ParsedMeal({required this.type, required this.title});
}
