import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/recipe.dart';
import '../../models/chat_message.dart';
import '../../viewmodels/recipe_view_model.dart';
import '../../viewmodels/pantry_view_model.dart';
import '../../viewmodels/meal_plan_view_model.dart';
import '../../models/meal_plan.dart';
import 'voice_cooking_screen.dart';
import '../../widgets/cooking_timer_widget.dart';
class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late Recipe _originalRecipe;
  late Recipe _recipe;
  int _servings = 2;
  final int _baseServings = 2;
  String? _activeTransform;
  bool _isTransforming = false;
  final List<ChatMessage> _chatMessages = [];
  final _chatController = TextEditingController();
  bool _isAiResponding = false;
  bool _isSavingAsRecipe = false;

  @override
  void initState() {
    super.initState();
    _originalRecipe = widget.recipe;
    _recipe = widget.recipe;
    _chatMessages.add(ChatMessage.ai(content: "Hi! I'm ChowGenie. Ask me anything about this recipe! I can help you substitute ingredients, simplify steps, or adapt it to your dietary needs. Once we're done, you can save our conversation as a new recipe."));
  }

  String _scaleIngredient(String ingredient, double ratio) {
    if (ratio == 1.0) return ingredient;

    return ingredient.replaceAllMapped(
      RegExp(r'\b(\d+\/\d+|\d+(?:\.\d+)?)\b'),
      (match) {
        final valStr = match.group(0)!;
        double? val;
        if (valStr.contains('/')) {
          final parts = valStr.split('/');
          final num = double.tryParse(parts[0]);
          final den = double.tryParse(parts[1]);
          if (num != null && den != null && den != 0) {
            val = num / den;
          }
        } else {
          val = double.tryParse(valStr);
        }

        if (val == null) return valStr;
        final scaled = val * ratio;
        if (scaled == scaled.roundToDouble()) {
          return scaled.toInt().toString();
        } else {
          return scaled.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
        }
      },
    );
  }

  Future<void> _applyTransform(String type) async {
    if (_isTransforming) return;
    setState(() => _isTransforming = true);

    final vm = context.read<RecipeViewModel>();
    final transformed = await vm.transformRecipe(
      recipe: _originalRecipe,
      transformType: type,
    );

    if (mounted) {
      setState(() {
        _isTransforming = false;
        if (transformed != null) {
          _recipe = transformed;
          _activeTransform = type;
        }
      });

      if (transformed != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.brand, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Recipe transformed to "$type" via Gemini Nano!')),
              ],
            ),
            backgroundColor: AppColors.of(context).surfaceAlt,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _revertTransform() {
    setState(() {
      _recipe = _originalRecipe;
      _activeTransform = null;
    });
  }

  int? _extractStepDurationMinutes(String step) {
    final match = RegExp(r'(\d+)\s*(?:mins?|minutes?|secs?|seconds?|hours?)', caseSensitive: false).firstMatch(step);
    if (match != null) {
      final numStr = match.group(1);
      final numVal = int.tryParse(numStr ?? '');
      if (numVal != null) {
        final lower = step.toLowerCase();
        if (lower.contains('hour') || lower.contains('hr')) {
          return numVal * 60;
        }
        return numVal;
      }
    }
    return null;
  }

  Future<void> _toggleFavorite() async {
    await context.read<RecipeViewModel>().toggleFavorite(_recipe.id);
    setState(() {
      _recipe = _recipe.copyWith(isFavorite: !_recipe.isFavorite);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(_recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _recipe.isFavorite ? AppColors.error : colors.textOnBrand, size: 18),
              const SizedBox(width: 8),
              Text(_recipe.isFavorite ? 'Added to Favorites' : 'Removed from Favorites'),
            ],
          ),
          backgroundColor: AppColors.of(context).surfaceAlt,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _shareRecipe() async {
    final qrData = context.read<RecipeViewModel>().exportService.generateQrData(_recipe);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.of(context).surface,
        title: Text('Share Recipe Data', style: AppTextStyles.heading3.copyWith(color: AppColors.of(context).textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Copy this payload or scan the QR Code to import on another device:', 
                 style: AppTextStyles.bodyMedium.copyWith(color: AppColors.of(context).textSecondary)),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFFFF6D00),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.of(context).surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                qrData,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.of(context).textPrimary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: AppColors.of(context).textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: qrData));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard!')),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Copy', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  void _addToMealPlan() async {
    final entry = MealPlanEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      recipeId: _recipe.id,
      recipeTitle: _recipe.title,
      mealType: MealType.dinner,
      date: DateTime.now(),
      estimatedCalories: _recipe.calories,
    );
    await context.read<MealPlanViewModel>().addEntry(entry);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.calendar_month, color: AppColors.brand, size: 18),
              SizedBox(width: 8),
              Text('Recipe added to today\'s dinner plan!'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _addToShoppingList() {
    final vm = context.read<PantryViewModel>();
    for (final ingredient in _recipe.ingredients) {
      vm.addIngredientToShoppingList(ingredient);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.shopping_cart, color: AppColors.brand, size: 18),
            const SizedBox(width: 8),
            Text('${_recipe.ingredients.length} items added to shopping list'),
          ],
        ),
        backgroundColor: AppColors.of(context).surfaceAlt,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _sendChatMessage() async {
    final query = _chatController.text.trim();
    if (query.isEmpty || _isAiResponding) return;

    _chatController.clear();
    setState(() {
      _chatMessages.add(ChatMessage.user(content: query));
      _isAiResponding = true;
    });

    final vm = context.read<RecipeViewModel>();
    final response = await vm.askAiAboutRecipe(
      recipe: _recipe,
      question: query,
      chatHistory: _chatMessages.sublist(0, _chatMessages.length - 1),
    );

    if (mounted) {
      setState(() {
        _chatMessages.add(ChatMessage.ai(content: response));
        _isAiResponding = false;
      });
    }
  }

  Future<void> _saveConversationAsRecipe() async {
    setState(() => _isSavingAsRecipe = true);
    
    final vm = context.read<RecipeViewModel>();
    final savedRecipe = await vm.saveConversationAsRecipe(
      originalRecipe: _recipe,
      chatHistory: _chatMessages.where((m) => m.type != MessageType.system).toList(),
    );

    if (mounted) {
      setState(() => _isSavingAsRecipe = false);
      if (savedRecipe != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recipe saved as "${savedRecipe.title}"!'),
            backgroundColor: AppColors.of(context).surfaceAlt,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save conversation as recipe. Please try again.'),
            backgroundColor: AppColors.of(context).surfaceAlt,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  AppColorSet get colors => AppColors.of(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.scaffold,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsRow(),
                  const SizedBox(height: 20),
                  _buildTransformChips(),
                  const SizedBox(height: 28),
                  _buildIngredientsHeader(),
                  const SizedBox(height: 12),
                  _buildIngredientsList(),
                  const SizedBox(height: 28),
                  _buildSectionTitle('Directions'),
                  const SizedBox(height: 12),
                  _buildDirectionsList(),
                  const SizedBox(height: 28),
                  _buildActionButtons(),
                  const SizedBox(height: 24),
                  _buildAskAiSection(colors),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Container(
          height: 280,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.genieGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Icon(Icons.restaurant, size: 80, color: colors.textOnBrand.withValues(alpha: 0.5)),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Positioned(
          top: 50,
          left: 16,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            ),
          ),
        ),
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _recipe.title,
                style: AppTextStyles.displaySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_recipe.source != null) ...[
                    Text(_recipe.source!, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                    const SizedBox(width: 12),
                  ],
                  if (_recipe.dietaryTags != null && _recipe.dietaryTags!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _recipe.dietaryTags!.first,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(Icons.local_fire_department, '${_recipe.calories?.toStringAsFixed(0) ?? '--'} kcal', 'Calories'),
          _statItem(Icons.schedule, _recipe.cookingTimeMinutes != null ? '${_recipe.cookingTimeMinutes} min' : '--', 'Time'),
          _statItem(Icons.whatshot, _recipe.spiceLevel != null ? '${_recipe.spiceLevel}/5' : '--', 'Spice'),
          _statItem(Icons.emoji_events_outlined, _recipe.difficulty ?? '--', 'Difficulty'),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.brand, size: 20),
        const SizedBox(height: 6),
        Text(value, style: AppTextStyles.labelLarge.copyWith(color: colors.textPrimary)),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: AppTextStyles.heading2.copyWith(color: colors.textPrimary));
  }

  Widget _buildIngredientsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionTitle('Ingredients'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _servings > 1 ? () => setState(() => _servings--) : null,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _servings > 1 ? colors.card : colors.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.remove, size: 14, color: _servings > 1 ? colors.textPrimary : colors.textTertiary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$_servings servings',
                  style: AppTextStyles.labelMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
                ),
              ),
              GestureDetector(
                onTap: _servings < 16 ? () => setState(() => _servings++) : null,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.card,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add, size: 14, color: colors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransformChips() {
    final transforms = [
      {'label': '🌱 Vegan', 'type': 'Vegan'},
      {'label': '🥩 High-Protein', 'type': 'High-Protein'},
      {'label': '🌾 Gluten-Free', 'type': 'Gluten-Free'},
      {'label': '💰 Budget Swap', 'type': 'Budget Swap'},
      {'label': '⚡ Quick 15m', 'type': 'Quick 15-Minute'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.brand, size: 18),
                const SizedBox(width: 6),
                Text('One-Tap Transforms', style: AppTextStyles.labelLarge.copyWith(color: colors.textPrimary)),
              ],
            ),
            if (_activeTransform != null)
              GestureDetector(
                onTap: _revertTransform,
                child: const Text('Revert to Original', style: TextStyle(color: AppColors.brand, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isTransforming)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand)),
                const SizedBox(width: 12),
                Text('Gemini Nano transforming recipe on-device...', style: AppTextStyles.bodySmall.copyWith(color: AppColors.brand)),
              ],
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: transforms.map((t) {
                final isSelected = _activeTransform == t['type'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(t['label']!),
                    selected: isSelected,
                    onSelected: (_) => _applyTransform(t['type']!),
                    selectedColor: AppColors.brand.withValues(alpha: 0.25),
                    backgroundColor: colors.surfaceAlt,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.brand : colors.textPrimary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppColors.brand : colors.border,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildIngredientsList() {
    final scaleRatio = _servings / _baseServings;
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_recipe.ingredients.length, (index) {
            final rawIngredient = _recipe.ingredients[index];
            final ingredient = _scaleIngredient(rawIngredient, scaleRatio);
            return Padding(
              padding: EdgeInsets.only(bottom: index == _recipe.ingredients.length - 1 ? 0 : 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.brand, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: MarkdownBody(
                      data: ingredient,
                      styleSheet: MarkdownStyleSheet(
                        p: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, height: 1.4),
                        strong: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold, height: 1.4),
                        pPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDirectionsList() {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: List.generate(_recipe.directions.length, (index) {
          final step = _recipe.directions[index];
          final stepMinutes = _extractStepDurationMinutes(step);
          return Column(
            children: [
              if (index > 0) Divider(height: 1, color: colors.border),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: AppColors.brandGradient),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: colors.textOnBrand,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MarkdownBody(
                            data: step,
                            styleSheet: MarkdownStyleSheet(
                              p: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, height: 1.5),
                              strong: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold, height: 1.5),
                              pPadding: EdgeInsets.zero,
                            ),
                          ),
                          if (stepMinutes != null) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () {
                                CookingTimerBottomSheet.show(
                                  context,
                                  initialMinutes: stepMinutes,
                                  label: 'Step ${index + 1} Timer',
                                );
                              },
                              icon: const Icon(Icons.timer_outlined, size: 15, color: AppColors.brand),
                              label: Text(
                                'Start ${stepMinutes}m Timer',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brand),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.brand),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  void _deleteRecipe() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Delete Recipe', style: AppTextStyles.heading3.copyWith(color: colors.textPrimary)),
        content: Text('Are you sure you want to delete this recipe?', style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: colors.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<RecipeViewModel>().deleteRecipe(_recipe.id);
              Navigator.pop(context); // Go back to recipe list
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recipe deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _actionIcon(Icons.mic, 'Cook', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VoiceCookingScreen(
                  steps: _recipe.directions,
                  recipeTitle: _recipe.title,
                  ingredients: _recipe.ingredients,
                ),
              ),
            );
          }),
          _actionIcon(Icons.timer_outlined, 'Timer', () => CookingTimerBottomSheet.show(context, initialMinutes: _recipe.cookingTimeMinutes ?? 15, label: '${_recipe.title} Timer')),
          _actionIcon(Icons.favorite_outlined, 'Favorite', _toggleFavorite),
          _actionIcon(Icons.calendar_month, 'Plan', _addToMealPlan),
          _actionIcon(Icons.shopping_cart, 'Cart', _addToShoppingList),
          _actionIcon(Icons.share, 'Share', _shareRecipe),
          if (_recipe.isUserGenerated)
            _actionIcon(Icons.delete_outline, 'Delete', _deleteRecipe, color: AppColors.error),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color ?? AppColors.brand, size: 22),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildAskAiSection(AppColorSet colors) {
    return Container(
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
              const Icon(Icons.auto_awesome, color: AppColors.brand, size: 20),
              const SizedBox(width: 8),
              Text(
                'Ask Genie about this Recipe',
                style: AppTextStyles.heading3.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _chatMessages.length,
            itemBuilder: (context, index) {
              final msg = _chatMessages[index];
              final isUser = msg.type == MessageType.user;
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.brand
                        : colors.surfaceAlt,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                      bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    msg.content,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isUser ? colors.textOnBrand : colors.textPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
          if (_isAiResponding) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Genie is thinking...',
                  style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: 'Ask about substitution, simplifications...',
                    hintStyle: TextStyle(color: colors.textTertiary),
                    filled: true,
                    fillColor: colors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  style: TextStyle(color: colors.textPrimary),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendChatMessage(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendChatMessage,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.send, color: colors.textOnBrand, size: 18),
                ),
              ),
            ],
          ),
          if (_chatMessages.where((m) => m.type == MessageType.user).isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _isSavingAsRecipe ? null : _saveConversationAsRecipe,
                icon: _isSavingAsRecipe
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_as, size: 18),
                label: const Text('Save Conversation as Recipe'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: colors.textOnBrand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
