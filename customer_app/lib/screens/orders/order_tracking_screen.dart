import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../models/review.dart';
import '../../models/vendor.dart';
import '../../providers/chat_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/tracking_map.dart';
import '../chat/chat_screen.dart';
import 'review_dialog.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with WidgetsBindingObserver {
  // Captured for dispose(), where inherited lookups are no longer allowed.
  late final OrderProvider _orders = context.read<OrderProvider>();

  Timer? _refreshTimer;
  OrderReview? _myReview;
  bool? _alreadyReviewed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    _loadReview();

    // Status updates only arrived over the tracking WebSocket before —
    // which covers nothing while the socket is down. Poll so accepted /
    // preparing / out-for-delivery transitions appear without the
    // customer having to reopen the app.
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Polling keeps burning data while the app sits in the background —
    // pause it on pause/hidden, resume (with an immediate refresh) on
    // returning to the foreground.
    switch (state) {
      case AppLifecycleState.resumed:
        _startPolling(immediate: true);
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _refreshTimer?.cancel();
        _refreshTimer = null;
      default:
        break;
    }
  }

  /// True once the order has reached a state that can never change again —
  /// there is nothing left to poll for (pull-to-refresh still works).
  bool _isTerminal(CustomerOrder? order) =>
      order == null ||
      order.status == OrderStatus.delivered ||
      order.status == OrderStatus.completed ||
      order.status == OrderStatus.cancelled;

  void _startPolling({bool immediate = false}) {
    _refreshTimer?.cancel();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 12), (_) => _autoRefresh());
    if (immediate) _autoRefresh();
  }

  /// Periodic pull: refresh this order, and (re)start live tracking the
  /// moment it becomes out_for_delivery — including transitions that
  /// happened while the socket wasn't connected. Stops itself once the
  /// order is terminal (delivered/completed/cancelled).
  Future<void> _autoRefresh() async {
    if (!mounted) return;
    if (_isTerminal(_orders.byId(widget.orderId))) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      return;
    }
    final fresh = await _orders.refreshOrder(widget.orderId);
    if (!mounted || fresh == null) return;
    if (fresh.status == OrderStatus.outForDelivery &&
        _orders.watchedOrderId != widget.orderId) {
      _orders.watchOrder(widget.orderId);
    }
    if (_isTerminal(fresh)) {
      // One last UI cycle picks up the final state; no further polls.
      _refreshTimer?.cancel();
      _refreshTimer = null;
      if (fresh.status == OrderStatus.delivered ||
          fresh.status == OrderStatus.completed) {
        await _loadReview();
      }
      return;
    }
    if (fresh.status == OrderStatus.delivered ||
        fresh.status == OrderStatus.completed) {
      await _loadReview();
    }
  }

  /// Pull-to-refresh: same as the timer, but immediate.
  Future<void> _manualRefresh() async {
    await _orders.refreshOrder(widget.orderId);
    if (!mounted) return;
    final order = _orders.byId(widget.orderId);
    if (order?.status == OrderStatus.outForDelivery &&
        _orders.watchedOrderId != widget.orderId) {
      _orders.watchOrder(widget.orderId);
    }
  }

  Future<void> _loadReview() async {
    try {
      final review = await _orders.getReview(widget.orderId);
      if (mounted) {
        setState(() {
          _myReview = review;
          _alreadyReviewed = review != null;
        });
      }
    } catch (_) {
      // Unknown state — assume unreviewed; the backend rejects duplicates.
      if (mounted) setState(() => _alreadyReviewed = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _orders.stopWatching();
    super.dispose();
  }

  Future<void> _cancelOrder(CustomerOrder order) async {
    // Double-tap protection: an in-flight cancel ignores further taps and
    // the button disables below via isCancelling().
    if (_orders.isCancelling(order.id)) return;
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

  /// Opens the shared rate-and-review dialog, then reloads the stored
  /// review so the screen shows it right after submitting.
  Future<void> _rateOrder(CustomerOrder order) async {
    await showOrderReviewDialog(
      context,
      orderId: order.id,
      vendorName: order.vendorName,
    );
    if (mounted) await _loadReview();
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

    // The socket only attaches while the order is out_for_delivery, so a
    // status flip that happened while this screen was open (poll, another
    // device, a missed WebSocket push) must start it from here too.
    if (order.status == OrderStatus.outForDelivery &&
        orderProvider.watchedOrderId != widget.orderId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _orders.watchOrder(widget.orderId);
      });
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
      // Status can change at any moment — pull-to-refresh mirrors the
      // 12-second poll so the customer can force an update on demand.
      body: RefreshIndicator(
        onRefresh: _manualRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
              _trackingArea(order, orderProvider, vendor),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('${i.quantity}x ',
                                      style: const TextStyle(color: AppColors.textSecondary)),
                                  Expanded(child: Text(i.foodName)),
                                  Text('₱${i.subtotal.toStringAsFixed(0)}'),
                                ],
                              ),
                              // Selected add-ons, so the line/total visibly
                              // include their price contribution.
                              ...i.optionLabels.map(
                                (label) => Padding(
                                  padding: const EdgeInsets.only(left: 24, top: 2),
                                  child: Text('• $label',
                                      style: const TextStyle(
                                          fontSize: 12, color: AppColors.textSecondary)),
                                ),
                              ),
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
            // Business-rule visibility matches the backend: customers may
            // cancel only while the order is undecided or freshly accepted
            // — once the kitchen starts preparing it, cancellation is
            // restricted to the store.
            if (order.status == OrderStatus.pending ||
                order.status == OrderStatus.accepted) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _orders.isCancelling(order.id)
                    ? null
                    : () => _cancelOrder(order),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(_orders.isCancelling(order.id)
                    ? 'Cancelling…'
                    : 'Cancel Order'),
              ),
            ],
            // Rate the order once it's done — one review per completed
            // order. After submitting (or when it was already reviewed)
            // the stored review is shown here.
            if (order.status == OrderStatus.delivered ||
                order.status == OrderStatus.completed) ...[
              if (_alreadyReviewed == true && _myReview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _ReviewCard(review: _myReview!),
                )
              else if (_alreadyReviewed == false)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ElevatedButton.icon(
                    onPressed: () => _rateOrder(order),
                    icon: const Icon(Icons.star_rounded),
                    label: const Text('Rate this order'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// What sits at the top of the tracking screen:
  ///  - out_for_delivery (delivery orders): ALWAYS a real map — the
  ///    destination pin when its coordinates are known, the rider marker
  ///    once GPS pings arrive, and a "waiting for the rider's location"
  ///    pill before the first ping. Never a blank/missing map.
  ///  - other active statuses (pending → ready): a clear status panel,
  ///    since there is nothing live to map yet.
  ///  - delivered/completed: a quiet destination-pin map when coords exist.
  Widget _trackingArea(
      CustomerOrder order, OrderProvider provider, VendorProfile? vendor) {
    final hasDestination =
        order.destinationLat != null && order.destinationLng != null;
    final destination =
        hasDestination ? LatLng(order.destinationLat!, order.destinationLng!) : null;
    final isLive = order.status == OrderStatus.outForDelivery &&
        order.fulfillmentType != FulfillmentType.pickup;

    if (!isLive && destination == null) {
      return _StatusPanel(order: order);
    }

    final rider = provider.riderLat != null && provider.riderLng != null
        ? LatLng(provider.riderLat!, provider.riderLng!)
        : null;
    // Destination coords can be missing (address without pinned
    // coordinates) — center on the store instead so the map still renders
    // meaningful tiles rather than an empty frame.
    final fallbackCenter = (vendor != null &&
            (vendor.latitude != 0 || vendor.longitude != 0))
        ? LatLng(vendor.latitude, vendor.longitude)
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: 200,
        child: Stack(
          children: [
            TrackingMap(
              destination: destination,
              rider: rider,
              fallbackCenter: fallbackCenter,
              height: 200,
            ),
            if (isLive)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: GestureDetector(
                  onTap: provider.trackingError != null
                      ? () => provider.watchOrder(order.id)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: provider.trackingError != null
                          ? AppColors.warning
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      provider.trackingError ??
                          (rider != null
                              ? 'Your rider is on the way — follow them on the map'
                              : 'Waiting for the rider\u2019s first location ping'),
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
    );
  }
}

/// Clear, non-map status view shown while the order is being fulfilled
/// but no rider is on the road yet (and for finished orders without
/// pinned coordinates) — replaces the old grey map-icon placeholder.
class _StatusPanel extends StatelessWidget {
  final CustomerOrder order;
  const _StatusPanel({required this.order});

  IconData get _icon {
    switch (order.status) {
      case OrderStatus.pending:
        return Icons.hourglass_top;
      case OrderStatus.accepted:
        return Icons.check_circle_outline;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.ready:
        return Icons.shopping_bag_outlined;
      case OrderStatus.outForDelivery:
        return Icons.delivery_dining;
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }

  String get _title {
    switch (order.status) {
      case OrderStatus.pending:
        return 'Waiting for the store';
      case OrderStatus.accepted:
        return 'Order accepted';
      case OrderStatus.preparing:
        return 'Preparing your order';
      case OrderStatus.ready:
        return order.fulfillmentType == FulfillmentType.pickup
            ? 'Ready for pickup'
            : 'Ready — waiting for a rider';
      case OrderStatus.outForDelivery:
        return 'On its way';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.completed:
        return 'Order completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get _subtitle {
    switch (order.status) {
      case OrderStatus.pending:
        return 'The store will confirm your order shortly.';
      case OrderStatus.accepted:
        return 'The store accepted your order — preparation starts next.';
      case OrderStatus.preparing:
        return 'The store is cooking your order right now.';
      case OrderStatus.ready:
        return order.fulfillmentType == FulfillmentType.pickup
            ? 'Head to the store when you are ready.'
            : 'Waiting for a rider to pick it up — live tracking starts then.';
      case OrderStatus.outForDelivery:
        return 'Your order is out for delivery.';
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return 'We hope you enjoyed it — rate the store below.';
      case OrderStatus.cancelled:
        return 'This order was cancelled.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Icon(_icon, size: 44, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(_title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            _subtitle,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The customer's stored review, shown after the order is rated.
class _ReviewCard extends StatelessWidget {
  final OrderReview review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your review', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (int i = 1; i <= 5; i++)
                  Icon(
                    i <= review.stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColors.warning,
                    size: 22,
                  ),
              ],
            ),
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(review.comment, style: const TextStyle(fontSize: 13.5)),
            ],
            if (review.vendorResponse != null && review.vendorResponse!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Store reply: ${review.vendorResponse}',
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
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
