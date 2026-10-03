import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/food_item.dart';
import '../../providers/menu_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'food_form_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _categoryFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<MenuProvider>();
    final categories = menu.categoriesInUse.toList()..sort();

    var items = menu.items;
    if (_categoryFilter != null) {
      items = items.where((i) => i.category == _categoryFilter).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      items = items.where((i) => i.name.toLowerCase().contains(q) || i.description.toLowerCase().contains(q)).toList();
    }

    final groupedCategories = (_categoryFilter != null ? [_categoryFilter!] : categories);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Food Item',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FoodFormScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search your menu…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() {
                          _query = '';
                          _searchController.clear();
                        }),
                      ),
              ),
            ),
          ),
          if (categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  children: [
                    _categoryChip('All', selected: _categoryFilter == null, onTap: () => setState(() => _categoryFilter = null)),
                    const SizedBox(width: 8),
                    for (final c in categories) ...[
                      _categoryChip(c, selected: _categoryFilter == c, onTap: () => setState(() => _categoryFilter = c)),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
          Expanded(
            child: menu.items.isEmpty
                ? const EmptyState(
                    icon: Icons.restaurant_menu_outlined,
                    title: 'No menu items yet',
                    subtitle: 'Tap + to add your first food item.',
                  )
                : items.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: 'No matches',
                        subtitle: 'Try a different search term or category.',
                      )
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          for (final category in groupedCategories) ...[
                            if (items.any((i) => i.category == category)) ...[
                              SectionHeader(title: category),
                              ...items.where((i) => i.category == category).map((item) => _FoodTile(item: item)),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, {required bool selected, required VoidCallback onTap}) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  final FoodItem item;
  const _FoodTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final menu = context.read<MenuProvider>();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FoodFormScreen(existingItem: item)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.fastfood_outlined, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('₱${item.price.toStringAsFixed(0)}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: item.isAvailable,
                activeThumbColor: AppColors.success,
                onChanged: (v) => menu.toggleAvailability(item.id, v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}