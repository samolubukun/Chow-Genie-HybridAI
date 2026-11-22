import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'ask_genie_screen.dart';
import 'recipe_list_screen.dart';
import 'pantry_screen.dart';
import 'mesh_home_screen.dart';
import 'meal_plan_screen.dart';
import 'meal_prep_screen.dart';
import 'nutrition_analytics_screen.dart';
import 'voice_cooking_screen.dart';
import 'diet_plan_screen.dart';
import 'qr_share_screen.dart';
import 'settings_screen.dart';
import 'ingrediguard_screen.dart';
import 'chat_screen.dart';
import '../../viewmodels/nutrition_view_model.dart';
import '../../viewmodels/ingrediguard_view_model.dart';
import '../widgets/wordmark.dart';
import '../../widgets/hybrid_ai_badge.dart';
import '../../services/model_manager.dart';
import '../../models/user_profile.dart';
import '../../models/ingrediguard_result.dart';
import '../../services/local_db_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NutritionViewModel>().loadDay();
      context.read<IngrediGuardViewModel>().loadHistory();
      _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    final profile = await LocalDbService.instance.getProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildDashboard(),
      const RecipeListScreen(),
      const IngrediGuardScreen(),
      const PantryScreen(),
      const MeshHomeScreen(),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.of(context).scaffold,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(AppColors.of(context)),
    );
  }

  Widget _buildDashboard() {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Wordmark(size: 26),
                  const SizedBox(height: 2),
                  Text(
                    _profile != null ? "Welcome back, ${_profile!.name}!" : "Welcome back!",
                    style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Consumer<ModelManager>(
            builder: (context, mm, _) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: HybridAiBadge(
                  isOnDevice: mm.isLatestOnDevice,
                  latencyMs: mm.latestLatencyMs,
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: colors.textPrimary),
            onPressed: () => _navigate(const SettingsScreen()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(colors),
            const SizedBox(height: 24),
            _buildFeatureGrid(colors),
            const SizedBox(height: 24),
            _buildQuickStats(colors),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(AppColorSet colors) {
    final calorieGoal = _profile?.dailyCalorieGoal ?? 2000.0;
    final waterGoal = _profile?.dailyWaterGoal ?? 8.0;

    return Consumer<NutritionViewModel>(
      builder: (context, nvm, _) {
        final caloriesDouble = nvm.dailyTotals['calories'] ?? 0.0;
        final calories = caloriesDouble.toStringAsFixed(0);
        final water = nvm.waterIntake;
        final caloriePercent = (caloriesDouble / calorieGoal).clamp(0.0, 1.0);
        
        final protein = nvm.dailyTotals['protein'] ?? 0.0;
        final carbs = nvm.dailyTotals['carbs'] ?? 0.0;
        final fat = nvm.dailyTotals['fat'] ?? 0.0;
        
        final proteinGoal = _profile?.dailyProteinGoal ?? 50.0;
        final carbsGoal = _profile?.dailyCarbsGoal ?? 250.0;
        final fatGoal = _profile?.dailyFatGoal ?? 65.0;

        final proteinPercent = (protein / proteinGoal).clamp(0.0, 1.0);
        final carbsPercent = (carbs / carbsGoal).clamp(0.0, 1.0);
        final fatPercent = (fat / fatGoal).clamp(0.0, 1.0);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.genieGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's Summary", 
                        style: AppTextStyles.heading2.copyWith(color: Colors.white, fontSize: 20)),
                      const SizedBox(height: 4),
                      Text("Track your daily nutrition goals", 
                        style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: caloriePercent,
                            strokeWidth: 8,
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(calories, 
                              style: AppTextStyles.numericSmall.copyWith(
                                color: Colors.white, 
                                fontSize: 18, 
                                fontWeight: FontWeight.bold
                              )),
                            Text('kcal', 
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.7), 
                                fontSize: 10
                              )),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.local_fire_department, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Text("Goal: ${calorieGoal.toStringAsFixed(0)} kcal", 
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white, 
                                fontWeight: FontWeight.w600,
                                fontSize: 13
                              )),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.water_drop, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Water: $water / ${waterGoal.toStringAsFixed(0)} glasses", 
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: Colors.white, 
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13
                                    )),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: (water / waterGoal).clamp(0.0, 1.0),
                                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                context.read<NutritionViewModel>().addWater();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _macroSummaryProgress("Protein", "${protein.toStringAsFixed(0)}g", proteinPercent),
                    _macroSummaryProgress("Carbs", "${carbs.toStringAsFixed(0)}g", carbsPercent),
                    _macroSummaryProgress("Fat", "${fat.toStringAsFixed(0)}g", fatPercent),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _macroSummaryProgress(String label, String value, double percent) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w500, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.numericSmall.copyWith(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SizedBox(
          width: 65,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureGrid(AppColorSet colors) {
    final features = [
      _FeatureItem('Ask Genie', 'Text & image to recipe creator', Icons.auto_awesome, () => _navigate(const AskGenieScreen())),
      _FeatureItem('ChowGenie Chat', 'Your AI culinary companion', Icons.chat_bubble_outline, () => _navigate(const ChatScreen())),
      _FeatureItem('IngrediGuard', 'Scan & analyze food additives', Icons.security, () => _navigate(const IngrediGuardScreen())),
      _FeatureItem('Meal Planner', 'Schedule your weekly meals', Icons.calendar_month, () => _navigate(const MealPlanScreen())),
      _FeatureItem('Nutrition', 'Log meals & macro tracking', Icons.donut_large, () => _navigate(const NutritionAnalyticsScreen())),
      _FeatureItem('Diet Plan', 'Personalized diet targets', Icons.health_and_safety, () => _navigate(const DietPlanScreen())),
      _FeatureItem('QR Share', 'Share recipes offline via QR', Icons.qr_code, () => _navigate(const QrShareScreen())),
      _FeatureItem('Settings', 'Manage profile & AI models', Icons.settings, () => _navigate(const SettingsScreen())),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: features.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) => _buildFeatureCard(colors, features[index]),
    );
  }

  Widget _buildFeatureCard(AppColorSet colors, _FeatureItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.borderLight.withValues(alpha: isDark ? 0.3 : 0.6),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: isDark ? 0.05 : 0.03),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.genieGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(item.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                item.label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: colors.textPrimary, 
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                item.description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary, 
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(AppColorSet colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer2<NutritionViewModel, IngrediGuardViewModel>(
      builder: (context, nvm, igvm, _) {
        final meals = nvm.todayLogs.length;
        final water = nvm.waterIntake;
        final lastScan = igvm.history.isNotEmpty ? igvm.history.first : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'DAILY TRACKERS',
                style: AppTextStyles.labelMedium.copyWith(
                  color: colors.textTertiary, 
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _metricCard(
                    colors,
                    icon: Icons.restaurant,
                    iconColor: AppColors.brand,
                    title: "Meals Logged",
                    value: "$meals logged",
                    onTap: () => _navigate(const MealPlanScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                    colors,
                    icon: Icons.water_drop,
                    iconColor: AppColors.info,
                    title: "Water Tracker",
                    value: "$water glasses",
                    onTap: () {
                      context.read<NutritionViewModel>().addWater();
                    },
                  ),
                ),
              ],
            ),
            if (lastScan != null) ...[
              const SizedBox(height: 12),
              _lastScanWidget(colors, lastScan),
            ],
          ],
        );
      },
    );
  }

  Widget _metricCard(
    AppColorSet colors, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderLight.withValues(alpha: isDark ? 0.3 : 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, 
                    style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(value, 
                    style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lastScanWidget(AppColorSet colors, IngrediGuardResult lastScan) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scoreColor = lastScan.healthScore >= 80 
        ? AppColors.success 
        : lastScan.healthScore >= 50 
            ? AppColors.warning 
            : AppColors.error;

    return InkWell(
      onTap: () => _navigate(const IngrediGuardScreen()),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderLight.withValues(alpha: isDark ? 0.3 : 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.security, color: scoreColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "LAST SCANNED PRODUCT",
                    style: AppTextStyles.labelMedium.copyWith(color: colors.textTertiary, fontSize: 10, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastScan.productName,
                    style: AppTextStyles.heading3.copyWith(color: colors.textPrimary, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${lastScan.novaGroup} • ${lastScan.harmfulAdditives.length} Additives",
                    style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lastScan.healthScore.toStringAsFixed(0),
                    style: AppTextStyles.numericSmall.copyWith(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    "Score",
                    style: TextStyle(color: scoreColor, fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigate(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadProfile();
  }

  Widget _buildBottomNav(AppColorSet colors) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.brand,
          unselectedItemColor: colors.textTertiary,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          selectedLabelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 10),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 10),
          items: [
            _navItem(Icons.dashboard, 'Dashboard', 0),
            _navItem(Icons.menu_book, 'Recipes', 1),
            _navItem(Icons.security, 'IngrediGuard', 2),
            _navItem(Icons.kitchen, 'Pantry', 3),
            _navItem(Icons.wifi, 'Mesh', 4),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(IconData icon, String label, int index) {
    return BottomNavigationBarItem(
      icon: Icon(icon, size: 22),
      label: label,
    );
  }
}

class _FeatureItem {
  final String label;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  const _FeatureItem(this.label, this.description, this.icon, this.onTap);
}
