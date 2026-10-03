import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/featured_food_card.dart';
import '../../widgets/vendor_card.dart';
import '../../widgets/vendor_card_compact.dart';
import '../cart/cart_screen.dart';
import '../location/location_setup_screen.dart';
import '../vendor/vendor_profile_screen.dart';
import 'store_listing_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vendorProvider = context.watch<VendorProvider>();
    final location = context.watch<LocationProvider>();
    final cart = context.watch<CartProvider>().cart;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const LocationSetupScreen())),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, size: 18, color: AppColors.primary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  location.activeAddress?.fullAddress ?? 'Set your location',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, size: 18),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: cart.vendorName != null ? 'Cart · ${cart.vendorName}' : 'Cart',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
              icon: cart.itemCount > 0
                  ? Badge(
                      label: Text('${cart.itemCount}'),
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.shopping_cart_outlined),
                    )
                  : const Icon(Icons.shopping_cart_outlined),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () {
            final location = context.read<LocationProvider>();
            return context.read<VendorProvider>().reload(
                  refLat: location.referenceLat,
                  refLng: location.referenceLng,
                );
          },
          child: vendorProvider.isLoading && !vendorProvider.isLoaded
              ? const Center(child: CircularProgressIndicator())
              : _HomeBody(vendorProvider: vendorProvider, location: location),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  final VendorProvider vendorProvider;
  final LocationProvider location;
  const _HomeBody({required this.vendorProvider, required this.location});

  @override
  Widget build(BuildContext context) {
    final featured = vendorProvider.featuredFoodItems;
    final popular = vendorProvider.popularVendors;
    final nearby = vendorProvider.nearbyVendors(
      refLat: location.referenceLat,
      refLng: location.referenceLng,
      refBarangay: location.referenceBarangay,
    );

    return CustomScrollView(
      slivers: [
        if (vendorProvider.lastError != null && vendorProvider.allVendors.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Card(
                color: AppColors.danger.withValues(alpha: 0.06),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.wifi_off, color: AppColors.danger),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Couldn't reach the stores. Check your connection and try again.",
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => vendorProvider.reload(
                          refLat: location.referenceLat,
                          refLng: location.referenceLng,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search food or store name',
              ),
              onSubmitted: (_) => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const StoreListingScreen())),
              onChanged: vendorProvider.setSearch,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
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
        ),

        // --- Featured Foods ---
        if (featured.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SectionHeader(title: 'Featured Foods'),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: featured.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final food = featured[i];
                  final vendor = vendorProvider.vendorById(food.vendorId);
                  return FeaturedFoodCard(
                    food: food,
                    vendorName: vendor?.storeName ?? '',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => VendorProfileScreen(vendorId: food.vendorId)),
                    ),
                  );
                },
              ),
            ),
          ),
        ],

        // --- Popular Stores ---
        if (popular.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SectionHeader(title: 'Popular Stores'),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: popular.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final vendor = popular[i];
                  return VendorCardCompact(
                    vendor: vendor,
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => VendorProfileScreen(vendorId: vendor.id))),
                  );
                },
              ),
            ),
          ),
        ],

        // --- Nearby Stores ---
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Nearby Stores (${nearby.length})',
              actionLabel: 'See all',
              onAction: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StoreListingScreen())),
            ),
          ),
        ),
        if (nearby.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.storefront_outlined,
              title: vendorProvider.selectedCategory != null
                  ? "No stores in ${vendorProvider.selectedCategory}"
                  : 'No vendors match your filters',
              subtitle: 'Try clearing a filter or searching for something else.',
              action: OutlinedButton(
                onPressed: () => vendorProvider.clearFilters(),
                child: const Text('Clear filters'),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              itemCount: nearby.length > 4 ? 4 : nearby.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final entry = nearby[i];
                return VendorCard(
                  vendor: entry.key,
                  distanceKm: entry.value,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => VendorProfileScreen(vendorId: entry.key.id))),
                );
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
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
