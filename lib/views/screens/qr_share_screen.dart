import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/recipe_view_model.dart';
import '../../models/recipe.dart';
import '../../services/recipe_export_service.dart';

class QrShareScreen extends StatefulWidget {
  final Recipe? initialRecipe;
  const QrShareScreen({super.key, this.initialRecipe});

  @override
  State<QrShareScreen> createState() => _QrShareScreenState();
}

class _QrShareScreenState extends State<QrShareScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Recipe? _selectedRecipe;
  String? _generatedQrData;
  String _scanResult = '';
  bool _isScanning = false;
  bool _importSuccess = false;
  final _exportService = RecipeExportService();
  final _pasteController = TextEditingController();

  final _filters = ['All', 'My Recipes', 'Favorites', 'Quick (<30min)', 'Vegetarian'];
  final _letters = List.generate(26, (i) => String.fromCharCode(65 + i));

  Widget _buildFilterChips(AppColorSet colors) {
    final vm = context.watch<RecipeViewModel>();
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final selected = vm.selectedFilter == filter;
          return GestureDetector(
            onTap: () => context.read<RecipeViewModel>().setFilters(filter: filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.brand : colors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? AppColors.brand : colors.border,
                ),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: selected ? colors.textOnBrand : colors.textSecondary,
                    fontSize: 12,
                  ),
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
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _letters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
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
                border: Border.all(color: selected ? AppColors.brand : colors.border),
              ),
              child: Text(
                letter,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected ? Colors.white : colors.textSecondary,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialRecipe != null) {
      _selectedRecipe = widget.initialRecipe;
      _generatedQrData = _exportService.generateQrData(widget.initialRecipe!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecipeViewModel>().loadRecipes();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pasteController.dispose();
    super.dispose();
  }

  void _generateQr(Recipe recipe) {
    final qrData = _exportService.generateQrData(recipe);
    setState(() {
      _selectedRecipe = recipe;
      _generatedQrData = qrData;
    });
  }

  Future<void> _importRecipe(String data) async {
    try {
      final recipe = _exportService.parseQrData(data);
      if (recipe != null) {
        final rvm = context.read<RecipeViewModel>();
        await rvm.saveImportedRecipe(recipe);
        setState(() {
          _scanResult = 'Successfully imported: ${recipe.title}';
          _importSuccess = true;
        });
      } else {
        setState(() {
          _scanResult = 'Invalid QR data format';
          _importSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _scanResult = 'Error: $e';
        _importSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.scaffold,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8),
            decoration: BoxDecoration(
              color: colors.card,
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Text('QR Share', style: AppTextStyles.heading2),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.brand,
                  labelColor: AppColors.brand,
                  unselectedLabelColor: colors.textTertiary,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: const [
                    Tab(text: 'Export', icon: Icon(Icons.qr_code)),
                    Tab(text: 'Import', icon: Icon(Icons.qr_code_scanner)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildExportTab(context, colors),
                _buildImportTab(context, colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportTab(BuildContext context, AppColorSet colors) {
    return Consumer<RecipeViewModel>(
      builder: (context, rvm, _) {
        final recipes = rvm.recipes;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select a Recipe', style: AppTextStyles.heading3.copyWith(color: colors.textPrimary)),
              const SizedBox(height: 8),
              TextField(
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
                onChanged: (q) => rvm.search(q),
              ),
              const SizedBox(height: 12),
              _buildFilterChips(colors),
              const SizedBox(height: 10),
              _buildLetterStrip(colors),
              const SizedBox(height: 16),
              if (recipes.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: recipes.length,
                    itemBuilder: (context, index) {
                      final recipe = recipes[index];
                      final isSelected = _selectedRecipe?.id == recipe.id;
                      return GestureDetector(
                        onTap: () => _generateQr(recipe),
                        child: Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.brand.withValues(alpha: 0.1) : colors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppColors.brand : colors.border,
                              width: isSelected ? 1.5 : 0.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.brand.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.restaurant, color: AppColors.brand, size: 16),
                                  ),
                                  const Spacer(),
                                  if (isSelected)
                                    const Icon(Icons.check_circle, color: AppColors.brand, size: 16),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                recipe.title,
                                style: AppTextStyles.bodySmall.copyWith(color: colors.textPrimary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${recipe.calories?.toStringAsFixed(0) ?? "?"} cal',
                                style: AppTextStyles.labelSmall.copyWith(color: colors.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.restaurant, color: colors.textTertiary, size: 32),
                      const SizedBox(height: 8),
                      Text('No recipes found', style: AppTextStyles.bodyMedium.copyWith(color: colors.textTertiary)),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              if (_generatedQrData != null && _selectedRecipe != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      Text('Your QR Code', style: AppTextStyles.heading3.copyWith(color: colors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(
                        _selectedRecipe!.title,
                        style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: QrImageView(
                          data: _generatedQrData!,
                          version: QrVersions.auto,
                          size: 220,
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
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final bytes = _generateQrImageBytes();
                                if (bytes != null) {
                                  Clipboard.setData(ClipboardData(text: _generatedQrData!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(Icons.check, color: Colors.white, size: 18),
                                          SizedBox(width: 8),
                                          Text('QR data copied to clipboard'),
                                        ],
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('Copy Data'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.textPrimary,
                                side: BorderSide(color: colors.border),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _exportService.shareRecipe(_selectedRecipe!),
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('Share'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _exportService.shareRecipeAsFile(_selectedRecipe!),
                          icon: const Icon(Icons.save_alt, size: 18),
                          label: const Text('Save as Image'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildImportTab(BuildContext context, AppColorSet colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Scan QR Code', style: AppTextStyles.heading3.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 12),
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: _isScanning
                  ? MobileScanner(
                      onDetect: (capture) {
                        final barcode = capture.barcodes.firstOrNull;
                        if (barcode != null && barcode.rawValue != null) {
                          setState(() => _isScanning = false);
                          _importRecipe(barcode.rawValue!);
                        }
                      },
                    )
                  : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner, color: colors.textTertiary, size: 64),
                        const SizedBox(height: 16),
                        Text('Tap to start scanning', style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _isScanning = true),
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text('Open Camera'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
          if (_scanResult.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _importSuccess
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _importSuccess
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _importSuccess ? Icons.check_circle : Icons.error_outline,
                    color: _importSuccess ? AppColors.success : AppColors.error,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _scanResult,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: _importSuccess ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: colors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR', style: AppTextStyles.labelLarge.copyWith(color: colors.textTertiary)),
              ),
              Expanded(child: Divider(color: colors.border)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Paste JSON Data', style: AppTextStyles.heading3.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _pasteController,
            maxLines: 5,
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Paste recipe JSON here...',
              hintStyle: TextStyle(color: colors.textTertiary),
              filled: true,
              fillColor: colors.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_pasteController.text.trim().isNotEmpty) {
                  _importRecipe(_pasteController.text.trim());
                }
              },
              icon: const Icon(Icons.import_export, size: 18),
              label: const Text('Import Recipe'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Uint8List? _generateQrImageBytes() {
    return null;
  }
}
