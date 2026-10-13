import 'package:flutter/material.dart';

import '../constants/location_constants.dart';

/// Barangay picker shared by the location-setup flow (new account + home
/// address chip) and Manage Addresses' add-address sheet, so every
/// address form offers the same list sourced from
/// [LocationConstants.ibajayBarangays].
///
/// [onChanged] receives the picked barangay; callers are expected to move
/// the pin to that barangay's coordinates (see `_applyBarangay` in
/// location_setup_screen.dart) so delivery coverage stays accurate.
class BarangayDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const BarangayDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      // Rebuilds the field when the barangay changes from the map/search.
      key: ValueKey(value),
      initialValue: LocationConstants.ibajayBarangays.contains(value)
          ? value
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
        if (v == null || v == value) return;
        onChanged(v);
      },
    );
  }
}
