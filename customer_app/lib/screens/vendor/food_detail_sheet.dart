import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cart.dart';
import '../../models/vendor.dart';
import '../../providers/cart_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class FoodDetailSheet extends StatefulWidget {
  final VendorProfile vendor;
  final FoodItemRef food;
  const FoodDetailSheet({super.key, required this.vendor, required this.food});

  @override
  State<FoodDetailSheet> createState() => _FoodDetailSheetState();
}

class _FoodDetailSheetState extends State<FoodDetailSheet> {
  int _quantity = 1;
  final _instructionsController = TextEditingController();
  final Map<String, Set<String>> _selected = {}; // groupName -> selected labels

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  double get _optionsExtra {
    double total = 0;
    for (final group in widget.food.options) {
      final chosen = _selected[group.groupName] ?? {};
      for (final choice in group.choices) {
        if (chosen.contains(choice.label)) total += choice.extraPrice;
      }
    }
    return total;
  }

  double get _lineTotal => (widget.food.price + _optionsExtra) * _quantity;

  void _toggleChoice(FoodOptionGroupRef group, String label) {
    setState(() {
      final set = _selected.putIfAbsent(group.groupName, () => {});
      if (group.allowMultiple) {
        if (set.contains(label)) {
          set.remove(label);
        } else {
          set.add(label);
        }
      } else {
        set
          ..clear()
          ..add(label);
      }
    });
  }

  List<SelectedOption> _buildSelectedOptions() {
    final result = <SelectedOption>[];
    for (final group in widget.food.options) {
      final chosenLabels = _selected[group.groupName] ?? {};
      if (chosenLabels.isEmpty) continue;
      final choices = group.choices.where((c) => chosenLabels.contains(c.label)).toList();
      result.add(SelectedOption(groupName: group.groupName, choices: choices));
    }
    return result;
  }

  void _addToCart() {
    // Enforce required option groups before adding.
    final missing = <String>[];
    for (final group in widget.food.options) {
      if (group.isRequired && (_selected[group.groupName]?.isEmpty ?? true)) {
        missing.add(group.groupName);
      }
    }
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please choose: ${missing.join(", ")}')),
      );
      return;
    }

    final cartProvider = context.read<CartProvider>();
    final conflict = cartProvider.addItem(
      foodItem: widget.food,
      vendor: widget.vendor,
      quantity: _quantity,
      options: _buildSelectedOptions(),
      specialInstructions: _instructionsController.text.trim(),
    );

    if (conflict != null) {
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Start a new cart?'),
          content: Text(
              'Your cart has items from ${cartProvider.cart.vendorName}. Adding from ${widget.vendor.storeName} will clear it.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                cartProvider.forceStartNewCart(
                  foodItem: widget.food,
                  vendor: widget.vendor,
                  quantity: _quantity,
                  options: _buildSelectedOptions(),
                  specialInstructions: _instructionsController.text.trim(),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Start New Cart'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.food.name} added to cart')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    RemoteImage(
                      url: widget.food.imageUrl,
                      height: 160,
                      icon: Icons.fastfood,
                      borderRadius: AppRadius.md,
                    ),
                    const SizedBox(height: 16),
                    Text(widget.food.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    if (widget.food.description.isNotEmpty)
                      Text(widget.food.description, style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text('₱${widget.food.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    for (final group in widget.food.options) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Text(group.groupName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (group.isRequired) ...[
                            const SizedBox(width: 6),
                            const Text('(Required)', style: TextStyle(color: AppColors.danger, fontSize: 11)),
                          ],
                          if (!group.allowMultiple) ...[
                            const SizedBox(width: 6),
                            const Text('(choose one)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...group.choices.map((choice) {
                        final selected = _selected[group.groupName]?.contains(choice.label) ?? false;
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (_) => _toggleChoice(group, choice.label),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(choice.label),
                          secondary: Text(
                            choice.extraPrice > 0 ? '+₱${choice.extraPrice.toStringAsFixed(0)}' : 'Free',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 20),
                    const Text('Special Instructions', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _instructionsController,
                      decoration: const InputDecoration(hintText: 'e.g. No onions'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                            ),
                            Text('$_quantity', style: const TextStyle(fontWeight: FontWeight.w700)),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => setState(() => _quantity++),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _addToCart,
                          child: Text('Add to Cart · ₱${_lineTotal.toStringAsFixed(0)}'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
