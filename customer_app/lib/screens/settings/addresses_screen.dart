import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/location_constants.dart';
import '../../models/user.dart';
import '../../providers/location_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

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
                    subtitle: Text('Brgy. ${addr.barangay} · ${addr.fullAddress}'),
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
    final addressController = TextEditingController();
    String barangay = 'Poblacion';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                const Text('Add a new address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(labelText: 'Label (e.g. Home, Work)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: barangay,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_city_outlined),
                    labelText: 'Barangay',
                  ),
                  items: LocationConstants.ibajayBarangays
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setSheetState(() => barangay = v ?? barangay),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Full Address',
                    hintText: 'House number, street, landmark',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pin location defaults to Ibajay town center for this demo — real builds use the map picker.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (addressController.text.trim().isEmpty) return;
                      context.read<LocationProvider>().addAddress(SavedAddress(
                            id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
                            label: labelController.text.trim().isEmpty ? 'Home' : labelController.text.trim(),
                            fullAddress: addressController.text.trim(),
                            barangay: barangay,
                            latitude: LocationConstants.townLat,
                            longitude: LocationConstants.townLng,
                          ));
                      Navigator.of(sheetContext).pop();
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
