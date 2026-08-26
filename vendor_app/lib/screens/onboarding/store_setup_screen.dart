import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../models/vendor.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/osm_location_picker.dart';
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
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  PickedLocation _picked = const PickedLocation(
    lat: 11.8188,
    lng: 122.1607,
    address: 'Poblacion, Ibajay, Aklan',
    barangay: 'Poblacion',
  );
  bool _showSuggestions = false;
  bool _searching = false;
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

  /// Free-text search: barangay names jump instantly from local data;
  /// anything else falls back to OpenStreetMap's geocoder.
  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final barangay = matchIbajayBarangay(query);
    if (barangay != null && barangayCenter(barangay) != null) {
      _applyBarangay(barangay);
      return;
    }

    setState(() => _searching = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent("$query, Ibajay, Aklan, Philippines")}'
        '&format=jsonv2&limit=1&countrycodes=ph',
      );
      final response = await http
          .get(uri, headers: {'User-Agent': 'ibajay-eats-vendor/0.1'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List;
        if (results.isNotEmpty && mounted) {
          final hit = results.first as Map<String, dynamic>;
          final lat = double.tryParse(hit['lat'] as String? ?? '');
          final lon = double.tryParse(hit['lon'] as String? ?? '');
          if (lat != null && lon != null) {
            final match = matchIbajayBarangay(query);
            setState(() {
              _picked = PickedLocation(
                lat: lat,
                lng: lon,
                address:
                    (hit['display_name'] as String?)?.split(',').take(3).join(', ') ??
                        query,
                barangay: match ?? _picked.barangay,
              );
              if (_picked.address.isNotEmpty) _address.text = _picked.address;
              _showSuggestions = false;
              _searchFocus.unfocus();
            });
          }
          return;
        }
      }
      messenger.showSnackBar(const SnackBar(
          content: Text('No matching place found — try a barangay name or tap the map')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Search is unavailable right now — try a barangay name')));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  void dispose() {
    _storeName.dispose();
    _description.dispose();
    _address.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<String> get _suggestions => suggestIbajayBarangays(_searchController.text);

  /// Barangay chosen via search suggestion or dropdown: jump the pin to its
  /// known center instantly (offline) and let the picker refine from there.
  void _applyBarangay(String barangay) {
    final center = barangayCenter(barangay);
    setState(() {
      _searchController.text = barangay;
      _showSuggestions = false;
      _searchFocus.unfocus();
      _picked = PickedLocation(
        lat: center?[0] ?? 11.8211,
        lng: center?[1] ?? 122.1617,
        address: 'Brgy. $barangay, Ibajay, Aklan',
        barangay: barangay,
      );
      _address.text = 'Brgy. $barangay, Ibajay, Aklan';
    });
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
        _error = 'Pick your store location on the map';
      });
      return;
    }
    if (_picked.outsideIbajay) {
      setState(() {
        _step = 0;
        _error = "Your store must be located in Ibajay, Aklan";
      });
      return;
    }
    // At least one fulfillment option must remain available.
    if (!_delivery.deliveryEnabled && !_delivery.pickupEnabled && !_delivery.scheduledDeliveryEnabled) {
      setState(() {
        _step = 3;
        _error = 'Enable at least one option — delivery, pickup, or scheduled delivery';
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
      latitude: _picked.lat,
      longitude: _picked.lng,
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
        const Text('Store Location', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(
          'Search your barangay or tap the map — the pin must sit inside Ibajay. '
          'The address is filled in for you.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search barangay (e.g. Aslum)',
            isDense: true,
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
        if (_showSuggestions && _suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 44),
                  itemBuilder: (context, i) {
                    final b = _suggestions[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_city_outlined,
                          size: 18, color: AppColors.textSecondary),
                      title: Text(b, style: const TextStyle(fontSize: 14)),
                      subtitle: const Text('Barangay, Ibajay, Aklan',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      onTap: () => _applyBarangay(b),
                    );
                  },
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        OsmLocationPicker(
          initial: _picked,
          target: _picked,
          height: 240,
          onChanged: (p) {
            // Map taps update the pin; don't reopen suggestions.
            setState(() {
              _picked = p;
              _showSuggestions = false;
              if (p.address.isNotEmpty) _address.text = p.address;
            });
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue:
              kIbajayBarangays.contains(_picked.barangay) ? _picked.barangay : 'Poblacion',
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.location_city_outlined),
            labelText: 'Barangay',
            isDense: true,
          ),
          items: kIbajayBarangays.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
          onChanged: (v) {
            if (v == null || v == _picked.barangay) return;
            _applyBarangay(v);
          },
        ),
        const SizedBox(height: 10),
        if (_picked.outsideIbajay)
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
                Icon(Icons.storefront_outlined, size: 18, color: AppColors.warning),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "This spot is outside Ibajay — move the pin inside the municipality "
                    'to continue.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        TextFormField(
          controller: _address,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Picked address appears here — you can add details like the landmark',
          ),
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
    // Scheduled delivery is independent: a store can offer ONLY scheduled
    // delivery (regular delivery + pickup both off), or any combination —
    // as long as at least one option is on.
    final showDeliveryAreas =
        _delivery.deliveryEnabled || _delivery.scheduledDeliveryEnabled;
    final noneSelected = !_delivery.deliveryEnabled &&
        !_delivery.pickupEnabled &&
        !_delivery.scheduledDeliveryEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Delivery Options', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text(
          'Pick how customers can receive their orders. You can offer scheduled '
          'delivery on its own, or combine options.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
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
        if (noneSelected)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Text(
              'Enable at least one option so customers can order from you.',
              style: TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        if (showDeliveryAreas) ...[
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
