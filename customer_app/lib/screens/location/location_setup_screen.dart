import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../constants/location_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/osm_location_picker.dart';
import '../main_shell.dart';

/// Location Setup: pick your delivery address on a real OpenStreetMap.
///
/// Search understands Ibajay's barangays natively — typing "a" suggests
/// Agbago/Aquino/Aslum… and picking one jumps the pin straight there
/// (offline, from the built-in coordinates). Non-barangay queries fall
/// back to OpenStreetMap's geocoder. Picks outside Ibajay are allowed
/// (pickup still works) but the app makes clear that delivery isn't
/// available there.
class LocationSetupScreen extends StatefulWidget {
  const LocationSetupScreen({super.key});

  @override
  State<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends State<LocationSetupScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  PickedLocation _picked = const PickedLocation(
    lat: LocationConstants.townLat,
    lng: LocationConstants.townLng,
    address: 'Poblacion, Ibajay, Aklan',
    barangay: 'Poblacion',
  );
  bool _saving = false;
  bool _searching = false;
  bool _showSuggestions = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<String> get _suggestions =>
      LocationConstants.suggestBarangays(_searchController.text);

  void _applyBarangay(String barangay) {
    final coords = LocationConstants.coordinatesForBarangay(barangay);
    setState(() {
      _searchController.text = barangay;
      _showSuggestions = false;
      _searchFocus.unfocus();
      _picked = PickedLocation(
        lat: coords?.lat ?? LocationConstants.townLat,
        lng: coords?.lng ?? LocationConstants.townLng,
        address: 'Brgy. $barangay, Ibajay, Aklan',
        barangay: barangay,
        outsideIbajay: false,
      );
    });
  }

  /// Free-text search: barangay names jump instantly from local data;
  /// anything else falls back to OpenStreetMap's geocoder.
  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // 1. Direct / fuzzy barangay match wins.
    final barangay = LocationConstants.matchBarangay(query);
    if (barangay != null &&
        LocationConstants.coordinatesForBarangay(barangay) != null) {
      _applyBarangay(barangay);
      return;
    }

    // 2. Nominatim forward search.
    setState(() => _searching = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent("$query, Ibajay, Aklan, Philippines")}'
        '&format=jsonv2&limit=1&countrycodes=ph',
      );
      final response = await http
          .get(uri, headers: {'User-Agent': 'ibajay-eats-app/0.1'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List;
        if (results.isNotEmpty) {
          final hit = results.first as Map<String, dynamic>;
          final lat = double.tryParse(hit['lat'] as String? ?? '');
          final lon = double.tryParse(hit['lon'] as String? ?? '');
          if (lat != null && lon != null && mounted) {
            final match = LocationConstants.matchBarangay(query);
            setState(() {
              _picked = PickedLocation(
                lat: lat,
                lng: lon,
                address:
                    (hit['display_name'] as String?)?.split(',').take(3).join(', ') ??
                        query,
                barangay: match ?? _picked.barangay,
                outsideIbajay: !LocationConstants.isInServiceArea(lat, lon),
              );
              _showSuggestions = false;
              _searchFocus.unfocus();
            });
          }
          return;
        }
      }
      messenger.showSnackBar(const SnackBar(
          content: Text('No matching place found — try a barangay name or drag/tap the map')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Search is unavailable right now — try a barangay name')));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _saveLocation() async {
    // Outside Ibajay: inform before saving — delivery won't be offered,
    // only pickup at stores that allow it.
    if (_picked.outsideIbajay) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.local_shipping_outlined, color: AppColors.warning, size: 36),
          title: const Text('Outside our delivery area'),
          content: const Text(
            "Your chosen location is outside Ibajay. Deliveries aren't available "
            'in your area yet — you can still order with Pickup from stores near town.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Pick Again')),
            ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Save Anyway')),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    setState(() => _saving = true);
    await context.read<LocationProvider>().saveInitialLocation(
          fullAddress: _picked.address.isNotEmpty
              ? _picked.address
              : '${_picked.barangay.isEmpty ? 'Ibajay' : _picked.barangay}, Ibajay, Aklan',
          barangay: _picked.barangay,
          lat: _picked.lat,
          lng: _picked.lng,
        );
    if (!mounted) return;
    context.read<AuthProvider>().markLocationSaved();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final outside = _picked.outsideIbajay;

    return Scaffold(
      appBar: AppBar(title: const Text('Set Your Location'), automaticallyImplyLeading: false),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search barangay or place (e.g. Aslum)',
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : (_searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _showSuggestions = false);
                              },
                            )
                          : null),
                ),
                onChanged: (_) => setState(() => _showSuggestions = true),
                onSubmitted: (_) => _search(),
              ),
            ),
            // Type-ahead suggestions from Ibajay's own barangay list.
            if (_showSuggestions && _suggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 44),
                      itemBuilder: (context, i) {
                        final b = _suggestions[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_city_outlined,
                              size: 18, color: AppColors.textSecondary),
                          title: Text(b, style: const TextStyle(fontSize: 14)),
                          subtitle: const Text('Barangay, Ibajay, Aklan',
                              style:
                                  TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          onTap: () => _applyBarangay(b),
                        );
                      },
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: OsmLocationPicker(
                initial: _picked,
                target: _picked,
                height: MediaQuery.of(context).size.height * 0.32,
                onChanged: (p) {
                  // Map taps update the pin; don't reopen suggestions.
                  setState(() {
                    _picked = p;
                    _showSuggestions = false;
                  });
                },
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _picked.address.isNotEmpty
                                ? _picked.address
                                : 'Lat ${_picked.lat.toStringAsFixed(5)}, Lng ${_picked.lng.toStringAsFixed(5)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (outside) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 18, color: AppColors.warning),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "You're outside Ibajay — deliveries aren't available here. "
                                'Pickup orders still work.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: LocationConstants.ibajayBarangays.contains(_picked.barangay)
                            ? _picked.barangay
                            : 'Poblacion',
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.location_city_outlined),
                          labelText: 'Barangay',
                          isDense: true,
                        ),
                        items: LocationConstants.ibajayBarangays
                            .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                            .toList(),
                        onChanged: (v) {
                          if (v == null || v == _picked.barangay) return;
                          _applyBarangay(v);
                        },
                      ),
                    ],
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
                    Text(
                      _picked.barangay.isEmpty && !outside
                          ? 'Tip: tap the map or search for your barangay.'
                          : "You can't continue until your location is saved.",
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
