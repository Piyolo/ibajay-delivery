import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/vendor_card.dart';
import '../vendor/vendor_profile_screen.dart';

/// Full-page, filterable store directory — reached via "See all" from any
/// Home screen section. Shares filter/search state with [VendorProvider],
/// so switching between here and Home stays in sync.
class StoreListingScreen extends StatelessWidget {
  const StoreListingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vendorProvider = context.watch<VendorProvider>();
    final location = context.watch<LocationProvider>();
    final results = vendorProvider.nearbyVendors(
      refLat: location.referenceLat,
      refLng: location.referenceLng,
      refBarangay: location.referenceBarangay,
    );
    final hasActiveFilters = vendorProvider.selectedCategory != null ||
        vendorProvider.filterOpenNow ||
        vendorProvider.filterDeliveryAvailable ||
        vendorProvider.filterPickupAvailable ||
        vendorProvider.filterScheduledAvailable ||
        vendorProvider.searchQuery.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('All Stores')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              // Controller-backed so it stays in sync with Home's field
              // (both read/write VendorProvider.searchQuery).
              child: _SearchField(vendorProvider: vendorProvider),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChip(
                    label: 'Open Now',
                    selected: vendorProvider.filterOpenNow,
                    onTap: vendorProvider.toggleOpenNow,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Delivery',
                    selected: vendorProvider.filterDeliveryAvailable,
                    onTap: vendorProvider.toggleDelivery,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Pickup',
                    selected: vendorProvider.filterPickupAvailable,
                    onTap: vendorProvider.togglePickup,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Scheduled',
                    selected: vendorProvider.filterScheduledAvailable,
                    onTap: vendorProvider.toggleScheduled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _CategoryChip(
                    label: 'All',
                    selected: vendorProvider.selectedCategory == null,
                    onTap: () => vendorProvider.setCategory(null),
                  ),
                  const SizedBox(width: 8),
                  ...vendorProvider.categories.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _CategoryChip(
                        label: c,
                        selected: vendorProvider.selectedCategory == c,
                        onTap: () => vendorProvider.setCategory(c),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${results.length} store${results.length == 1 ? '' : 's'}'
                    '${vendorProvider.selectedCategory != null ? ' in ${vendorProvider.selectedCategory}' : ''}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                  const Spacer(),
                  if (hasActiveFilters)
                    TextButton(
                      onPressed: () => vendorProvider.clearFilters(),
                      child: const Text('Clear filters', style: TextStyle(fontSize: 12.5)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No stores match your filters',
                      subtitle: vendorProvider.selectedCategory != null
                          ? "Nothing in ${vendorProvider.selectedCategory} right now — try another category."
                          : 'Try clearing a filter or searching for something else.',
                      action: hasActiveFilters
                          ? OutlinedButton(
                              onPressed: () => vendorProvider.clearFilters(),
                              child: const Text('Clear filters'),
                            )
                          : null,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final entry = results[i];
                        return VendorCard(
                          vendor: entry.key,
                          distanceKm: entry.value,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => VendorProfileScreen(vendorId: entry.key.id)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
  }
}

/// Search box whose text always mirrors [VendorProvider.searchQuery], so
/// edits from the Home screen show up here and vice versa.
class _SearchField extends StatefulWidget {
  final VendorProvider vendorProvider;
  const _SearchField({required this.vendorProvider});

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.vendorProvider.searchQuery);

  @override
  void didUpdateWidget(covariant _SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.vendorProvider.searchQuery != _controller.text) {
      _controller.text = widget.vendorProvider.searchQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Search food or store name',
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  widget.vendorProvider.setSearch('');
                  setState(() => _controller.clear());
                },
              )
            : null,
      ),
      onChanged: (v) {
        widget.vendorProvider.setSearch(v);
        setState(() {});
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
    );
  }
}
