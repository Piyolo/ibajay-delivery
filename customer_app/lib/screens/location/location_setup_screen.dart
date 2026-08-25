import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/location_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../theme/app_theme.dart';
import '../main_shell.dart';

/// Location Setup: search + pin-drop over a map. Google Maps SDK integration
/// point is `_MapPlaceholder` below — swap it for a real GoogleMap widget
/// with a draggable marker once the API key is configured.
class LocationSetupScreen extends StatefulWidget {
  const LocationSetupScreen({super.key});

  @override
  State<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends State<LocationSetupScreen> {
  final _searchController = TextEditingController();
  double _lat = LocationConstants.townLat;
  double _lng = LocationConstants.townLng;
  String _address = 'Poblacion, Ibajay, Aklan';
  String _barangay = 'Poblacion';
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _dragPin(Offset delta) {
    setState(() {
      // Coarse simulated drag: nudges lat/lng slightly per pixel of drag.
      _lng += delta.dx * 0.00003;
      _lat -= delta.dy * 0.00003;
    });
  }

  Future<void> _saveLocation() async {
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    context.read<LocationProvider>().saveInitialLocation(
          fullAddress: _address,
          barangay: _barangay,
          lat: _lat,
          lng: _lng,
        );
    context.read<AuthProvider>().markLocationSaved();
    setState(() => _saving = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Your Location'), automaticallyImplyLeading: false),
      // The mock map fills the middle; resizing for the keyboard squeezes
      // the fixed bottom panel and overflows. The keyboard overlays instead.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search address, landmark, or barangay',
                ),
                onSubmitted: (v) => setState(() => _address = v.isEmpty ? _address : v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: DropdownButtonFormField<String>(
                initialValue: _barangay,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.location_city_outlined),
                  labelText: 'Barangay',
                ),
                items: LocationConstants.ibajayBarangays
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _barangay = v ?? _barangay;
                  _address = '$_barangay, Ibajay, Aklan';
                }),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onPanUpdate: (details) => _dragPin(details.delta),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      color: AppColors.surfaceMuted,
                      child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
                    ),
                    const Icon(Icons.location_pin, color: AppColors.primary, size: 52),
                    Positioned(
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Text(
                          'Drag the map to move the pin',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _address,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lat ${_lat.toStringAsFixed(5)}, Lng ${_lng.toStringAsFixed(5)}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveLocation,
                      child: _saving
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                            )
                          : const Text('Save This Location'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "You can't continue until your location is saved.",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
