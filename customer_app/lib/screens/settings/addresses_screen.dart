import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/location_constants.dart';
import '../../models/user.dart';
import '../../providers/location_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/osm_location_picker.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('My Addresses')),
      body: location.addresses.isEmpty
          ? const EmptyState(
              icon: Icons.location_off_outlined,
              title: 'No saved addresses',
              subtitle: 'Add a delivery address to start ordering.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: location.addresses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final addr = location.addresses[i];
                final isActive = location.activeAddress?.id == addr.id;
                return Card(
                  child: ListTile(
                    leading: Icon(
                      addr.label == 'Home'
                          ? Icons.home
                          : addr.label == 'Work'
                              ? Icons.work
                              : Icons.location_on,
                      color: isActive ? AppColors.primary : AppColors.textSecondary,
                    ),
                    title: Row(
                      children: [
                        Text(addr.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (addr.isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: const Text('Default',
                                style: TextStyle(fontSize: 10, color: AppColors.secondary)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text('Brgy. ${addr.barangay.isEmpty ? '—' : addr.barangay} · ${addr.fullAddress}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                      onPressed: () => location.removeAddress(addr.id),
                    ),
                    onTap: () => location.setActive(addr.id),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAddressSheet(context),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add Address'),
      ),
    );
  }

  void _showAddAddressSheet(BuildContext context) {
    final labelController = TextEditingController(text: 'Home');
    PickedLocation picked = const PickedLocation(
      lat: LocationConstants.townLat,
      lng: LocationConstants.townLng,
      address: 'Poblacion, Ibajay, Aklan',
      barangay: 'Poblacion',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pin your delivery address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(labelText: 'Label (e.g. Home, Work)'),
                ),
                const SizedBox(height: 12),
                OsmLocationPicker(
                  height: 240,
                  onChanged: (p) => setSheetState(() => picked = p),
                ),
                if (picked.outsideIbajay)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.local_shipping_outlined, size: 18, color: AppColors.warning),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Outside Ibajay — deliveries aren't available here; "
                            'this address can only be used for pickup orders.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (picked.address.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(picked.address,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.read<LocationProvider>().addAddress(SavedAddress(
                            id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
                            label:
                                labelController.text.trim().isEmpty ? 'Home' : labelController.text.trim(),
                            fullAddress: picked.address.isNotEmpty
                                ? picked.address
                                : 'Lat ${picked.lat.toStringAsFixed(5)}, Lng ${picked.lng.toStringAsFixed(5)}',
                            barangay: picked.barangay,
                            latitude: picked.lat,
                            longitude: picked.lng,
                          ));
                    },
                    child: const Text('Save Address'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
