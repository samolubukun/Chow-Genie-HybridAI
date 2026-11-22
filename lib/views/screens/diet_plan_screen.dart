import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/meal_plan_view_model.dart';
import '../../services/local_db_service.dart';
import '../screens/profile_edit_screen.dart';

class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({super.key});

  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends State<DietPlanScreen> {
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {}

  Future<void> _generatePlan() async {
    final vm = context.read<MealPlanViewModel>();
    final profile = await LocalDbService.instance.getProfile();
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
    final days = <String, List<String>>{};
    String? currentDay;
    final nonDayLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final dayMatch = RegExp(r'^(?:#|\*|-|\s)*(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)', caseSensitive: false)
          .firstMatch(trimmed);
      if (dayMatch != null) {
        currentDay = dayMatch.group(1)!;
        days.putIfAbsent(currentDay, () => []);
        continue;
      }

      if (currentDay != null) {
        days[currentDay]!.add(trimmed);
      } else {
        nonDayLines.add(trimmed);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.brand, size: 20),
            const SizedBox(width: 8),
            Text(
              'Your Weekly Plan',
              style: AppTextStyles.heading2.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (nonDayLines.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkdownBody(
                  data: nonDayLines.join('\n'),
                  styleSheet: MarkdownStyleSheet(
                    p: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
                    strong: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ...days.entries.map((entry) => _buildDayCard(colors, entry.key, entry.value)),
      ],
    );
  }

  Widget _buildDayCard(AppColorSet colors, String day, List<String> meals) {
    final dayColor = _dayColor(day);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dayColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4, height: 24,
                decoration: BoxDecoration(
                  color: dayColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                day,
                style: AppTextStyles.heading3.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...meals.map((meal) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, size: 6, color: dayColor),
                const SizedBox(width: 10),
                Expanded(
                  child: MarkdownBody(
                    data: meal,
                    styleSheet: MarkdownStyleSheet(
                      p: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
                      strong: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
                      pPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
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
