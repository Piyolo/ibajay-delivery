import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/status_badge.dart';
import 'order_detail_screen.dart';

class OrdersDashboardScreen extends StatefulWidget {
  const OrdersDashboardScreen({super.key});

  @override
  State<OrdersDashboardScreen> createState() => _OrdersDashboardScreenState();
}

class _OrdersDashboardScreenState extends State<OrdersDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vendor = context.watch<VendorProvider>().vendor;
    final orders = context.watch<OrderProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: AppPillToggle(
                value: vendor.isOpen,
                activeLabel: 'Open',
                inactiveLabel: 'Closed',
                onChanged: (v) => context.read<VendorProvider>().toggleStoreOpen(v),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'New (${orders.newOrders.length})'),
            Tab(text: 'Preparing (${orders.preparingOrders.length})'),
            Tab(text: 'Out for Delivery (${orders.outForDelivery.length})'),
            const Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OrderList(orders: orders.newOrders, emptyLabel: 'No new orders right now.'),
          _OrderList(orders: orders.preparingOrders, emptyLabel: 'Nothing being prepared.'),
          _OrderList(orders: orders.outForDelivery, emptyLabel: 'No deliveries in progress.'),
          _OrderList(orders: orders.history, emptyLabel: 'No completed orders yet.'),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<VendorOrder> orders;
  final String emptyLabel;
  const _OrderList({required this.orders, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: 'Nothing here yet',
        subtitle: emptyLabel,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _OrderCard(order: orders[i]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final VendorOrder order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.read<OrderProvider>();
    final timeFmt = DateFormat('h:mm a');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(order.id, style: const TextStyle(fontWeight: FontWeight.w800)),
                  StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                '${order.items.length} item${order.items.length > 1 ? 's' : ''} · ₱${order.grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(_fulfillmentIcon(order.fulfillmentType), size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(_fulfillmentLabel(order), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const Spacer(),
                  Text(timeFmt.format(order.placedAt), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              if (order.status == OrderStatus.pending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => orderProvider.rejectOrder(order.id),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => orderProvider.acceptOrder(order.id),
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ] else if (order.status != OrderStatus.completed &&
                  order.status != OrderStatus.cancelled &&
                  order.status != OrderStatus.delivered) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () => orderProvider.advanceStatus(order.id),
                    child: Text('Mark as ${order.status.next?.label ?? ''}'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _fulfillmentIcon(FulfillmentType type) {
    switch (type) {
      case FulfillmentType.delivery:
        return Icons.delivery_dining_outlined;
      case FulfillmentType.pickup:
        return Icons.storefront_outlined;
      case FulfillmentType.scheduled:
        return Icons.schedule_outlined;
    }
  }

  String _fulfillmentLabel(VendorOrder order) {
    switch (order.fulfillmentType) {
      case FulfillmentType.delivery:
        return 'Delivery';
      case FulfillmentType.pickup:
        return 'Pickup';
      case FulfillmentType.scheduled:
        return order.scheduledFor != null
            ? 'Scheduled · ${DateFormat('MMM d, h:mm a').format(order.scheduledFor!)}'
            : 'Scheduled';
    }
  }
}
