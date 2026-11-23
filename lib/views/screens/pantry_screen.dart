import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/pantry_view_model.dart';
import '../../viewmodels/recipe_view_model.dart';
import '../../models/pantry_item.dart';
import '../../models/shopping_item.dart';
import 'ask_genie_screen.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  final _shoppingItemController = TextEditingController();
  String? _selectedCategory;
  DateTime? _selectedDate;
  String _selectedUnit = 'unit';

  final _categories = [
    'Produce', 'Dairy', 'Meat', 'Seafood', 'Grains', 'Canned',
    'Spices', 'Condiments', 'Frozen', 'Beverages', 'Snacks', 'Other'
  ];
  final _units = ['unit', 'g', 'kg', 'ml', 'L', 'tsp', 'tbsp', 'cup', 'oz', 'lb', 'piece', 'pack'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PantryViewModel>().loadPantry();
      context.read<PantryViewModel>().loadShoppingList();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    _shoppingItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        title: const Text('Pantry'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Scan Receipt with Hybrid AI',
            icon: const Icon(Icons.document_scanner_outlined, color: AppColors.brand),
            onPressed: _showScanReceiptSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.brand,
          labelColor: AppColors.brand,
          unselectedLabelColor: colors.textSecondary,
          indicatorSize: TabBarIndicatorSize.label,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
          unselectedLabelStyle: const TextStyle(fontSize: 13, fontFamily: 'Inter'),
          tabs: const [
            Tab(text: 'All Items'),
            Tab(text: 'Expiring Soon'),
            Tab(text: 'Shopping List'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllItemsTab(colors),
          _buildExpiringTab(colors),
          _buildShoppingListTab(colors),
        ],
      ),
      floatingActionButton: _tabController.index == 0 || _tabController.index == 1
          ? Padding(
              padding: const EdgeInsets.only(bottom: 90.0),
              child: FloatingActionButton(
                onPressed: _showAddItemSheet,
                backgroundColor: AppColors.brand,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildAllItemsTab(AppColorSet colors) {
    return Consumer<PantryViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.brand));
        }
        final grouped = _groupByCategory(vm.items);
        if (grouped.isEmpty) {
          return _emptyState(colors, 'Your pantry is empty.\nTap + to add items.', Icons.kitchen_outlined);
        }
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: grouped.entries.map((entry) {
                  return _categoryGroup(colors, entry.key, entry.value, vm);
                }).toList(),
              ),
            ),
            _buildWhatCanIMake(colors),
          ],
        );
      },
    );
  }

  Map<String, List<PantryItem>> _groupByCategory(List<PantryItem> items) {
    final map = <String, List<PantryItem>>{};
    for (final item in items) {
      final cat = item.category ?? 'Other';
      map.putIfAbsent(cat, () => []).add(item);
    }
    return map;
  }

  Widget _categoryGroup(AppColorSet colors, String category, List<PantryItem> items, PantryViewModel vm) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              category.toUpperCase(),
              style: AppTextStyles.labelMedium.copyWith(color: colors.textTertiary, letterSpacing: 1),
            ),
          ),
          ...items.map((item) => _pantryItemTile(colors, item, vm)),
        ],
      ),
    );
  }

  Widget _pantryItemTile(AppColorSet colors, PantryItem item, PantryViewModel vm) {
    Color expiryColor;
    if (item.isExpired) {
      expiryColor = AppColors.error;
    } else if (item.isExpiringSoon) {
      expiryColor = AppColors.warning;
    } else {
      expiryColor = AppColors.success;
    }

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => vm.deleteItem(item.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit}',
                    style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            if (item.expiryDate != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: expiryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.isExpired
                      ? 'Expired'
                      : DateFormat('MMM d').format(item.expiryDate!),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: expiryColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatCanIMake(AppColorSet colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: () {
            final names = context.read<PantryViewModel>().items.map((i) => i.name).join(', ');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AskGenieScreen()),
            );
            context.read<RecipeViewModel>().generateRecipeFromIngredients(ingredients: names);
          },
          icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          label: const Text('What Can I Make?', style: AppTextStyles.buttonMedium),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: colors.textOnBrand,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildExpiringTab(AppColorSet colors) {
    return Consumer<PantryViewModel>(
      builder: (context, vm, _) {
        final expiring = vm.items.where((i) => i.isExpiringSoon || i.isExpired).toList()
          ..sort((a, b) {
            if (a.isExpired && !b.isExpired) return -1;
            if (!a.isExpired && b.isExpired) return 1;
            if (a.expiryDate == null) return 1;
            if (b.expiryDate == null) return -1;
            return a.expiryDate!.compareTo(b.expiryDate!);
          });

        if (expiring.isEmpty) {
          return _emptyState(colors, 'No items expiring soon!', Icons.check_circle_outline);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: expiring.map((item) {
            final isExpired = item.isExpired;
            final badgeColor = isExpired ? AppColors.error : AppColors.warning;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: badgeColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isExpired ? Icons.error_outline : Icons.warning_amber_outlined,
                    color: badgeColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                        Text(
                          '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit}',
                          style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isExpired
                          ? 'EXPIRED'
                          : item.expiryDate != null
                              ? '${item.expiryDate!.difference(DateTime.now()).inDays + 1}d left'
                              : '',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildShoppingListTab(AppColorSet colors) {
    return Consumer<PantryViewModel>(
      builder: (context, vm, _) {
        final unchecked = vm.shoppingList.where((i) => !i.isChecked).toList();
        final checked = vm.shoppingList.where((i) => i.isChecked).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _shoppingItemController,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Add item...',
                        filled: true,
                        fillColor: colors.card,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.border, width: 0.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
                        ),
                      ),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          vm.addIngredientToShoppingList(value.trim());
                          _shoppingItemController.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final text = _shoppingItemController.text.trim();
                      if (text.isNotEmpty) {
                        vm.addIngredientToShoppingList(text);
                        _shoppingItemController.clear();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: AppColors.brandGradient),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            if (checked.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Spacer(),
                    GestureDetector(
                      onTap: vm.clearCheckedItems,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Clear Checked', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: vm.shoppingList.isEmpty
                  ? _emptyState(colors, 'Shopping list is empty.\nAdd items above.', Icons.shopping_cart_outlined)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      children: [
                        if (unchecked.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 6),
                            child: Text('TO BUY', style: AppTextStyles.labelMedium.copyWith(color: colors.textTertiary, letterSpacing: 1)),
                          ),
                          ...unchecked.map((i) => _shoppingItemTile(colors, i, vm)),
                        ],
                        if (checked.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 6),
                            child: Text('CHECKED', style: AppTextStyles.labelMedium.copyWith(color: colors.textTertiary, letterSpacing: 1)),
                          ),
                          ...checked.map((i) => _shoppingItemTile(colors, i, vm)),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _shoppingItemTile(AppColorSet colors, ShoppingItem item, PantryViewModel vm) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => vm.deleteShoppingItem(item.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => vm.toggleShoppingItem(item.id),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: item.isChecked ? AppColors.brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: item.isChecked ? AppColors.brand : colors.borderLight,
                  ),
                ),
                child: item.isChecked
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: item.isChecked ? colors.textTertiary : colors.textPrimary,
                  decoration: item.isChecked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Text(
              '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit}',
              style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showScanReceiptSheet() async {
    final colors = AppColors.of(context);
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long, color: AppColors.brand, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scan Supermarket Receipt', style: AppTextStyles.heading3.copyWith(color: colors.textPrimary)),
                        Text('Auto-pantry import via Gemini 3.5 Flash', style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.brand,
                  child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                ),
                title: Text('Take Photo of Receipt', style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary)),
                subtitle: Text('Capture receipt using device camera', style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: colors.surfaceAlt,
                  child: const Icon(Icons.photo_library, color: AppColors.brand, size: 20),
                ),
                title: Text('Upload Receipt from Gallery', style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary)),
                subtitle: Text('Select receipt image from files', style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await picker.pickImage(source: source);
      if (picked == null) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const CircularProgressIndicator(color: AppColors.brand),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Scanning Receipt...', style: AppTextStyles.labelLarge.copyWith(color: colors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Firebase AI Logic Multimodal Analysis', style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final bytes = await picked.readAsBytes();
      final vm = context.read<PantryViewModel>();
      final items = await vm.scanAndAddReceipt(bytes);

      if (mounted) {
        Navigator.pop(context); // Dismiss progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Added ${items.length} items to your pantry! (${vm.lastScanBadge ?? "Hybrid AI"})',
                  ),
                ),
              ],
            ),
            backgroundColor: colors.surfaceAlt,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to scan receipt: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showAddItemSheet() {
    final colors = AppColors.of(context);
    _nameController.clear();
    _quantityController.text = '1';
    _unitController.clear();
    _priceController.clear();
    _notesController.clear();
    _selectedCategory = null;
    _selectedDate = null;
    _selectedUnit = 'unit';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: SingleChildScrollView(
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
                  Text('Add Pantry Item', style: AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: _sheetInputDecoration(colors, 'Item Name', Icons.shopping_basket),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: colors.textPrimary),
                          decoration: _sheetInputDecoration(colors, 'Qty', Icons.numbers),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedUnit,
                          decoration: _sheetInputDecoration(colors, 'Unit', Icons.straighten),
                          dropdownColor: colors.surfaceAlt,
                          style: TextStyle(color: colors.textPrimary),
                          items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          onChanged: (v) {
                            if (v != null) setSheetState(() => _selectedUnit = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: _sheetInputDecoration(colors, 'Category', Icons.category),
                    dropdownColor: colors.surfaceAlt,
                    style: TextStyle(color: colors.textPrimary),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setSheetState(() => _selectedCategory = v ?? 'Other'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: colors.textPrimary),
                          decoration: _sheetInputDecoration(colors, 'Price (\$)', Icons.attach_money),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: ctx,
                              initialDate: DateTime.now().add(const Duration(days: 7)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            );
                            if (date != null) {
                              setSheetState(() => _selectedDate = date);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.border),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: colors.textTertiary, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedDate != null
                                      ? DateFormat('MMM d, yyyy').format(_selectedDate!)
                                      : 'Expiry',
                                  style: TextStyle(color: _selectedDate != null ? colors.textPrimary : colors.textTertiary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: _sheetInputDecoration(colors, 'Notes (optional)', Icons.notes),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = _nameController.text.trim();
                        if (name.isEmpty) return;
                        final qty = double.tryParse(_quantityController.text) ?? 1;
                        context.read<PantryViewModel>().addItem(
                          name: name,
                          quantity: qty,
                          unit: _selectedUnit,
                          expiryDate: _selectedDate,
                          price: double.tryParse(_priceController.text),
                          category: _selectedCategory,
                          notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
                        );
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: colors.textOnBrand,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Add Item', style: AppTextStyles.buttonMedium),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _sheetInputDecoration(AppColorSet colors, String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.brand, size: 18),
      filled: true,
      fillColor: colors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.border, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
    );
  }

  Widget _emptyState(AppColorSet colors, String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, size: 32, color: colors.textTertiary),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
