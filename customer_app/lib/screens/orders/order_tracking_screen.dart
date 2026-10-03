import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../providers/chat_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../chat/chat_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  // Captured for dispose(), where inherited lookups are no longer allowed.
  late final OrderProvider _orders = context.read<OrderProvider>();

  bool? _alreadyReviewed;

  @override
  void initState() {
    super.initState();
    // Deep-opened or freshly restored session: fetch from the API if the
    // order isn't already in memory. Live tracking starts only once the
    // fetched/known status is actually out_for_delivery.
    final existing = _orders.byId(widget.orderId);
    if (existing == null) {
      _orders.refreshOrder(widget.orderId).then((fresh) {
        if (fresh?.status == OrderStatus.outForDelivery) {
          _orders.watchOrder(widget.orderId);
        }
      });
    } else {
      _orders.watchOrder(widget.orderId);
    }
    _checkReviewed();
  }

  Future<void> _checkReviewed() async {
    try {
      final reviewed = await _orders.hasReview(widget.orderId);
      if (mounted) setState(() => _alreadyReviewed = reviewed);
    } catch (_) {
      // Unknown state — assume unreviewed; the backend rejects duplicates.
      if (mounted) setState(() => _alreadyReviewed = false);
    }
  }

  @override
  void dispose() {
    _orders.stopWatching();
    super.dispose();
  }

  Future<void> _cancelOrder(CustomerOrder order) async {
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
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<OrderProvider>().cancelOrder(order.id, 'Cancelled by customer');
      messenger.showSnackBar(const SnackBar(content: Text('Your order was cancelled')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not cancel the order — please try again')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final order = orderProvider.byId(widget.orderId);
    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: orderProvider.lastError != null
              ? Text(orderProvider.lastError!)
              : const CircularProgressIndicator(),
        ),
      );
    }
    final vendor = context.watch<VendorProvider>().vendorById(order.vendorId);

    // Pickup skips the rider flow entirely and uses its own labels
    // (Ready for Pickup → Picked Up); cancelled/completed map to the end of
    // the flow instead of resetting the stepper to step 0.
    final isPickup = order.fulfillmentType == FulfillmentType.pickup;
    final allSteps = [
      OrderStatus.pending,
      OrderStatus.accepted,
      OrderStatus.preparing,
      OrderStatus.ready,
      if (!isPickup) OrderStatus.outForDelivery,
      OrderStatus.delivered,
    ];
    String stepLabel(OrderStatus s) {
      if (isPickup && s == OrderStatus.ready) return 'Ready for Pickup';
      if (isPickup && s == OrderStatus.delivered) return 'Picked Up';
      return s.label;
    }

    final currentIndex = order.status == OrderStatus.cancelled
        ? -1
        : switch (order.status) {
            OrderStatus.completed => allSteps.length - 1,
            _ => allSteps.indexOf(order.status),
          };

    return Scaffold(
      appBar: AppBar(
        title: Text(order.orderNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: vendor == null
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final thread = await context
                          .read<ChatProvider>()
                          .getOrCreateThread(vendor, orderId: order.id);
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ChatScreen(threadId: thread.id)));
                    } catch (_) {
                      messenger.showSnackBar(const SnackBar(
                          content: Text('Could not open the chat — try again')));
                    }
                  },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (order.status == OrderStatus.cancelled)
            Card(
              color: AppColors.danger.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.cancel, color: AppColors.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(order.cancellationReason.isEmpty
                          ? 'This order was cancelled.'
                          : 'This order was cancelled — ${order.cancellationReason}'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Container(
                height: 180,
                color: AppColors.surfaceMuted,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.map_outlined, size: 48, color: AppColors.textSecondary),
                    if (order.status == OrderStatus.outForDelivery)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: orderProvider.trackingError != null
                              ? () => orderProvider.watchOrder(order.id)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: orderProvider.trackingError != null
                                  ? AppColors.warning
                                  : AppColors.primary,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              orderProvider.trackingError ??
                                  (orderProvider.riderLat != null
                                      ? 'Live location · ${orderProvider.riderLat!.toStringAsFixed(4)}, ${orderProvider.riderLng!.toStringAsFixed(4)}'
                                      : 'Your order is on the way'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(order.vendorName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < allSteps.length; i++)
              _StepRow(
                label: stepLabel(allSteps[i]),
                isDone: i <= currentIndex,
                isLast: i == allSteps.length - 1,
              ),
            const SizedBox(height: 20),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Order Details', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ...order.items.map((i) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Text('${i.quantity}x ', style: const TextStyle(color: AppColors.textSecondary)),
                            Expanded(child: Text(i.foodName)),
                            Text('₱${i.subtotal.toStringAsFixed(0)}'),
                          ],
                        ),
                      )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text('₱${order.grandTotal.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (order.scheduledFor != null)
                    Text(
                      'Scheduled for ${order.scheduledFor!.toLocal()}'.split('.').first,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  Text(
                    order.fulfillmentType == FulfillmentType.pickup
                        ? 'Pickup at ${vendor?.address ?? order.deliveryAddress}'
                        : 'Deliver to ${order.deliveryAddress}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  Text('Payment: ${order.paymentMethod.label}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ),
          if (order.isActive && order.status != OrderStatus.outForDelivery) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _cancelOrder(order),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Cancel Order'),
            ),
          ],
          // Rate the order once it's done — one review per completed order.
          if ((order.status == OrderStatus.delivered ||
                  order.status == OrderStatus.completed) &&
              _alreadyReviewed == false)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: () => _leaveReview(order),
                icon: const Icon(Icons.star_rounded),
                label: const Text('Rate this order'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _leaveReview(CustomerOrder order) async {
    int stars = 5;
    final commentController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Rate ${order.vendorName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 1; i <= 5; i++)
                    IconButton(
                      icon: Icon(
                        i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: AppColors.warning,
                        size: 34,
                      ),
                      onPressed: () => setDialogState(() => stars = i),
                    ),
                ],
              ),
              TextField(
                controller: commentController,
                maxLines: 3,
                maxLength: 500,
                decoration:
                    const InputDecoration(hintText: 'Share your experience (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit Review'),
            ),
          ],
        ),
      ),
    );
    commentController.dispose();
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _orders.submitReview(order.id, stars: stars, comment: commentController.text);
      if (!mounted) return;
      setState(() => _alreadyReviewed = true);
      messenger.showSnackBar(const SnackBar(content: Text('Thanks for your review!')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not submit your review — try again')));
    }
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isLast;
  const _StepRow({required this.label, required this.isDone, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = isDone ? AppColors.success : AppColors.border;
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: isDone ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: color)),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isDone ? FontWeight.w700 : FontWeight.w400,
                color: isDone ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
