import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final cart = cartProvider.cart;

    return Scaffold(
      appBar: AppBar(
        title: Text(cart.vendorName ?? 'Your Cart'),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: cartProvider.clear,
              child: const Text('Clear', style: TextStyle(color: AppColors.danger)),
            ),
        ],
      ),
      body: cart.isEmpty
          ? const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              subtitle: 'Add items from a vendor to get started.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: cart.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final item = cart.items[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.foodItem.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              if (item.selectedOptions.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    item.selectedOptions
                                        .expand((o) => o.choices.map((c) => c.label))
                                        .join(', '),
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                ),
                              if (item.specialInstructions.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('"${item.specialInstructions}"',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
                                ),
                              const SizedBox(height: 8),
                              Text('₱${item.lineTotal.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                              onPressed: () => context.read<CartProvider>().removeItem(item.id),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => context.read<CartProvider>().updateQuantity(item.id, -1),
                                ),
                                Text('${item.quantity}'),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => context.read<CartProvider>().updateQuantity(item.id, 1),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal', style: TextStyle(color: AppColors.textSecondary)),
                        Text('₱${cart.subtotal.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                        child: const Text('Proceed to Checkout'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
