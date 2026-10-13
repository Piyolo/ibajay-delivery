import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';

/// Read-only OpenStreetMap view for delivery tracking (no API key).
///
/// Shows the customer's delivery pin and — while an order is out for
/// delivery — the rider's live position (from GPS pings relayed by the
/// backend). The camera fits both points the first time they're known;
/// afterwards the vendor is free to pan/zoom without fighting an
/// auto-recenter. Pickup orders (no coordinates) render nothing.
class TrackingMap extends StatefulWidget {
  final LatLng? destination;
  final LatLng? rider;
  final double height;

  const TrackingMap({super.key, this.destination, this.rider, this.height = 220});

  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap> {
  MapController? _mapController;
  bool _didInitialFit = false;

  @override
  void didUpdateWidget(covariant TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fit once, when both points first become known (typically the rider
    // ping arriving after the destination was already on screen).
    if (!_didInitialFit &&
        widget.destination != null &&
        widget.rider != null &&
        (oldWidget.rider == null || widget.rider != oldWidget.rider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBoth());
    }
  }

  void _fitBoth() {
    final controller = _mapController;
    final destination = widget.destination;
    final rider = widget.rider;
    if (controller == null || destination == null || rider == null) return;
    _didInitialFit = true;
    try {
      controller.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([destination, rider]),
        padding: const EdgeInsets.all(48),
      ));
    } catch (_) {
      // Map not laid out yet — the next rider ping retries.
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
    if (destination == null) return const SizedBox.shrink();
    final rider = widget.rider;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        height: widget.height,
        child: FlutterMap(
          mapController: _mapController ??= MapController(),
          options: MapOptions(
            initialCenter: rider ?? destination,
            initialZoom: rider != null ? 13 : 16,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ibajayeats.vendor',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: destination,
                  width: 40,
                  height: 40,
                  alignment: Alignment.topCenter,
                  child: const Icon(
                    Icons.location_on,
                    size: 36,
                    color: AppColors.primary,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                  ),
                ),
                if (rider != null)
                  Marker(
                    point: rider,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.delivery_dining,
                      size: 32,
                      color: AppColors.success,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
