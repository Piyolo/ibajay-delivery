import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/status_badge.dart';
import '../settings/store_status_screen.dart';
import 'order_detail_screen.dart';

class OrdersDashboardScreen extends StatefulWidget {
  const OrdersDashboardScreen({super.key});

  @override
  State<OrdersDashboardScreen> createState() => _OrdersDashboardScreenState();
}

class _OrdersDashboardScreenState extends State<OrdersDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // True while a pull-to-refresh is running, so the full-screen first-load
  // spinner doesn't replace the lists (and kill the refresh indicator)
  // when the inbox is empty and the user pulls to refresh.
  bool _refreshing = false;

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

  Future<void> _refreshOrders() async {
    setState(() => _refreshing = true);
    try {
      await context.read<OrderProvider>().load();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendor = context.watch<VendorProvider>().vendor;
    final orders = context.watch<OrderProvider>();
    final loading = orders.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              // Same behavior as the Dashboard: tapping the status pill
              // opens the Store Status options screen instead of instantly
              // flipping open/closed.
              child: StoreStatusPill(
                status: vendor.status,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StoreStatusScreen()),
                ),
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
      body: loading && orders.all.isEmpty && !_refreshing
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _OrderList(
                  orders: orders.newOrders,
                  emptyLabel: 'No new orders right now.',
                  onRefresh: _refreshOrders,
                ),
                _OrderList(
                  orders: orders.preparingOrders,
                  emptyLabel: 'Nothing being prepared.',
                  onRefresh: _refreshOrders,
                ),
                _OrderList(
                  orders: orders.outForDelivery,
                  emptyLabel: 'No deliveries in progress.',
                  onRefresh: _refreshOrders,
                ),
                _OrderList(
                  orders: orders.history,
                  emptyLabel: 'No completed orders yet.',
                  onRefresh: _refreshOrders,
                ),
              ],
            ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<VendorOrder> orders;
  final String emptyLabel;
  final Future<void> Function() onRefresh;
  const _OrderList({required this.orders, required this.emptyLabel, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: orders.isEmpty
          ? ListView(
              children: [
                EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Nothing here yet',
                  subtitle: emptyLabel,
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _OrderCard(order: orders[i]),
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final VendorOrder order;
  const _OrderCard({required this.order});

  /// Accept taps report the outcome — the provider swallows API errors
  /// into [OrderProvider.lastError], so the snack is the only way a failed
  /// accept ever reaches the vendor.
  Future<void> _acceptOrder(BuildContext context) async {
    final provider = context.read<OrderProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await provider.acceptOrder(order.id);
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Order accepted'
          : 'Could not accept order — ${provider.lastError ?? 'try again'}'),
    ));
  }

  /// One-tap reject is replaced by a reason dialog (the reason is sent to
  /// the backend via the cancel endpoint); the result gets a snack either
  /// way.
  Future<void> _rejectOrder(BuildContext context) async {
    final provider = context.read<OrderProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectReasonDialog(),
    );
    if (reason == null) return; // dialog dismissed without rejecting
    final ok = await provider.rejectOrder(order.id, reason: reason);
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Order rejected'
          : 'Could not reject order — ${provider.lastError ?? 'try again'}'),
    ));
  }

  Future<void> _advanceStatus(BuildContext context) async {
    final provider = context.read<OrderProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final next = order.status.nextFor(order.fulfillmentType);
    // Pickup collection reads "Picked Up", matching the product's pickup
    // flow (… → Ready for Pickup → Picked Up).
    final label = (order.fulfillmentType == FulfillmentType.pickup &&
            next == OrderStatus.completed)
        ? 'Picked Up'
        : (next?.label ?? 'next status');
    final ok = await provider.advanceStatus(order.id);
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Order marked as $label'
          : 'Could not update order — ${provider.lastError ?? 'try again'}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.read<OrderProvider>();
    final busy = orderProvider.isBusy(order.id);
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
                  Expanded(
                    child: Text(
                      order.orderNumber.isNotEmpty ? order.orderNumber : order.id,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                        onPressed: busy ? null : () => _rejectOrder(context),
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
                        onPressed: busy ? null : () => _acceptOrder(context),
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
                Builder(builder: (context) {
                  final next = order.status.nextFor(order.fulfillmentType);
                  // Pickup collection reads "Picked Up", matching the
                  // product's pickup flow (… → Ready for Pickup → Picked Up).
                  final label = next == null
                      ? ''
                      : (order.fulfillmentType == FulfillmentType.pickup &&
                              next == OrderStatus.completed)
                          ? 'Picked Up'
                          : next.label;
                  return SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: busy ? null : () => _advanceStatus(context),
                      child: Text('Mark as $label'),
                    ),
                  );
                }),
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

/// Confirmation dialog shown before rejecting an order: asks for a reason
/// (quick chips + optional custom text) so the customer gets a meaningful
/// cancellation message. Pops with the chosen reason, or null on cancel.
class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog();

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  static const _reasons = [
    'Out of stock',
    'Too busy right now',
    'Closing soon',
    'No rider available',
  ];

  late final TextEditingController _custom;
  String? _selected = _reasons.first;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _custom = TextEditingController();
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  /// A typed reason overrides the chip; the prefilled first chip keeps the
  /// reason non-empty so the backend always receives one.
  String get _reason {
    final custom = _custom.text.trim();
    return custom.isNotEmpty ? custom : (_selected ?? '');
  }

  void _submit() {
    if (_submitting) return;
    setState(() => _submitting = true);
    Navigator.of(context).pop(_reason);
  }

  @override
  Widget build(BuildContext context) {
    final customText = _custom.text.trim();
    return AlertDialog(
      title: const Text('Why are you rejecting this order?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final reason in _reasons)
                  ChoiceChip(
                    label: Text(reason),
                    selected: _selected == reason && customText.isEmpty,
                    onSelected: (_) => setState(() {
                      _selected = reason;
                      _custom.clear();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _custom,
              decoration: const InputDecoration(labelText: 'Or type a reason'),
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Reject Order'),
        ),
      ],
    );
  }
}
