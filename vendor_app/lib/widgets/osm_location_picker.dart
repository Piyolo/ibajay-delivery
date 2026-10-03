import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/vendor.dart';
import '../theme/app_theme.dart';

/// A picked point plus everything the app derives from it.
class PickedLocation {
  final double lat;
  final double lng;
  final String address;
  final String barangay;
  final bool outsideIbajay;

  const PickedLocation({
    required this.lat,
    required this.lng,
    this.address = '',
    this.barangay = '',
    this.outsideIbajay = false,
  });
}

/// OpenStreetMap-based location picker (no API key needed).
///
/// Tap anywhere to drop the pin exactly there; the pin is a real map
/// marker anchored at the chosen point. After every move the position is
/// reverse-geocoded via Nominatim into an address + barangay guess and
/// reported through [onChanged].
///
/// Outside-Ibajay detection combines the distance check with the
/// reverse-geocoded municipality: picks Nominatim identifies as Ibajay are
/// always inside (remote mountain barangays), picks identified as a
/// neighboring town are always outside.
class OsmLocationPicker extends StatefulWidget {
  final PickedLocation initial;
  final double height;
  final ValueChanged<PickedLocation> onChanged;

  /// When the parent moves the selection externally (search, barangay
  /// dropdown), the camera follows. Compare by lat/lng.
  final PickedLocation? target;

  const OsmLocationPicker({
    super.key,
    this.initial = const PickedLocation(lat: kIbajayTownLat, lng: kIbajayTownLng),
    this.height = 260,
    required this.onChanged,
    this.target,
  });

  @override
  State<OsmLocationPicker> createState() => _OsmLocationPickerState();
}

class _OsmLocationPickerState extends State<OsmLocationPicker> {
  late LatLng _point;
  MapController? _mapController;
  Timer? _geocodeDebounce;
  bool _geocoding = false;
  String _address = '';
  String _barangay = '';
  bool? _outside;
  bool _locating = false;

  /// Where the user last chose a barangay deliberately (setup target).
  /// Near that spot their choice wins over geocoder guesses.
  LatLng? _manualBarangayAnchor;

  @override
  void initState() {
    super.initState();
    _point = LatLng(widget.initial.lat, widget.initial.lng);
    _address = widget.initial.address;
    _barangay = widget.initial.barangay;
    _outside = widget.initial.outsideIbajay;
  }

  @override
  void didUpdateWidget(covariant OsmLocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.target;
    if (target == null) return;
    if (target.lat != oldWidget.target?.lat || target.lng != oldWidget.target?.lng) {
      final newPoint = LatLng(target.lat, target.lng);
      if (newPoint != _point) {
        setState(() {
          _point = newPoint;
          _address = target.address;
          if (target.barangay.isNotEmpty) {
            _barangay = target.barangay;
            _manualBarangayAnchor = newPoint;
          }
          _outside = target.outsideIbajay;
        });
        _mapController?.move(newPoint, 16);
        _resolve();
      }
    }
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    super.dispose();
  }

