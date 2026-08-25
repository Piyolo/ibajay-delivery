import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../chat/chat_screen.dart';
import 'delivery_tracking_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  static const _flow = [
    OrderStatus.pending,
    OrderStatus.accepted,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final order = orderProvider.findById(orderId);

    if (order == null) {
      return const Scaffold(body: Center(child: Text('Order not found')));
    }

    final currentIndex = _flow.indexOf(order.status);

    return Scaffold(
      appBar: AppBar(
        title: Text(order.id),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(customerName: order.customerName, orderId: order.id),
              ),
            ),
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
              _StatusStepper(currentIndex: currentIndex, flow: _flow),
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
            if (order.status == OrderStatus.ready)
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
            else if (order.status.next != null)
              ElevatedButton(
                onPressed: () => orderProvider.advanceStatus(order.id),
                child: Text('Mark as ${order.status.next!.label}'),
              ),
          ],
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