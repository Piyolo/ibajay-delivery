import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vendor.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = context.read<VendorProvider>().vendor.categories.toSet();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final provider = context.read<VendorProvider>();
    await provider.updateCategories(_selected.toList());
    if (!mounted) return;
    setState(() => _saving = false);
    if (provider.lastError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Not saved — ${provider.lastError}')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categories updated')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Categories'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('What does your store sell? Pick all that apply.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kStoreCategoryOptions.map((c) {
                  final selected = _selected.contains(c);
                  return FilterChip(
                    label: Text(c),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      v ? _selected.add(c) : _selected.remove(c);
                    }),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}