import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../services/local_db_service.dart';
import '../../services/model_manager.dart';
import '../../viewmodels/theme_view_model.dart';
import 'profile_edit_screen.dart';
import 'model_download_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    final profile = await LocalDbService.instance.getProfile();
    final meshIdentity = await LocalDbService.instance.getMeshIdentity();
    return {
      'profile': profile,
      'meshName': meshIdentity['displayName'] ?? 'Not set',
      'meshPeerId': meshIdentity['id'] ?? '--',
    };
  }

  void _refresh() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          final profile = snapshot.data?['profile'];
          final meshName = snapshot.data?['meshName'] as String? ?? 'Not set';
          final meshPeerId = snapshot.data?['meshPeerId'] as String? ?? '--';
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              _sectionHeader(colors, 'Profile'),
              const SizedBox(height: 12),
              _profileCard(context, colors, profile),
              const SizedBox(height: 28),

              _sectionHeader(colors, 'Health Profile'),
              const SizedBox(height: 12),
              _healthProfileCard(context, colors, profile),
              const SizedBox(height: 28),

              _sectionHeader(colors, 'Diet Goals'),
              const SizedBox(height: 12),
              _dietGoalsCard(context, colors, profile),
              const SizedBox(height: 28),

              _sectionHeader(colors, 'Mesh Identity'),
              const SizedBox(height: 12),
              _meshCard(colors, meshName, meshPeerId),
              const SizedBox(height: 28),

              _sectionHeader(colors, 'AI Engine'),
              const SizedBox(height: 12),
              _menuItem(context, colors,
                icon: Icons.psychology,
                label: 'Firebase Hybrid AI',
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: colors.card,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (ctx) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Firebase AI Logic Hybrid Inference', style: AppTextStyles.heading2),
                          const SizedBox(height: 12),
                          Text('• On-Device Engine: Gemini Nano (AICore local execution)', style: AppTextStyles.bodyMedium),
                          const SizedBox(height: 6),
                          Text('• Cloud Fallback: Gemini 3.5 Flash', style: AppTextStyles.bodyMedium),
                          const SizedBox(height: 6),
                          Text('• App Check Security: Active (Debug Provider)', style: AppTextStyles.bodyMedium),
                          const SizedBox(height: 6),
                          Text('• Remote Config: Connected (PREFER_ON_DEVICE)', style: AppTextStyles.bodyMedium),
                          const SizedBox(height: 6),
                          Text('• Cloud Firestore: Auto-syncing recipes', style: AppTextStyles.bodyMedium),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
                              child: const Text('Close'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),

              _sectionHeader(colors, 'Theme'),
              const SizedBox(height: 12),
              Consumer<ThemeViewModel>(
                builder: (context, themeVm, _) {
                  final brightness = MediaQuery.of(context).platformBrightness;
                  final isDark = themeVm.effectiveIsDark(brightness);
                  return _menuItem(context, colors,
                    icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                    label: 'Dark Mode',
                    trailing: Switch(
                      value: isDark,
                      onChanged: (val) => themeVm.setDark(val),
                      activeTrackColor: AppColors.brand,
                      activeThumbColor: AppColors.brand,
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),

              _sectionHeader(colors, 'About'),
              const SizedBox(height: 12),
              _menuItem(context, colors,
                icon: Icons.info_outline,
                label: 'Version',
                trailing: Text('2.0.0', style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary)),
              ),
              _menuItem(context, colors,
                icon: Icons.description_outlined,
                label: 'Licenses',
                onTap: () => showLicensePage(context: context),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(AppColorSet colors, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title,
        style: AppTextStyles.labelMedium.copyWith(color: colors.textTertiary, letterSpacing: 1)),
    );
  }

  Widget _profileCard(BuildContext context, AppColorSet colors, dynamic profile) {
    if (profile == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: colors.surfaceAlt, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.person, color: colors.textTertiary),
            ),
            const SizedBox(width: 16),
            Text('No profile', style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary)),
            const Spacer(),
            Icon(Icons.chevron_right, color: colors.textTertiary),
          ],
        ),
      );
    }
    return InkWell(
      onTap: () async {
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ProfileEditScreen(section: ProfileEditSection.personal),
          ),
        );
        if (updated == true) _refresh();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.brandGradient),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(Icons.person, size: 28, color: colors.textOnBrand),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.name, style: AppTextStyles.heading3.copyWith(color: colors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('${profile.dailyCalorieGoal.toStringAsFixed(0)} kcal daily goal  •  ${profile.age ?? '-'} yrs',
                      style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _healthProfileCard(BuildContext context, AppColorSet colors, dynamic profile) {
    return InkWell(
      onTap: () async {
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ProfileEditScreen(section: ProfileEditSection.health),
          ),
        );
        if (updated == true) _refresh();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.favorite_outline, color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Health & Diet', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    profile != null && profile.healthConditions.isNotEmpty
                        ? profile.healthConditions.join(', ')
                        : 'No conditions set',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _dietGoalsCard(BuildContext context, AppColorSet colors, dynamic profile) {
    return InkWell(
      onTap: () async {
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ProfileEditScreen(section: ProfileEditSection.goals),
          ),
        );
        if (updated == true) _refresh();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Goal Type',
                          style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary)),
                      const SizedBox(height: 4),
                      Text(
                        profile?.dietGoal != null ? profile.dietGoal : 'Not set',
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Target Weight',
                          style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary)),
                      const SizedBox(height: 4),
                      Text(
                        profile?.targetWeightKg != null ? '${profile.targetWeightKg} kg' : 'Not set',
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Water Goal',
                          style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary)),
                      const SizedBox(height: 4),
                      Text(
                        '${profile?.dailyWaterGoal?.toStringAsFixed(0) ?? '8'} cups',
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Calorie Goal: ',
                    style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary)),
                Text('${profile?.dailyCalorieGoal?.toStringAsFixed(0) ?? '2000'} kcal/day',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.brand, fontWeight: FontWeight.w600)),
                const Spacer(),
                Icon(Icons.chevron_right, color: colors.textTertiary, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _meshCard(AppColorSet colors, String displayName, String peerId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.wifi_tethering, color: AppColors.brand, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                const SizedBox(height: 2),
                Text('Peer ID: $peerId',
                    style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(BuildContext context, AppColorSet colors, {
    required IconData icon,
    required String label,
    Widget? trailing,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? colors.textSecondary, size: 22),
        title: Text(label, style: AppTextStyles.bodyLarge.copyWith(color: colors.textPrimary)),
        trailing: trailing ?? Icon(Icons.chevron_right, color: colors.textTertiary, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: colors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
