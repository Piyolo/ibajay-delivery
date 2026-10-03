import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/vendor.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';

class DeliverySettingsScreen extends StatefulWidget {
  const DeliverySettingsScreen({super.key});

  @override
  State<DeliverySettingsScreen> createState() => _DeliverySettingsScreenState();
}

class _DeliverySettingsScreenState extends State<DeliverySettingsScreen> {
  late DeliverySettings _settings;
  late TextEditingController _feeController;
  String _search = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = context.read<VendorProvider>().vendor.deliverySettings;
    // Work on a copy so cancelling (back button) doesn't leave a half-edited state.
    _settings = DeliverySettings(
      deliveryEnabled: current.deliveryEnabled,
      pickupEnabled: current.pickupEnabled,
      scheduledDeliveryEnabled: current.scheduledDeliveryEnabled,
      deliveryBarangays: [...current.deliveryBarangays],
      baseDeliveryFee: current.baseDeliveryFee,
    );
    _feeController = TextEditingController(text: current.baseDeliveryFee.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final provider = context.read<VendorProvider>();
    await provider.updateDeliverySettings(_settings);
    if (!mounted) return;
    setState(() => _saving = false);
    if (provider.lastError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Not saved — ${provider.lastError}')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery settings saved')));
    Navigator.of(context).pop();
  }

  void _toggleBarangay(String b) {
    setState(() {
      _settings.deliveryBarangays.contains(b)
          ? _settings.deliveryBarangays.remove(b)
          : _settings.deliveryBarangays.add(b);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Settings'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _switchTile(
              title: 'Delivery',
              subtitle: 'Your team delivers orders to customers',
              value: _settings.deliveryEnabled,
              onChanged: (v) => setState(() => _settings.deliveryEnabled = v),
            ),
            _switchTile(
              title: 'Pickup',
              subtitle: 'Customers pick up orders at your store',
              value: _settings.pickupEnabled,
              onChanged: (v) => setState(() => _settings.pickupEnabled = v),
            ),
            _switchTile(
              title: 'Scheduled Delivery',
              subtitle: 'Allow customers to pick a future date & time',
              value: _settings.scheduledDeliveryEnabled,
              onChanged: (v) => setState(() => _settings.scheduledDeliveryEnabled = v),
            ),
            const SizedBox(height: 16),
            const Text('Delivery Fee (₱)', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _feeRow(
              controller: _feeController,
              label: 'Flat delivery fee',
              value: _settings.baseDeliveryFee,
              onChanged: (v) => setState(() => _settings.baseDeliveryFee = v),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text('Delivery Areas', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text(
                  '${_settings.deliveryBarangays.length} of ${kIbajayBarangays.length} barangays',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Pick which barangays in Ibajay you can deliver to. Customers outside these areas won\'t be offered delivery.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 20),
                      hintText: 'Search barangay',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _settings.deliveryBarangays = [...kIbajayBarangays]),
                  child: const Text('All'),
                ),
                TextButton(
                  onPressed: () => setState(() => _settings.deliveryBarangays = []),
                  child: const Text('None'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._filteredBarangays.map(_barangayTile),
            if (_filteredBarangays.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No barangays match your search.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  List<String> get _filteredBarangays {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return kIbajayBarangays;
    return kIbajayBarangays.where((b) => b.toLowerCase().contains(q)).toList();
  }

  Widget _barangayTile(String b) {
    final selected = _settings.deliveryBarangays.contains(b);
    return CheckboxListTile(
      value: selected,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(b, style: const TextStyle(fontSize: 14)),
      activeColor: AppColors.primary,
      onChanged: (_) => _toggleBarangay(b),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        value: value,
        activeThumbColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }

  Widget _feeRow({
    required TextEditingController controller,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        SizedBox(
          width: 90,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            onChanged: (v) => onChanged(double.tryParse(v) ?? value),
          ),
        ),
      ],
    );
  }
}
