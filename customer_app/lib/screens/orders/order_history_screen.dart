import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../models/vendor.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/status_badge.dart';
import 'order_tracking_screen.dart';
import 'review_dialog.dart';

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

  Future<void> _refresh(BuildContext context) =>
      context.read<OrderProvider>().loadOrders();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final orders = provider.activeOrders;
    if (provider.isLoading && orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (orders.isEmpty) {
      // Scrollable wrapper so pull-to-refresh works on the empty state
      // too — status changes shouldn't need an app restart to appear.
      return RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EmptyState(
              icon: Icons.receipt_long_outlined,
              title: provider.lastError != null ? 'Could not load your orders' : 'No active orders',
              subtitle: provider.lastError ?? 'Your ongoing orders will show up here.',
              action: OutlinedButton(
                onPressed: () => context.read<OrderProvider>().loadOrders(),
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _OrderCard(order: orders[i], showReorder: false),
      ),
    );
  }
}

class _PastOrdersTab extends StatelessWidget {
  const _PastOrdersTab();

  Future<void> _refresh(BuildContext context) =>
      context.read<OrderProvider>().loadOrders();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final orders = provider.pastOrders;
    if (provider.isLoading && orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EmptyState(
              icon: Icons.history,
              title: provider.lastError != null ? 'Could not load your orders' : 'No past orders yet',
              subtitle: provider.lastError ?? 'Completed and cancelled orders will show up here.',
              action: OutlinedButton(
                  onPressed: () => context.read<OrderProvider>().loadOrders(),
                  child: const Text('Retry')),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _OrderCard(order: orders[i], showReorder: true),
      ),
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

  /// Cancel flow mirroring order_tracking_screen: confirm prompt, then
  /// the backend call with a reason (a query param server-side). The
  /// server refuses anything past "accepted" with a policy message that
  /// is surfaced verbatim.
  Future<void> _cancelOrder(BuildContext context) async {
    final orders = context.read<OrderProvider>();
    // Double-tap protection: an in-flight cancel ignores further taps and
    // the button disables via isCancelling().
    if (orders.isCancelling(order.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text(
          'The store will be notified and your order will no longer be prepared. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Order'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await orders.cancelOrder(order.id, 'Cancelled by customer');
      messenger.showSnackBar(const SnackBar(content: Text('Your order was cancelled')));
      // The provider flips the status locally; pull the list too so the
      // card reflects any server-side side effects (e.g. moved tabs).
      if (context.mounted) await orders.loadOrders();
    } on ApiException catch (e) {
      // Policy refusals ("already being prepared...") pass through as-is.
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not cancel the order — please try again')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();
    // Business-rule visibility matches the backend and the tracking
    // screen: customers may cancel only while the order is undecided or
    // freshly accepted.
    final canCancel = order.status == OrderStatus.pending ||
        order.status == OrderStatus.accepted;
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
              if (canCancel)
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: orders.isCancelling(order.id)
                        ? null
                        : () => _cancelOrder(context),
                    style:
                        OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    child: Text(orders.isCancelling(order.id)
                        ? 'Cancelling…'
                        : 'Cancel Order'),
                  ),
                ),
              // Delivered/completed orders can be rated — the dialog
              // shows the stored review when one already exists.
              if (showReorder &&
                  (order.status == OrderStatus.delivered ||
                      order.status == OrderStatus.completed))
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => showOrderReviewDialog(
                      context,
                      orderId: order.id,
                      vendorName: order.vendorName,
                    ),
                    icon: const Icon(Icons.star_rounded, size: 16),
                    label: const Text('Rate order',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
