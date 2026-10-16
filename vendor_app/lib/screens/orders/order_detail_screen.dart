import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../providers/chat_provider.dart';
import '../../providers/order_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/phone_launcher.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/tracking_map.dart';
import '../chat/chat_screen.dart';
import 'delivery_tracking_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  static List<OrderStatus> _flowFor(FulfillmentType type) => [
        OrderStatus.pending,
        OrderStatus.accepted,
        OrderStatus.preparing,
        OrderStatus.ready,
        if (type != FulfillmentType.pickup) OrderStatus.outForDelivery,
        OrderStatus.delivered,
      ];

  /// Opens the conversation for this order. Threads come from
  /// GET /chats/vendor. The backend keeps ONE thread per (customer, vendor)
  /// and only links it to the FIRST order it was opened from — so matching
  /// by order id alone misses the customer's real thread when they opened
  /// chat from a different order. Match by order id first, then fall back
  /// to this order's customer's thread.
  VendorChatThread? _resolveThread(List<VendorChatThread> threads, VendorOrder order) {
    for (final t in threads) {
      if (t.orderId == order.id) return t;
    }
    for (final t in threads) {
      if (t.customerName.isNotEmpty && t.customerName == order.customerName) return t;
    }
    return null;
  }

  Future<void> _openChat(BuildContext context, VendorOrder order) async {
    final messenger = ScaffoldMessenger.of(context);
    final chat = context.read<ChatProvider>();
    var resolved = _resolveThread(chat.threads, order);
    if (resolved == null) {
      await chat.loadThreads();
      resolved = _resolveThread(chat.threads, order);
    }
    final thread = resolved;
    if (thread == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('No conversation yet — the customer can start one from their order')));
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ChatScreen(threadId: thread.id)));
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final order = orderProvider.findById(orderId);

    if (order == null) {
      return const Scaffold(body: Center(child: Text('Order not found')));
    }

    final flow = _flowFor(order.fulfillmentType);
    final currentIndex = order.status == OrderStatus.cancelled
        ? -1
        : (order.status == OrderStatus.completed
            ? flow.length - 1
            : flow.indexOf(order.status));

    return Scaffold(
      appBar: AppBar(
        title: Text(order.orderNumber.isNotEmpty ? order.orderNumber : 'Order'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            tooltip: 'Call customer',
            onPressed: () => callCustomer(context, order.customerMobile),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Chat with customer',
            onPressed: () => _openChat(context, order),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Status', style: TextStyle(fontWeight: FontWeight.w700)),
                StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 14),
            if (order.status != OrderStatus.cancelled)
              _StatusStepper(currentIndex: currentIndex, flow: flow),
            const SizedBox(height: 24),
            _sectionCard(
              title: 'Customer',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(order.customerMobile, style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(order.deliveryAddress, style: const TextStyle(color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                  // The customer's pinned delivery location (stamped on
                  // the order from their saved address) — shows the vendor
                  // exactly where to deliver, not just a text address.
                  if (order.customerLat != null && order.customerLng != null) ...[
                    const SizedBox(height: 10),
                    TrackingMap(
                      destination: LatLng(order.customerLat!, order.customerLng!),
                      height: 160,
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        Icon(Icons.near_me_outlined, size: 12, color: AppColors.textSecondary),
                        SizedBox(width: 4),
                        Text('Delivery location pinned by the customer',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Delivery',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_fulfillmentIcon(order.fulfillmentType), size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(_fulfillmentLabel(order), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  if (order.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.sticky_note_2_outlined, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order.notes,
                              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Items',
              child: Column(
                children: order.items
                    .map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item.quantity}x', style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.foodName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    if (item.addons.isNotEmpty)
                                      Text('+ ${item.addons.join(', ')}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    if (item.specialInstructions.isNotEmpty)
                                      Text('"${item.specialInstructions}"',
                                          style: const TextStyle(
                                              fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              Text('₱${item.subtotal.toStringAsFixed(0)}'),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Payment',
              child: Column(
                children: [
                  _row('Items Total', '₱${order.itemsTotal.toStringAsFixed(0)}'),
                  _row('Delivery Fee', '₱${order.deliveryFee.toStringAsFixed(0)}'),
                  const Divider(height: 20),
                  _row('Total', '₱${order.grandTotal.toStringAsFixed(0)}', bold: true),
                  const SizedBox(height: 6),
                  _row('Payment Method', order.paymentMethod),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Delivery flows only: pickup orders go straight
            // ready → completed via the generic button below.
            if (order.status == OrderStatus.ready &&
                order.fulfillmentType != FulfillmentType.pickup)
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DeliveryTrackingScreen(orderId: order.id)),
                ),
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Start Delivery'),
              )
            else if (order.status == OrderStatus.outForDelivery)
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DeliveryTrackingScreen(orderId: order.id)),
                ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('View Live Tracking'),
              )
            else if (order.status.nextFor(order.fulfillmentType) != null)
              ElevatedButton(
                onPressed: orderProvider.isBusy(order.id)
                    ? null
                    : () => _advanceStatus(context, orderProvider, order),
                child: Text(
                    'Mark as ${order.status.nextFor(order.fulfillmentType)!.label}'),
              ),
          ],
        ),
      ),
    );
  }

  /// Advances the order and reports the outcome — the provider records
  /// failures in lastError instead of throwing, so the snack is how a
  /// failed transition becomes visible.
  Future<void> _advanceStatus(
      BuildContext context, OrderProvider provider, VendorOrder order) async {
    final messenger = ScaffoldMessenger.of(context);
    final label = order.status.nextFor(order.fulfillmentType)!.label;
    final ok = await provider.advanceStatus(order.id);
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Order marked as $label'
          : 'Could not update order — ${provider.lastError ?? 'try again'}'),
    ));
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
        return 'Customer Pickup';
      case FulfillmentType.scheduled:
        return order.scheduledFor != null
            ? 'Scheduled · ${DateFormat('MMM d, h:mm a').format(order.scheduledFor!)}'
            : 'Scheduled Delivery';
    }
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: bold ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatusStepper extends StatelessWidget {
  final int currentIndex;
  final List<OrderStatus> flow;
  const _StatusStepper({required this.currentIndex, required this.flow});

  @override
  Widget build(BuildContext context) {
    return Row(
      // Top-align every cell: labels wrap to different line counts (e.g.
      // "Out for Delivery" wraps), and the default centered alignment
      // pushed shorter cells' dot/line rows DOWN, leaving a visible step /
      // gap in the progress line between "Ready" and "Out for Delivery".
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(flow.length, (i) {
        final done = i <= currentIndex;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i != 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i <= currentIndex ? AppColors.primary : AppColors.border,
                      ),
                    ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  if (i != flow.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i < currentIndex ? AppColors.primary : AppColors.border,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                flow[i].label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color: done ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: done ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}