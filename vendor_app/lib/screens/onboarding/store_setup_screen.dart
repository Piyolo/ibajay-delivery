import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vendor.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import '../main_shell.dart';

class StoreSetupScreen extends StatefulWidget {
  const StoreSetupScreen({super.key});

  @override
  State<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends State<StoreSetupScreen> {
  int _step = 0;
  late final TextEditingController _storeName;
  late final TextEditingController _description;
  final _address = TextEditingController();
  final Set<String> _selectedCategories = {'Meals'};
  late List<OperatingHours> _hours;
  late DeliverySettings _delivery;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final provider = context.read<VendorProvider>();
      _storeName = TextEditingController(text: provider.pendingStoreName);
      _description = TextEditingController(text: provider.pendingStoreDescription);
      _hours = OperatingHours.defaultWeek();
      _delivery = DeliverySettings();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _storeName.dispose();
    _description.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_storeName.text.trim().isEmpty) {
      setState(() {
        _step = 0;
        _error = 'Store name is required';
      });
      return;
    }
    if (_address.text.trim().isEmpty) {
      setState(() {
        _step = 0;
        _error = 'Store address is required';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final provider = context.read<VendorProvider>();
    final ok = await provider.createStore(
      storeName: _storeName.text.trim(),
      description: _description.text.trim(),
      address: _address.text.trim(),
      categories: _selectedCategories.toList(),
      delivery: _delivery,
      hours: _hours,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = ok ? null : (provider.lastAuthError ?? 'Could not create the store');
    });
    if (!ok) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = [_detailsStep(), _categoriesStep(), _hoursStep(), _deliveryStep()];
    return Scaffold(
      appBar: AppBar(
        title: Text('Set Up Your Store (${_step + 1}/4)'),
        automaticallyImplyLeading: false,
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step--),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
              child: Row(
                children: List.generate(4, (i) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _step ? AppColors.primary : AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: steps[_step],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () {
                          if (_step < 3) {
                            setState(() => _step++);
                          } else {
                            _finish();
                          }
                        },
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(_step < 3 ? 'Next' : 'Finish Setup'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tell us about your store', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Customers see this on your store profile.',
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        const Text('Store Name', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(controller: _storeName),
        const SizedBox(height: 16),
        const Text('Description', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(controller: _description, maxLines: 3),
        const SizedBox(height: 16),
        const Text('Store Address', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _address,
          decoration: const InputDecoration(hintText: 'e.g. Rizal St, Poblacion, Ibajay, Aklan'),
        ),
      ],
    );
  }

  Widget _categoriesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What does your store sell?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Pick all that apply. This helps customers find you.',
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: kStoreCategoryOptions.map((c) {
            final selected = _selectedCategories.contains(c);
            return FilterChip(
              label: Text(c),
              selected: selected,
              onSelected: (v) => setState(() {
                v ? _selectedCategories.add(c) : _selectedCategories.remove(c);
              }),
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _hoursStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Operating Hours', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Your store status updates automatically based on this schedule.',
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        ..._hours.map((h) => _hourRow(h)),
      ],
    );
  }

  Widget _hourRow(OperatingHours h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(h.day, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
            child: h.isOpen
                ? Text('${h.openTime} – ${h.closeTime}', style: const TextStyle(color: AppColors.textSecondary))
                : const Text('Closed', style: TextStyle(color: AppColors.textSecondary)),
          ),
          Switch(
            value: h.isOpen,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => setState(() => h.isOpen = v),
          ),
        ],
      ),
    );
  }

  Widget _deliveryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Delivery Options', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        _switchTile(
          title: 'Delivery',
          subtitle: 'Your team delivers orders to customers',
          value: _delivery.deliveryEnabled,
          onChanged: (v) => setState(() => _delivery.deliveryEnabled = v),
        ),
        _switchTile(
          title: 'Pickup',
          subtitle: 'Customers pick up orders at your store',
          value: _delivery.pickupEnabled,
          onChanged: (v) => setState(() => _delivery.pickupEnabled = v),
        ),
        _switchTile(
          title: 'Scheduled Delivery',
          subtitle: 'Allow customers to pick a future date & time',
          value: _delivery.scheduledDeliveryEnabled,
          onChanged: (v) => setState(() => _delivery.scheduledDeliveryEnabled = v),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text('Delivery Areas', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            Text(
              '${_delivery.deliveryBarangays.length} of ${kIbajayBarangays.length} selected',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Pick which barangays in Ibajay you can deliver to — you can adjust this later in Delivery Settings.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kIbajayBarangays.map((b) {
            final selected = _delivery.deliveryBarangays.contains(b);
            return FilterChip(
              label: Text(b),
              selected: selected,
              onSelected: (_) => setState(() {
                selected
                    ? _delivery.deliveryBarangays.remove(b)
                    : _delivery.deliveryBarangays.add(b);
              }),
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12.5,
              ),
            );
          }).toList(),
        ),
      ],
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
}
