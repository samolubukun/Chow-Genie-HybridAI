import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/meal_plan_view_model.dart';
import '../../viewmodels/recipe_view_model.dart';
import '../../models/meal_plan.dart';
import '../../services/local_db_service.dart';
import '../../services/model_manager.dart';
import '../../widgets/hybrid_ai_badge.dart';
import 'meal_prep_screen.dart';
import 'recipe_detail_screen.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  DateTime? _selectedDate;
  bool _showAllWeek = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MealPlanViewModel>().loadWeek();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Color _mealColor(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return AppColors.brand;
      case MealType.lunch:
        return AppColors.success;
      case MealType.dinner:
        return AppColors.accent;
      case MealType.snack:
        return AppColors.warning;
    }
  }

  String _mealIcon(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return '🌅';
      case MealType.lunch:
        return '☀️';
      case MealType.dinner:
        return '🌙';
      case MealType.snack:
        return '🍿';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.scaffold,
      body: Consumer<MealPlanViewModel>(
        builder: (context, vm, _) {
          final weekStart = vm.currentWeekStart;
          final today = DateTime.now();
          final activeDate = _selectedDate ?? (
            (today.isAfter(weekStart.subtract(const Duration(days: 1))) && today.isBefore(weekStart.add(const Duration(days: 7))))
                ? DateTime(today.year, today.month, today.day)
                : weekStart
          );

          final activeDayEntries = vm.entries
              .where((e) => e.date.year == activeDate.year && e.date.month == activeDate.month && e.date.day == activeDate.day)
              .toList();
          final isToday = activeDate.year == today.year && activeDate.month == today.month && activeDate.day == today.day;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: colors.scaffold,
                surfaceTintColor: Colors.transparent,
                title: Text('Meal Plan', style: AppTextStyles.heading2),
                centerTitle: true,
              ),
              SliverToBoxAdapter(child: _buildWeekNavigator(context, vm, colors)),
              SliverToBoxAdapter(child: _buildDayTabs(context, vm, colors, activeDate)),
              if (vm.entries.isNotEmpty)
                SliverToBoxAdapter(child: _buildSmartShoppingBanner(context, vm, colors)),
              if (_showAllWeek) ...[
                // All Week Grouped View
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('All Week Overview', style: AppTextStyles.heading3.copyWith(color: colors.textPrimary)),
                        TextButton.icon(
                          onPressed: () => setState(() => _showAllWeek = false),
                          icon: const Icon(Icons.today_rounded, size: 16),
                          label: const Text('Day View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(foregroundColor: AppColors.brand),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
                        final d = days[index];
                        final dayMeals = vm.entries.where((e) => e.date.year == d.year && e.date.month == d.month && e.date.day == d.day).toList();
                        return _buildGroupedDayCard(context, vm, d, dayMeals, colors);
                      },
                      childCount: 7,
                    ),
                  ),
                ),
              ] else ...[
                // Selected Day View (Grounded with date, clear slots, no 28-meal endless clutter)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isToday ? 'Today • ${DateFormat('EEEE, MMM d').format(activeDate)}' : DateFormat('EEEE, MMM d').format(activeDate),
                                  style: AppTextStyles.heading3.copyWith(color: colors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${activeDayEntries.length} of 4 meals planned',
                                  style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: () => setState(() => _showAllWeek = true),
                              icon: const Icon(Icons.calendar_view_week_rounded, size: 16),
                              label: const Text('All Week', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(foregroundColor: AppColors.brand),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: vm.isLoading ? null : () => _handleGenerateDayWithAi(context, vm, activeDate),
                                icon: const Icon(Icons.auto_awesome, size: 16, color: AppColors.brand),
                                label: const Text('Plan Day with AI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brand)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  side: BorderSide(color: AppColors.brand.withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _showDayDetail(context, vm, activeDate, colors),
                              icon: const Icon(Icons.view_agenda_outlined, size: 16, color: AppColors.accent),
                              label: const Text('Manage Day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final slots = [MealType.breakfast, MealType.lunch, MealType.dinner, MealType.snack];
                        final slot = slots[index];
                        final slotMeals = activeDayEntries.where((e) => e.mealType == slot).toList();

                        if (slotMeals.isNotEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: slotMeals.map((m) => _buildMealEntryCard(context, vm, m, colors)).toList(),
                          );
                        } else {
                          return _buildEmptySlotCard(context, vm, slot, activeDate, colors);
                        }
                      },
                      childCount: 4,
                    ),
                  ),
                ),
              ],
              SliverToBoxAdapter(child: const SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWeekNavigator(BuildContext context, MealPlanViewModel vm, AppColorSet colors) {
    final weekStart = vm.currentWeekStart;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final dateFormat = DateFormat('MMM d');
    final label = '${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            onPressed: vm.isLoading ? null : () => vm.navigateWeek(-1),
          ),
          Column(
            children: [
              Text(label, style: AppTextStyles.labelLarge.copyWith(color: colors.textPrimary)),
              const SizedBox(height: 2),
              Text('Week ${_weekNumber(weekStart)}', style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.brand),
            onPressed: vm.isLoading ? null : () => vm.navigateWeek(1),
          ),
        ],
      ),
    );
  }

  int _weekNumber(DateTime date) {
    final firstOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstOfYear).inDays;
    return ((days + firstOfYear.weekday - 1) / 7).ceil();
  }

  Widget _buildDayTabs(BuildContext context, MealPlanViewModel vm, AppColorSet colors, DateTime activeDate) {
    final weekStart = vm.currentWeekStart;
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();

    return SizedBox(
      height: 88,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = days[index];
          final isSelected = date.year == activeDate.year && date.month == activeDate.month && date.day == activeDate.day;
          final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
          final dayEntries = vm.entries
              .where((e) => e.date.year == date.year && e.date.month == date.month && e.date.day == date.day)
              .toList();

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
                _showAllWeek = false;
              });
            },
            child: Container(
              width: 76,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brand : colors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppColors.brand
                      : (isToday ? AppColors.brand.withValues(alpha: 0.6) : colors.border),
                  width: isToday && !isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayNames[index],
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isSelected ? Colors.white : (isToday ? AppColors.brand : colors.textSecondary),
                      fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: AppTextStyles.numericSmall.copyWith(
                      fontSize: 16,
                      color: isSelected ? Colors.white : colors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (dayEntries.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...dayEntries.take(3).map((e) => Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withValues(alpha: 0.8) : _mealColor(e.mealType),
                            shape: BoxShape.circle,
                          ),
                        )),
                        if (dayEntries.length > 3)
                          Text(
                            '+${dayEntries.length - 3}',
                            style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 8,
                              color: isSelected ? Colors.white : colors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptySlotCard(
    BuildContext context,
    MealPlanViewModel vm,
    MealType slot,
    DateTime date,
    AppColorSet colors,
  ) {
    final slotName = slot.name[0].toUpperCase() + slot.name.substring(1);
    return InkWell(
      onTap: () => _showAddMealSheet(context, vm, slot, date, colors),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _mealColor(slot).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(_mealIcon(slot), style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slotName, style: AppTextStyles.labelMedium.copyWith(color: colors.textPrimary)),
                  Text('No meal scheduled for $slotName', style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary)),
                ],
              ),
            ),
            const Icon(Icons.add_circle_outline_rounded, color: AppColors.brand, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedDayCard(
    BuildContext context,
    MealPlanViewModel vm,
    DateTime date,
    List<MealPlanEntry> dayMeals,
    AppColorSet colors,
  ) {
    final dayName = DateFormat('EEEE, MMM d').format(date);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dayName, style: AppTextStyles.labelLarge.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold)),
              Text('${dayMeals.length} meals', style: AppTextStyles.bodySmall.copyWith(color: AppColors.brand, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          if (dayMeals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No meals scheduled', style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary)),
            )
          else
            ...dayMeals.map((m) => _buildMealEntryCard(context, vm, m, colors)),
        ],
      ),
    );
  }

  Widget _buildMealEntryCard(BuildContext context, MealPlanViewModel vm, MealPlanEntry entry, AppColorSet colors) {
    final mealColor = _mealColor(entry.mealType);

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      onDismissed: (_) => vm.removeEntry(entry.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: InkWell(
          onTap: () => _showMealOptionsSheet(context, vm, entry, colors),
          child: Row(
            children: [
            Container(
              width: 6,
              height: 50,
              decoration: BoxDecoration(
                color: mealColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.recipeTitle,
                    maxLines: 2,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        entry.mealType.name[0].toUpperCase() + entry.mealType.name.substring(1),
                        style: AppTextStyles.labelSmall.copyWith(color: mealColor),
                      ),
                      const SizedBox(width: 8),
                      if (entry.estimatedCalories != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${entry.estimatedCalories!.toStringAsFixed(0)} cal',
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.brand, fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.more_vert_rounded, color: colors.textTertiary, size: 20),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildEmptyState(AppColorSet colors, MealPlanViewModel vm) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_month, size: 48, color: AppColors.brand),
            ),
            const SizedBox(height: 24),
            Text(
              'No meals planned yet',
              style: AppTextStyles.heading2.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap a day slot to add a meal, or generate a full weekly plan',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isLoading,
    required VoidCallback onTap,
    required AppColorSet colors,
    bool isSecondary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: isSecondary
          ? OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 20),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.textPrimary,
                side: BorderSide(color: colors.border),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            )
          : ElevatedButton.icon(
              onPressed: isLoading ? null : onTap,
              icon: isLoading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome, size: 20),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
    );
  }

  void _showDayDetail(BuildContext context, MealPlanViewModel vm, DateTime date, AppColorSet colors) {
    final dayEntries = vm.entries
        .where((e) => e.date.year == date.year && e.date.month == date.month && e.date.day == date.day)
        .toList();
    final dayName = DateFormat('EEEE').format(date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
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
                  Text(dayName, style: AppTextStyles.heading1.copyWith(color: colors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(date),
                    style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  for (final type in MealType.values) ...[
                    _buildSlotRow(context, vm, type, date, colors, dayEntries),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotRow(
    BuildContext context,
    MealPlanViewModel vm,
    MealType type,
    DateTime date,
    AppColorSet colors,
    List<MealPlanEntry> entries,
  ) {
    final mealEntries = entries.where((e) => e.mealType == type).toList();
    final mealColor = _mealColor(type);

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _showAddMealSheet(context, vm, type, date, colors);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: mealColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _mealIcon(type),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.name[0].toUpperCase() + type.name.substring(1),
                    style: AppTextStyles.labelLarge.copyWith(color: colors.textPrimary),
                  ),
                  if (mealEntries.isNotEmpty)
                    Text(
                      mealEntries.first.recipeTitle,
                      style: AppTextStyles.bodySmall.copyWith(color: mealColor),
                    ),
                ],
              ),
            ),
            if (mealEntries.isEmpty)
              Icon(Icons.add_circle_outline, color: colors.textTertiary, size: 22)
            else
              Text(
                '${mealEntries.first.estimatedCalories?.toStringAsFixed(0) ?? "?"} cal',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.brand),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddMealSheet(BuildContext context, MealPlanViewModel vm, MealType type, DateTime date, AppColorSet colors) {
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _mealColor(type).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_mealIcon(type), style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add ${type.name[0].toUpperCase() + type.name.substring(1)}',
                    style: AppTextStyles.heading2.copyWith(color: colors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchController,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search recipes...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.brand),
                  filled: true,
                  fillColor: colors.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (q) => context.read<RecipeViewModel>().search(q),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: Consumer<RecipeViewModel>(
                  builder: (context, rvm, _) {
                    final results = rvm.searchResults;
                    if (results.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, color: colors.textTertiary, size: 32),
                            const SizedBox(height: 8),
                            Text('Search recipes to add', style: AppTextStyles.bodyMedium.copyWith(color: colors.textTertiary)),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (ctx, i) {
                        final recipe = results[i];
                        return ListTile(
                          leading: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.restaurant, color: AppColors.brand, size: 20),
                          ),
                          title: Text(recipe.title, style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary)),
                          subtitle: Text(
                            '${recipe.calories?.toStringAsFixed(0) ?? "?"} cal',
                            style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                          ),
                          onTap: () async {
                            final existing = vm.entries.where((e) =>
                                e.date.year == date.year &&
                                e.date.month == date.month &&
                                e.date.day == date.day &&
                                e.mealType == type).toList();
                            for (final ex in existing) {
                              await vm.removeEntry(ex.id);
                            }

                            final entry = MealPlanEntry(
                              id: DateTime.now().microsecondsSinceEpoch.toString(),
                              recipeId: recipe.id,
                              recipeTitle: recipe.title,
                              mealType: type,
                              date: date,
                              estimatedCalories: recipe.calories,
                            );
                            await vm.addEntry(entry);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showGenerateForSlot(context, vm, type, date, colors);
                  },
                  icon: const Icon(Icons.auto_awesome, size: 16, color: AppColors.accent),
                  label: const Text('Generate with AI', style: TextStyle(color: AppColors.accent)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGenerateForSlot(BuildContext context, MealPlanViewModel vm, MealType type, DateTime date, AppColorSet colors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(_mealIcon(type), style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text('Generate ${type.name[0].toUpperCase() + type.name.substring(1)}', style: AppTextStyles.heading3),
          ],
        ),
        content: Text('Use AI to suggest a meal for this slot?', style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Generating meal suggestion via Hybrid AI...',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );

              final profile = await LocalDbService.instance.getProfile();
              final existing = vm.entries.where((e) =>
                  e.date.year == date.year &&
                  e.date.month == date.month &&
                  e.date.day == date.day &&
                  e.mealType == type).toList();
              for (final ex in existing) {
                await vm.removeEntry(ex.id);
              }

              final entry = await vm.suggestAndAddMealForSlot(
                type: type,
                date: date,
                profile: profile,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                if (entry != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.brand, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Added "${entry.recipeTitle}" to your meal plan!')),
                        ],
                      ),
                      backgroundColor: colors.surfaceAlt,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Could not generate meal suggestion. Please try again.'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGenerateDayWithAi(BuildContext context, MealPlanViewModel vm, DateTime date) async {
    final colors = AppColors.of(context);
    final dayName = DateFormat('EEEE, MMM d').format(date);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.brand, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text('Plan $dayName', style: AppTextStyles.heading3)),
          ],
        ),
        content: Text(
          'ChowGenie Hybrid AI will generate a complete 4-slot day plan (Breakfast, Lunch, Dinner, Snack) tailored to your dietary goals.\n\nAny existing meals for this day will be refreshed.',
          style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Generate Day Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Generating full day plan for $dayName with Hybrid AI...')),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final profile = await LocalDbService.instance.getProfile();
    final results = await vm.generateMealsForDay(date, profile: profile);

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (results.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.brand, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Generated ${results.length} meals for $dayName!')),
              ],
            ),
            backgroundColor: colors.surfaceAlt,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showMealOptionsSheet(BuildContext context, MealPlanViewModel vm, MealPlanEntry entry, AppColorSet colors) {
    final mealColor = _mealColor(entry.mealType);
    final slotName = entry.mealType.name[0].toUpperCase() + entry.mealType.name.substring(1);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(_mealIcon(entry.mealType), style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(slotName.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: mealColor, fontWeight: FontWeight.bold)),
                        Text(entry.recipeTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.heading3.copyWith(color: colors.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.restaurant_menu_rounded, color: AppColors.brand),
                title: const Text('View Recipe Details'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final recipe = await LocalDbService.instance.getRecipe(entry.recipeId);
                  if (recipe != null && context.mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)));
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recipe details for "${entry.recipeTitle}"')));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded, color: AppColors.brand),
                title: const Text('Swap from 73k Recipe Bank'),
                subtitle: const Text('Search and replace this slot from your recipe collection'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddMealSheet(context, vm, entry.mealType, entry.date, colors);
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: AppColors.accent),
                title: const Text('Re-generate with AI'),
                subtitle: const Text('Have Hybrid AI generate a brand new recipe for this slot'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showGenerateForSlot(context, vm, entry.mealType, entry.date, colors);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text('Remove from Day', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  vm.removeEntry(entry.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGeneratedPlanDialog(BuildContext context, String plan, AppColorSet colors) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
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

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: Column(
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
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.brand, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Your Weekly Plan', style: AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  Consumer<ModelManager>(
                    builder: (_, mm, __) => Flexible(
                      child: HybridAiBadge(
                        isOnDevice: mm.isLatestOnDevice,
                        modelName: 'Gemini Flash',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close plan',
                    icon: Icon(Icons.close, color: colors.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
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
                    ...days.entries.map((entry) {
                      final day = entry.key;
                      final meals = entry.value;
                      
                      Color dayColor = AppColors.brand;
                      switch (day.toLowerCase()) {
                        case 'monday': dayColor = const Color(0xFFFF6D00); break;
                        case 'tuesday': dayColor = const Color(0xFF7C3AED); break;
                        case 'wednesday': dayColor = const Color(0xFF10B981); break;
                        case 'thursday': dayColor = const Color(0xFF3B82F6); break;
                        case 'friday': dayColor = const Color(0xFFF59E0B); break;
                        case 'saturday': dayColor = const Color(0xFFEF4444); break;
                        case 'sunday': dayColor = const Color(0xFFEC4899); break;
                      }

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
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSmartShoppingBanner(BuildContext context, MealPlanViewModel vm, AppColorSet colors) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
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
                  color: AppColors.brand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shopping_cart_checkout, color: AppColors.brand, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Grocery List Generator',
                      style: AppTextStyles.labelLarge.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Cross-checks ${vm.entries.length} planned meals against your pantry stock',
                      style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
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
              onPressed: vm.isLoading ? null : () => _handleGenerateSmartList(context, vm, colors),
              icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Add Missing Items to Shopping List',
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGenerateSmartList(BuildContext context, MealPlanViewModel vm, AppColorSet colors) async {
    final result = await vm.generateSmartShoppingList();
    if (!context.mounted) return;

    final missing = (result['missingAdded'] as List<String>?) ?? [];
    final pantryCount = (result['pantryCount'] as int?) ?? 0;
    final mealCount = (result['mealCount'] as int?) ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.success, size: 24),
                  const SizedBox(width: 10),
                  Text('Grocery Sync Complete', style: AppTextStyles.heading3.copyWith(color: colors.textPrimary)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Scanned $mealCount meals. Found $pantryCount ingredients already in your pantry. Added ${missing.length} missing items to your shopping list.',
                style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (missing.isNotEmpty) ...[
                Text('Added Items:', style: AppTextStyles.labelMedium.copyWith(color: colors.textTertiary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: missing.map((item) => Container(
                    constraints: const BoxConstraints(maxWidth: 220),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: colors.textPrimary)),
                  )).toList(),
                ),
                const SizedBox(height: 20),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
