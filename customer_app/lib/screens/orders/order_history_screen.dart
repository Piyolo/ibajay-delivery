import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../models/vendor.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/status_badge.dart';
import 'order_tracking_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // History lives on the backend — pull the latest every time the
    // screen opens (also covers orders placed on another device).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OrderProvider>().loadOrders();
    });
  }

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
        body: const TabBarView(
          children: [_ActiveOrdersTab(), _PastOrdersTab()],
        ),
      ),
    );
  }
}

class _ActiveOrdersTab extends StatelessWidget {
  const _ActiveOrdersTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final orders = provider.activeOrders;
    if (provider.isLoading && orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (orders.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: provider.lastError != null ? 'Could not load your orders' : 'No active orders',
        subtitle: provider.lastError ?? 'Your ongoing orders will show up here.',
        action: OutlinedButton(
          onPressed: () => context.read<OrderProvider>().loadOrders(),
          child: const Text('Retry'),
        ),
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
  const _PastOrdersTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final orders = provider.pastOrders;
    if (provider.isLoading && orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (orders.isEmpty) {
      return EmptyState(
        icon: Icons.history,
        title: provider.lastError != null ? 'Could not load your orders' : 'No past orders yet',
        subtitle: provider.lastError ?? 'Completed and cancelled orders will show up here.',
        action: OutlinedButton(onPressed: () => context.read<OrderProvider>().loadOrders(), child: const Text('Retry')),
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
    if (vendor == null || vendor.menu.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This store's menu is unavailable right now")),
      );
      return;
    }
    final cartProvider = context.read<CartProvider>();
    cartProvider.clear();
    var added = 0;
    for (final line in order.items) {
      // Match by exact name and skip unknown items instead of silently
      // adding a wrong substitute.
      FoodItemRef? food;
      for (final f in vendor.menu) {
        if (f.name == line.foodName) {
          food = f;
          break;
        }
      }
      if (food == null || !food.isAvailable) continue;
      cartProvider.addItem(foodItem: food, vendor: vendor, quantity: line.quantity);
      added++;
    }
    if (added == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('None of these items are available anymore')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$added item(s) added to your cart from ${vendor.storeName}')),
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
