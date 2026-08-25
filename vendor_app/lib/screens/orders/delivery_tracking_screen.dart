import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../theme/app_theme.dart';

/// Vendor-side "Start Delivery" flow. Once wired to the backend, this screen
/// should stream the device's GPS position over the FastAPI WebSocket
/// (e.g. `ws://.../ws/orders/{orderId}/track`) at a short interval so the
/// customer app can render live vendor location + ETA on Google Maps.
class DeliveryTrackingScreen extends StatefulWidget {
  final String orderId;
  const DeliveryTrackingScreen({super.key, required this.orderId});

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  bool _tracking = false;

  void _toggleTracking() {
    setState(() => _tracking = !_tracking);
    final orderProvider = context.read<OrderProvider>();
    final order = orderProvider.findById(widget.orderId);
    if (_tracking && order != null && order.status == OrderStatus.ready) {
      orderProvider.advanceStatus(widget.orderId);
    }
    // TODO: open WebSocket + start/stop Geolocator position stream here.
  }

  @override
  Widget build(BuildContext context) {
    final order = context.watch<OrderProvider>().findById(widget.orderId);

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Tracking')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: AppColors.surfaceMuted,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 56, color: AppColors.textSecondary),
                        SizedBox(height: 8),
                        Text(
                          'Google Maps view\n(live vendor location + route to customer)',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_tracking)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.gps_fixed, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text('Broadcasting live location to customer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (order != null) ...[
                    Text('Delivering to ${order.customerName}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(order.deliveryAddress, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton.icon(
                    onPressed: _toggleTracking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _tracking ? AppColors.danger : AppColors.primary,
                    ),
                    icon: Icon(_tracking ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                    label: Text(_tracking ? 'Stop Delivery' : 'Start Delivery'),
                  ),
                  if (_tracking && order != null && order.status == OrderStatus.outForDelivery) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () {
                        context.read<OrderProvider>().advanceStatus(widget.orderId);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Mark as Delivered'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
