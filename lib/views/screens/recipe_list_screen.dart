import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/recipe_view_model.dart';
import '../../models/recipe.dart';
import 'recipe_detail_screen.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _filters = ['All', 'My Recipes', 'Favorites', 'Quick (<30min)', 'Vegetarian'];
  final _letters = List.generate(26, (i) => String.fromCharCode(65 + i));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecipeViewModel>().loadRecipes(refresh: true);
    });
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<RecipeViewModel>().loadRecipes();
    }
  }

  void _onSearchChanged() {
    context.read<RecipeViewModel>().setFilters(query: _searchController.text.trim());
  }

  Future<void> _onRefresh() async {
    await context.read<RecipeViewModel>().loadRecipes(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        title: const Text('Recipes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(colors),
          const SizedBox(height: 12),
          _buildFilterChips(colors),
          const SizedBox(height: 12),
          _buildLetterStrip(colors),
          const SizedBox(height: 12),
          Expanded(
            child: Consumer<RecipeViewModel>(
              builder: (context, vm, _) {
                if (vm.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.brand),
                  );
                }
                final recipes = vm.recipes;
                if (recipes.isEmpty && !vm.isLoading) {
                  return _emptyState(colors, vm.searchQuery.isNotEmpty);
                }
                return RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: AppColors.brand,
                  child: Column(
                    children: [
                      Expanded(
                        child: GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: recipes.length,
                          itemBuilder: (context, index) => _buildRecipeCard(recipes[index], colors),
                        ),
                      ),
                      if (vm.isLoadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: CircularProgressIndicator(color: AppColors.brand),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppColorSet colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: colors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search recipes...',
          prefixIcon: Icon(Icons.search, color: colors.textTertiary, size: 22),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: colors.textTertiary, size: 18),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          filled: true,
          fillColor: colors.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.border, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(AppColorSet colors) {
    final vm = context.watch<RecipeViewModel>();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final selected = vm.selectedFilter == filter;
          return GestureDetector(
            onTap: () => context.read<RecipeViewModel>().setFilters(filter: filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.brand : colors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.brand : colors.border,
                ),
              ),
              child: Text(
                filter,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected ? colors.textOnBrand : colors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLetterStrip(AppColorSet colors) {
    final vm = context.watch<RecipeViewModel>();
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _letters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 2),
        itemBuilder: (context, index) {
          final letter = _letters[index];
          final selected = vm.selectedLetter == letter;
          return GestureDetector(
            onTap: () {
              context.read<RecipeViewModel>().setFilters(letter: selected ? null : letter, clearLetter: selected);
            },
            child: Container(
              width: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.brand : colors.card,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                letter,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected ? Colors.white : colors.textSecondary,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe, AppColorSet colors) {
    final ingredientCount = recipe.ingredients.length;
    final cookingTime = recipe.cookingTimeMinutes;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailScreen(recipe: recipe),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.genieGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Center(
                      child: Icon(Icons.restaurant, size: 40, color: colors.textOnBrand.withValues(alpha: 0.6)),
                    ),
                  ),
                  if (cookingTime != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '$cookingTime min',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => context.read<RecipeViewModel>().toggleFavorite(recipe.id),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: recipe.isFavorite ? AppColors.error : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.shopping_basket_outlined, size: 12, color: colors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        '$ingredientCount ingredients',
                        style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(AppColorSet colors, bool hasQuery) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                hasQuery ? Icons.search_off : Icons.menu_book_outlined,
                size: 32,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasQuery ? 'No recipes found' : 'No recipes yet',
              style: AppTextStyles.heading3.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different search term or filter.'
                  : 'Your recipe collection is empty.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
