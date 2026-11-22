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
              SliverToBoxAdapter(child: _buildDayTabs(context, vm, colors)),
              if (vm.entries.isNotEmpty)
                SliverToBoxAdapter(child: _buildSmartShoppingBanner(context, vm, colors)),
              if (vm.entries.isEmpty && !vm.isLoading)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(colors, vm),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final entry = vm.entries[index];
                        return _buildMealEntryCard(context, vm, entry, colors);
                      },
                      childCount: vm.entries.length,
                    ),
                  ),
                ),
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

  Widget _buildDayTabs(BuildContext context, MealPlanViewModel vm, AppColorSet colors) {
    final weekStart = vm.currentWeekStart;
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();
    final isCurrentWeek = today.isAfter(weekStart.subtract(const Duration(days: 1))) &&
        today.isBefore(weekStart.add(const Duration(days: 7)));

    return SizedBox(
      height: 88,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = days[index];
          final isToday = isCurrentWeek && date.day == today.day && date.month == today.month;
          final dayEntries = vm.entries
              .where((e) => e.date.year == date.year && e.date.month == date.month && e.date.day == date.day)
              .toList();

          return GestureDetector(
            onTap: () => _showDayDetail(context, vm, date, colors),
            child: Container(
              width: 76,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: isToday ? AppColors.brand : colors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isToday ? AppColors.brand : colors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayNames[index],
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isToday ? Colors.white : colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: AppTextStyles.numericSmall.copyWith(
                      fontSize: 16,
                      color: isToday ? Colors.white : colors.textPrimary,
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
                            color: _mealColor(e.mealType),
                            shape: BoxShape.circle,
                          ),
                        )),
                        if (dayEntries.length > 3)
                          Text(
                            '+${dayEntries.length - 3}',
                            style: AppTextStyles.labelSmall.copyWith(fontSize: 8, color: colors.textTertiary),
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
          onTap: () async {
            final recipe = await LocalDbService.instance.getRecipe(entry.recipeId);
            if (recipe != null && context.mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)));
            }
          },
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
            Icon(Icons.drag_handle, color: colors.textTertiary, size: 20),
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
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Generating meal suggestion...'),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
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
                  const Icon(Icons.auto_awesome, color: AppColors.brand, size: 24),
                  const SizedBox(width: 8),
                  Text('Your Weekly Plan', style: AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
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
            height: 42,
            child: ElevatedButton.icon(
              onPressed: vm.isLoading ? null : () => _handleGenerateSmartList(context, vm, colors),
              icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
              label: const Text('Add Missing Items to Shopping List', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(item, style: TextStyle(fontSize: 12, color: colors.textPrimary)),
                  )).toList(),
                ),
                const SizedBox(height: 20),
              ],
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
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
