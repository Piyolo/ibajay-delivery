import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../theme/app_theme.dart';

/// Vendor-side "Start Delivery" flow: flips the order to out_for_delivery
/// on the backend (POST /tracking/{id}/start) and streams the device's GPS
/// position to the backend every few seconds, which the backend relays to
/// the customer's live tracking screen.
class DeliveryTrackingScreen extends StatefulWidget {
  final String orderId;
  const DeliveryTrackingScreen({super.key, required this.orderId});

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  bool _tracking = false;
  bool _starting = false;
  StreamSubscription<Position>? _positionSub;
  String? _lastPing;

  @override
  void initState() {
    super.initState();
    // Reopening an in-progress delivery must resume GPS sharing — otherwise
    // the customer's tracking view freezes while the order stays
    // out_for_delivery.
    WidgetsBinding.instance.addPostFrameCallback((_) => _resumeIfNeeded());
  }

  void _resumeIfNeeded() {
    final order = context.read<OrderProvider>().findById(widget.orderId);
    if (order?.status == OrderStatus.outForDelivery && !_tracking) {
      _startGpsStream();
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<bool> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<void> _startDelivery() async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<OrderProvider>();
    if (!await _ensurePermission()) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Location permission is required to share live tracking')));
      return;
    }

    setState(() => _starting = true);
    try {
      // Backend transition: ready → out_for_delivery (+ broadcast).
      // Only after the backend confirms does GPS streaming begin.
      await provider.startDelivery(widget.orderId);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not start delivery — check your connection')));
      if (mounted) setState(() => _starting = false);
      return;
    }
    if (!mounted) return;
    setState(() => _starting = false);
    _startGpsStream();
  }

  /// Streams GPS pings every few seconds while delivering. Live tracking is
  /// only ever active while the order is out_for_delivery.
  void _startGpsStream() {
    final provider = context.read<OrderProvider>();
    _positionSub?.cancel();
    setState(() => _tracking = true);
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        timeLimit: Duration(minutes: 5),
      ),
    ).listen(
      (position) async {
        await provider.sendGpsPing(
          widget.orderId,
          latitude: position.latitude,
          longitude: position.longitude,
        );
        if (mounted) {
          setState(() =>
              _lastPing = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}');
        }
      },
      onError: (_) {
        // Never keep claiming we're live when the stream has died.
        if (mounted) {
          setState(() => _tracking = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Live location sharing stopped — resume it below')));
        }
      },
    );
  }

  /// Stops GPS pings. Called before marking the order delivered so tracking
  /// ends exactly when the delivery ends.
  void _stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    if (mounted) setState(() => _tracking = false);
  }

  Future<void> _markDelivered() async {
    final provider = context.read<OrderProvider>();
    _stopTracking();
    await provider.advanceStatus(widget.orderId);
    if (mounted) Navigator.of(context).pop();
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
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _tracking ? Icons.radar : Icons.map_outlined,
                          size: 56,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _tracking
                              ? 'Sharing live location with the customer\n$_lastPing'
                              : 'Live location sharing is off.\nResume it so the customer can follow your delivery.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
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
                          Expanded(
                            child: Text('Broadcasting live location to customer',
                                style: TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
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
                    Text('Delivering to ${order.customerName}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(order.deliveryAddress,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 16),
                  ],
                  if (order != null && order.status == OrderStatus.ready)
                    ElevatedButton.icon(
                      onPressed: (_tracking || _starting) ? null : _startDelivery,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      icon: _starting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.play_circle_outline),
                      label: const Text('Start Delivery'),
                    ),
                  if (order != null && order.status == OrderStatus.outForDelivery) ...[
                    if (!_tracking)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          if (await _ensurePermission()) {
                            _startGpsStream();
                          } else if (mounted) {
                            messenger.showSnackBar(const SnackBar(
                                content: Text(
                                    'Location permission is required to share live tracking')));
                          }
                        },
                        icon: const Icon(Icons.location_searching),
                        label: const Text('Resume Live Tracking'),
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _markDelivered,
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
