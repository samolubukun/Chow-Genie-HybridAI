import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class IngredientChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const IngredientChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brand.withValues(alpha: 0.15)
              : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.brand : colors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: selected ? AppColors.brand : colors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
