import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/status_badge.dart';
import 'order_tracking_screen.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [Tab(text: 'Active'), Tab(text: 'History')],
          ),
        ),
        body: TabBarView(
          children: [_ActiveOrdersTab(), _PastOrdersTab()],
        ),
      ),
    );
  }
}

class _ActiveOrdersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>().activeOrders;
    if (orders.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No active orders',
        subtitle: 'Your ongoing orders will show up here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _OrderCard(order: orders[i], showReorder: false),
    );
  }
}

class _PastOrdersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>().pastOrders;
    if (orders.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'No past orders yet',
        subtitle: 'Completed and cancelled orders will show up here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _OrderCard(order: orders[i], showReorder: true),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final CustomerOrder order;
  final bool showReorder;
  const _OrderCard({required this.order, required this.showReorder});

  void _reorder(BuildContext context) {
    final vendor = context.read<VendorProvider>().vendorById(order.vendorId);
    if (vendor == null) return;
    final cartProvider = context.read<CartProvider>();
    cartProvider.clear();
    for (final line in order.items) {
      final food = vendor.menu.firstWhere(
        (f) => f.name == line.foodName,
        orElse: () => vendor.menu.first,
      );
      cartProvider.addItem(foodItem: food, vendor: vendor, quantity: line.quantity);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${order.items.length} item(s) added to your cart from ${vendor.storeName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: order.id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(order.vendorName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(order.orderNumber, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Text(
                order.items.map((i) => '${i.quantity}x ${i.foodName}').join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('₱${order.grandTotal.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (showReorder)
                    OutlinedButton(
                      onPressed: () => _reorder(context),
                      child: const Text('Reorder'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
