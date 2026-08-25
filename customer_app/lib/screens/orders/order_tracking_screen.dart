import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../providers/chat_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../chat/chat_screen.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  static const _steps = [
    OrderStatus.pending,
    OrderStatus.accepted,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    final order = context.watch<OrderProvider>().byId(orderId);
    if (order == null) {
      return const Scaffold(body: Center(child: Text('Order not found')));
    }
    final vendor = context.watch<VendorProvider>().vendorById(order.vendorId);

    final relevantSteps = order.fulfillmentType == FulfillmentType.pickup
        ? _steps.where((s) => s != OrderStatus.outForDelivery).toList()
        : _steps;
    final currentIndex = relevantSteps.indexOf(order.status).clamp(0, relevantSteps.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(order.orderNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: vendor == null
                ? null
                : () {
                    final thread = context.read<ChatProvider>().getOrCreateThread(vendor, orderId: order.id);
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => ChatScreen(threadId: thread.id)));
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
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: AppColors.danger),
                    SizedBox(width: 10),
                    Expanded(child: Text('This order was cancelled.')),
                  ],
                ),
              ),
            )
          else ...[
            // Map placeholder — swap for a GoogleMap widget showing vendor
            // location + live rider marker once google_maps_flutter is wired
            // to the /ws/orders/{id}/track WebSocket.
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: const Text(
                            'Vendor is on the way',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
                Text(order.vendorName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < relevantSteps.length; i++)
              _StepRow(
                label: relevantSteps[i].label,
                isDone: i <= currentIndex,
                isLast: i == relevantSteps.length - 1,
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
                  Text(
                    order.fulfillmentType == FulfillmentType.pickup
                        ? 'Pickup at ${order.deliveryAddress}'
                        : 'Deliver to ${order.deliveryAddress}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  Text('Payment: ${order.paymentMethod.label}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ),
          if (order.isActive) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _confirmCancel(context),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Cancel Order'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
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
    if (confirmed != true) return;
    if (!context.mounted) return;
    context.read<OrderProvider>().cancelOrder(orderId, 'Cancelled by customer');
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
