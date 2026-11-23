import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/ingrediguard_view_model.dart';
import '../../viewmodels/chat_view_model.dart';
import '../../services/model_manager.dart';
import '../../widgets/hybrid_ai_badge.dart';
import '../../models/ingrediguard_result.dart';
import '../widgets/capture_prompt_card.dart';
import '../widgets/nutrient_result_card.dart';
import 'chat_screen.dart';

class IngrediGuardScreen extends StatelessWidget {
  const IngrediGuardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.scaffold,
      body: Consumer<IngrediGuardViewModel>(
        builder: (context, vm, _) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                pinned: true,
                expandedHeight: 110,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                  title: Row(
                    children: [
                      const Icon(Icons.security, color: AppColors.brand, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'IngrediGuard',
                        style: AppTextStyles.displaySmall.copyWith(fontSize: 24),
                      ),
                    ],
                  ),
                  collapseMode: CollapseMode.pin,
                ),
                actions: [
                  if (vm.history.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.delete_sweep_outlined, color: colors.textSecondary),
                      tooltip: 'Clear History',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: colors.surface,
                            title: const Text('Clear Scan History?'),
                            content: const Text('This will delete all previous IngrediGuard scans from this device.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
                              ),
                              TextButton(
                                onPressed: () {
                                  vm.clearHistory();
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Clear', style: TextStyle(color: AppColors.error)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      if (!vm.hasImage) ...[
                        CapturePromptCard(
                          icon: Icons.shield_outlined,
                          title: 'Analyze Ingredient Label',
                          subtitle: 'Scan food ingredients to detect seed oils, ultra-processed NOVA levels, and biochemical additives.',
                          iconColor: AppColors.brand,
                          onCameraTap: () => vm.takePhoto(),
                          onGalleryTap: () => vm.pickImage(),
                        ),
                        if (vm.history.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'SCAN HISTORY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: vm.history.length,
                            itemBuilder: (context, index) {
                              final item = vm.history[index];
                              return _buildHistoryItem(context, item, vm);
                            },
                          ),
                        ] else ...[
                          const SizedBox(height: 48),
                          Icon(Icons.health_and_safety_outlined, size: 64, color: colors.textTertiary),
                          const SizedBox(height: 12),
                          Text(
                            'Your scanned items will appear here.',
                            style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ],
                      if (vm.hasImage)
                        ImagePreviewCard(
                          imagePath: vm.image!.path,
                          height: 280,
                          onClose: () => vm.clearImage(),
                          actions: vm.isAnalyzing
                              ? null
                              : Row(
                                  children: [
                                    Expanded(
                                      child: _ActionBtn(
                                        icon: Icons.auto_awesome,
                                        label: 'Analyze Ingredients',
                                        color: AppColors.brand,
                                        onTap: () => vm.analyze(),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _ActionBtn(
                                        icon: Icons.swap_horiz_rounded,
                                        label: 'Retake',
                                        color: colors.textSecondary,
                                        onTap: () => vm.clearImage(),
                                        filled: false,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      if (vm.isAnalyzing)
                        const AnalyzingIndicator(
                          title: 'Analyzing Ingredients...',
                          subtitle: 'Analyzing ingredients via Firebase Hybrid AI...',
                        ),
                      if (vm.hasResult && vm.result != null)
                        _buildScanResults(context, vm, vm.result!),
                      if (vm.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: ErrorBanner(
                            message: vm.errorMessage!,
                            onDismiss: () => vm.clearResults(),
                          ),
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, IngrediGuardResult item, IngrediGuardViewModel vm) {
    final colors = AppColors.of(context);
    final scoreColor = _getScoreColor(item.healthScore);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scoreColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              item.healthScore.toStringAsFixed(0),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: scoreColor,
              ),
            ),
          ),
        ),
        title: Text(
          item.productName,
          style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary, fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: item.novaGroup == 'NOVA 4' ? AppColors.error.withValues(alpha: 0.1) : colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.novaGroup,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: item.novaGroup == 'NOVA 4' ? AppColors.error : colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (item.hasSeedOils)
                Text(
                  '⚠️ Seed Oils',
                  style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600),
                )
              else
                Text(
                  '🌱 Clean Oils',
                  style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: colors.textTertiary),
        onTap: () {
          // Open the scanned item details
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (_, controller) => Container(
                decoration: BoxDecoration(
                  color: colors.scaffold,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView(
                  controller: controller,
                  children: [
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 24),
                    _buildScanResults(context, vm, item, isBottomSheet: true),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScanResults(BuildContext context, IngrediGuardViewModel vm, IngrediGuardResult result, {bool isBottomSheet = false}) {
    final colors = AppColors.of(context);
    final scoreColor = _getScoreColor(result.healthScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isBottomSheet) const SizedBox(height: 20),
        
        // Product Name and Hybrid AI Micro-Pill
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                result.productName,
                style: AppTextStyles.displaySmall.copyWith(fontSize: 24, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Consumer<ModelManager>(
              builder: (_, mm, __) => HybridAiBadge(
                isOnDevice: mm.isLatestOnDevice,
                latencyMs: mm.latestLatencyMs,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Score Row & NOVA Group Card
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score gauge
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 80,
                      width: 80,
                      child: Stack(
                        children: [
                          Center(
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                value: result.healthScore / 100,
                                strokeWidth: 8,
                                color: scoreColor,
                                backgroundColor: colors.border,
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              result.healthScore.toStringAsFixed(0),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Safety Score',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // NOVA status card
            Expanded(
              flex: 5,
              child: NovaCard(result: result),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Seed Oils Indicator
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: result.hasSeedOils ? AppColors.warning.withValues(alpha: 0.08) : AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: result.hasSeedOils ? AppColors.warning.withValues(alpha: 0.3) : AppColors.success.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                result.hasSeedOils ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                color: result.hasSeedOils ? AppColors.warning : AppColors.success,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.hasSeedOils ? 'Inflammatory Seed Oils Detected' : 'No Inflammatory Seed Oils Found',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.hasSeedOils
                          ? 'Contains: ${result.detectedSeedOils.join(", ")}. Seed oils can cause systemic cellular inflammation.'
                          : 'This product uses cleaner, healthy oil alternatives (e.g. olive oil, avocado oil, coconut oil, or no oils).',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Flagged Additives section
        Row(
          children: [
            Text(
              'ADDITIVES DETECTED',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textTertiary, letterSpacing: 0.5),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${result.harmfulAdditives.length}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (result.harmfulAdditives.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: AppColors.success, size: 22),
                const SizedBox(width: 12),
                Text(
                  'No harmful additives detected!',
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ...result.harmfulAdditives.map((additive) => _buildAdditiveTile(context, additive)),

        const SizedBox(height: 24),

        // Clean Swaps Section
        if (result.cleanSwaps.isNotEmpty) ...[
          Text(
            'HEALTHIER ALTERNATIVES',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          ...result.cleanSwaps.map((swap) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        swap,
                        style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 24),
        ],

        // Sparkle chat query button
        GestureDetector(
          onTap: () {
            // Dismiss bottom sheet if open
            if (isBottomSheet) {
              Navigator.pop(context);
            }
            context.read<ChatViewModel>().setContext(
                  'I just checked a product via IngrediGuard: ${result.productName}. '
                  'Safety Score: ${result.healthScore.toStringAsFixed(0)}/100, '
                  'NOVA level: ${result.novaGroup}. '
                  'Additives found: ${result.harmfulAdditives.map((a) => a.name).join(", ")}. '
                  'Seed oils present: ${result.hasSeedOils ? result.detectedSeedOils.join(", ") : "None"}. '
                  'Tell me more about the hazards in this product.',
                );
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFFF9E00), width: 1.5),
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFFF9E00), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Ask Genie about these ingredients',
                    style: TextStyle(
                      color: Color(0xFFFF9E00),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdditiveTile(BuildContext context, AdditiveHazard additive) {
    final colors = AppColors.of(context);
    final riskColor = _getRiskColor(additive.risk);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(
            Icons.biotech,
            color: riskColor,
            size: 22,
          ),
          title: Text(
            additive.name,
            style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary, fontSize: 14),
          ),
          subtitle: Text(
            '${additive.category} • ${additive.risk.name.toUpperCase()} RISK',
            style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          trailing: Icon(Icons.keyboard_arrow_down, color: colors.textTertiary, size: 18),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      additive.description,
                      style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.4),
                    ),
                    if (additive.hazards.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: additive.hazards.map((hazard) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: riskColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: riskColor.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            hazard,
                            style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  Color _getRiskColor(RiskLevel risk) {
    switch (risk) {
      case RiskLevel.high:
        return AppColors.error;
      case RiskLevel.moderate:
        return AppColors.warning;
      case RiskLevel.low:
        return AppColors.success;
    }
  }
}

class NovaCard extends StatefulWidget {
  final IngrediGuardResult result;

  const NovaCard({super.key, required this.result});

  @override
  State<NovaCard> createState() => _NovaCardState();
}

class _NovaCardState extends State<NovaCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isNova4 = widget.result.novaGroup == 'NOVA 4';
    final description = widget.result.processingDescription;
    final isLong = description.length > 60;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isNova4 
                      ? AppColors.error.withValues(alpha: 0.1) 
                      : AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.result.novaGroup,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isNova4 ? AppColors.error : AppColors.success,
                  ),
                ),
              ),
              if (isLong)
                GestureDetector(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: colors.textSecondary,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 11,
              height: 1.3,
              color: colors.textPrimary,
            ),
            maxLines: _isExpanded ? null : 4,
            overflow: _isExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
          ),
          if (isLong && !_isExpanded)
            GestureDetector(
              onTap: () => setState(() => _isExpanded = true),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See more',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 12,
                      color: AppColors.brand,
                    ),
                  ],
                ),
              ),
            )
          else if (isLong && _isExpanded)
            GestureDetector(
              onTap: () => setState(() => _isExpanded = false),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See less',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_up,
                      size: 12,
                      color: AppColors.brand,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: filled ? color : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: filled ? colors.textOnBrand : colors.textPrimary),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: filled ? colors.textOnBrand : colors.textPrimary,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
