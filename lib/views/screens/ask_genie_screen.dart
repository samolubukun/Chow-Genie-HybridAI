import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/recipe_view_model.dart';
import '../../viewmodels/pantry_view_model.dart';
import '../../services/model_manager.dart';
import '../../widgets/hybrid_ai_badge.dart';

import '../../services/local_db_service.dart';

class AskGenieScreen extends StatefulWidget {
  const AskGenieScreen({super.key});

  @override
  State<AskGenieScreen> createState() => _AskGenieScreenState();
}

class _AskGenieScreenState extends State<AskGenieScreen> {
  int _selectedTab = 0;
  final _ingredientsController = TextEditingController();
  String _dietPref = 'None';
  bool _makeItHealthy = false;
  String? _imagePath;
  final _imagePicker = ImagePicker();

  final _dietOptions = [
    'None',
    'Vegan',
    'Keto',
    'Gluten-Free',
    'Low-Carb',
    'High-Protein',
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _ingredientsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imagePath = picked.path);
    }
  }

  Future<void> _captureImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() => _imagePath = picked.path);
    }
  }

  Future<void> _generateFromIngredients() async {
    final vm = context.read<RecipeViewModel>();
    final ingredients = _ingredientsController.text.trim();
    if (ingredients.isEmpty) return;

    final profile = await LocalDbService.instance.getProfile();

    await vm.generateRecipeFromIngredients(
      ingredients: ingredients,
      preference: _dietPref == 'None' ? null : _dietPref,
      healthy: _makeItHealthy,
      profile: profile,
    );
  }

  Future<void> _generateFromImage() async {
    if (_imagePath == null) return;
    final vm = context.read<RecipeViewModel>();
    await vm.generateRecipeFromImage(_imagePath!);
  }

  Future<void> _saveRecipe() async {
    final vm = context.read<RecipeViewModel>();
    if (vm.generatedRecipe == null) return;

    final title = vm.generatedRecipe!
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => 'Ask Genie Recipe');

    await vm.saveGeneratedRecipe(title.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Recipe saved!'),
          backgroundColor: AppColors.of(context).surfaceAlt,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyRecipe() {
    final vm = context.read<RecipeViewModel>();
    if (vm.generatedRecipe == null) return;

    // Copy to clipboard
    Clipboard.setData(ClipboardData(text: vm.generatedRecipe!));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Recipe copied!'),
        backgroundColor: AppColors.of(context).surfaceAlt,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _whatCanIMake() async {
    final pantryVm = context.read<PantryViewModel>();
    await pantryVm.loadPantry();
    final items = pantryVm.items;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Your pantry is empty. Add items first!'),
          backgroundColor: AppColors.of(context).surfaceAlt,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final ingredientList = items.map((i) => i.name).join(', ');
    final vm = context.read<RecipeViewModel>();
    final profile = await LocalDbService.instance.getProfile();

    await vm.generateRecipeFromIngredients(
      ingredients: ingredientList,
      preference: _dietPref == 'None' ? null : _dietPref,
      healthy: _makeItHealthy,
      profile: profile,
    );
  }



  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final vm = context.watch<RecipeViewModel>();

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        title: const Text('Ask Genie'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTabSelector(colors),
                  const SizedBox(height: 16),
                  if (_selectedTab == 0) _buildIngredientsTab(colors),
                  if (_selectedTab == 1) _buildPhotoTab(colors),
                  if (vm.isGenerating) _buildLoadingShimmer(colors),
                  if (vm.generatedRecipe != null && !vm.isGenerating)
                    _buildRecipeResult(colors, vm),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildTabSelector(AppColorSet colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? AppColors.brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 18,
                      color: _selectedTab == 0 ? colors.textOnBrand : colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ingredients',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: _selectedTab == 0 ? colors.textOnBrand : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? AppColors.brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_rounded,
                      size: 18,
                      color: _selectedTab == 1 ? colors.textOnBrand : colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Photo',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: _selectedTab == 1 ? colors.textOnBrand : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsTab(AppColorSet colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ingredientsController,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Enter ingredients, comma-separated...',
            hintStyle: TextStyle(color: colors.textTertiary),
            filled: true,
            fillColor: colors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _dietPref,
          decoration: InputDecoration(
            labelText: 'Dietary Preference',
            filled: true,
            fillColor: colors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          dropdownColor: colors.surfaceAlt,
          items: _dietOptions
              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _dietPref = v);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Switch(
              value: _makeItHealthy,
              onChanged: (v) => setState(() => _makeItHealthy = v),
              activeColor: AppColors.brand,
              activeTrackColor: AppColors.brand.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            Text(
              'Make it Healthy',
              style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _generateFromIngredients,
            icon: const Icon(Icons.auto_awesome, size: 20),
            label: const Text('Generate Recipe'),
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
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _whatCanIMake,
            icon: const Icon(Icons.kitchen_rounded, size: 20),
            label: const Text('What Can I Make?'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brand,
              side: BorderSide(color: AppColors.brand.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoTab(AppColorSet colors) {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
              image: _imagePath != null
                  ? DecorationImage(
                      image: FileImage(File(_imagePath!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _imagePath == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_outlined, size: 48, color: colors.textTertiary),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to pick an image',
                        style: AppTextStyles.bodyMedium.copyWith(color: colors.textTertiary),
                      ),
                    ],
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _captureImage,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Camera'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_imagePath != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _generateFromImage,
              icon: const Icon(Icons.search_rounded, size: 20),
              label: const Text('Analyze & Generate Recipe'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: colors.textOnBrand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingShimmer(AppColorSet colors) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 160, height: 20,
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < 4; i++) ...[
            Container(
              width: double.infinity, height: 14,
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Genie is cooking...',
                style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeResult(AppColorSet colors, RecipeViewModel vm) {
    final recipe = vm.generatedRecipe!;

    return Container(
      margin: const EdgeInsets.only(top: 24),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.brand, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Generated Recipe',
                    style: AppTextStyles.heading3.copyWith(color: AppColors.brand, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Consumer<ModelManager>(
                  builder: (_, mm, __) => HybridAiBadge(
                    isOnDevice: mm.isLatestOnDevice,
                    isOffline: mm.isLatestOffline,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _copyRecipe,
                  child: Tooltip(
                    message: 'Copy Recipe',
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.copy_rounded, color: colors.textSecondary, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _saveRecipe,
                  child: Tooltip(
                    message: 'Save Recipe',
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.bookmark_outline, color: colors.textSecondary, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkdownBody(
                  data: recipe,
                  styleSheet: MarkdownStyleSheet(
                    p: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary, height: 1.5),
                    h1: AppTextStyles.heading1.copyWith(color: AppColors.brand),
                    h2: AppTextStyles.heading2.copyWith(color: AppColors.brand),
                    h3: AppTextStyles.heading3.copyWith(color: AppColors.brand),
                    listBullet: AppTextStyles.bodyMedium.copyWith(color: AppColors.brand),
                    strong: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