  bool get _distanceOutside {
    const r = 6371.0;
    final dLat = (_point.latitude - kIbajayTownLat) * (math.pi / 180);
    final dLng = (_point.longitude - kIbajayTownLng) * (math.pi / 180);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(kIbajayTownLat * math.pi / 180) *
            math.cos(_point.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)) >
        kIbajayServiceRadiusKm;
  }

  /// Tap-to-place: the pin goes EXACTLY where the user tapped.
  void _placePin(LatLng point) {
    setState(() => _point = point);
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 250), _resolve);
  }

  /// Reverse-geocodes the current point and reports the result upward.
  Future<void> _resolve() async {
    // Captured so a response that arrives after another tap can be
    // discarded instead of labeling the NEW pin with the OLD point's data.
    final requested = _point;

    void report() => widget.onChanged(PickedLocation(
          lat: _point.latitude,
          lng: _point.longitude,
          address: _address,
          barangay: _barangay,
          outsideIbajay: _outside ?? _distanceOutside,
        ));

    // Report coordinates immediately so saving never blocks on geocoding.
    report();

    setState(() => _geocoding = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${_point.latitude}&lon=${_point.longitude}'
        '&format=jsonv2&zoom=17&addressdetails=1',
      );
      final response = await http
          .get(uri, headers: {'User-Agent': 'ibajay-eats-vendor/0.1'})
          .timeout(const Duration(seconds: 10));
      // Another tap moved the pin while this request was in flight.
      if (requested != _point) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};

        String? areaName;
        for (final key in [
          'suburb', 'city_district', 'village', 'hamlet', 'quarter',
          'neighbourhood',
        ]) {
          final v = address[key] as String?;
          if (v != null && v.isNotEmpty) {
            areaName = v;
            break;
          }
        }
        String? match = matchIbajayBarangay(areaName ?? '');

        // Cross-check the geocoder's label against known barangay centers
        // (rural OSM labels are sparse and can name the neighbor).
        final nearest = nearestBarangayTo(_point.latitude, _point.longitude);
        if (match != null && nearest.key.isNotEmpty && nearest.key != match) {
          final center = kBarangayCenters[match]!;
          final labeledKm =
              haversineKm(_point.latitude, _point.longitude, center[0], center[1]);
          if (nearest.value * 2 < labeledKm && labeledKm > 1.0) {
            match = nearest.key;
          }
        } else if (match == null && nearest.key.isNotEmpty && nearest.value <= 2.0) {
          match = nearest.key;
        }

        String? municipality;
        for (final key in ['city', 'municipality', 'town', 'county']) {
          final v = address[key] as String?;
          if (v != null && v.isNotEmpty) {
            municipality = v;
            break;
          }
        }

        bool outside;
        if (municipality != null && municipality.isNotEmpty) {
          final m = municipality.toLowerCase().trim();
          outside = !(m.contains('ibajay')) &&
              kNeighboringMunicipalities.any((n) => m.contains(n));
          if (!outside && !m.contains('ibajay') && _distanceOutside) outside = true;
        } else {
          outside = _distanceOutside;
        }

        final road = address['road'] as String?;
        final house = address['house_number'] as String?;
        final streetBits = [
          if (house?.isNotEmpty == true) house!,
          if (road?.isNotEmpty == true) road!
        ];
        final label = [
          ...streetBits,
          if (!outside && match != null) 'Brgy. $match',
          if (!outside) 'Ibajay, Aklan',
        ].where((s) => s.isNotEmpty).join(', ');

        if (mounted) {
          setState(() {
            _outside = outside;
            if (label.isNotEmpty) _address = label;
            final nearManualChoice = _manualBarangayAnchor != null &&
                _barangay.isNotEmpty &&
                haversineKm(
                      _point.latitude,
                      _point.longitude,
                      _manualBarangayAnchor!.latitude,
                      _manualBarangayAnchor!.longitude,
                    ) <
                    0.5;
            if (!nearManualChoice) {
              if (match != null) _barangay = match;
              _manualBarangayAnchor = null;
            }
          });
          report();
        }
      }
    } catch (_) {
      // Offline / rate-limited: coordinates are already reported.
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        if (!mounted) return;
        _mapController?.move(
          LatLng(position.latitude, position.longitude),
          _mapController!.camera.zoom < 15 ? 16 : _mapController!.camera.zoom,
        );
        _placePin(LatLng(position.latitude, position.longitude));
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Location permission was not granted')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not get your current location')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: widget.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: FlutterMap(
              mapController: _mapController ??= MapController(),
              options: MapOptions(
                initialCenter: _point,
                initialZoom: 15.5,
                onTap: (_, latLng) => _placePin(latLng),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ibajayeats.vendor',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _point,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on,
                        size: 40,
                        color: AppColors.primary,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _locating ? null : _useMyLocation,
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location,
                        size: 20, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
        if (_geocoding)
          const Positioned(
            top: 8,
            left: 8,
            child: IgnorePointer(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}
