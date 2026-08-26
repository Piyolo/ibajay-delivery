import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vendor.dart';
import '../../providers/cart_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../cart/cart_screen.dart';
import '../chat/chat_screen.dart';
import 'food_detail_sheet.dart';

class VendorProfileScreen extends StatelessWidget {
  final String vendorId;
  const VendorProfileScreen({super.key, required this.vendorId});

  @override
  Widget build(BuildContext context) {
    final vendorProvider = context.watch<VendorProvider>();
    final vendor = vendorProvider.vendorById(vendorId);
    if (vendor == null) {
      return const Scaffold(body: Center(child: Text('Vendor not found')));
    }

    final favorites = context.watch<FavoritesProvider>();
    final cart = context.watch<CartProvider>().cart;
    final customerBarangay = context.watch<LocationProvider>().referenceBarangay;
    final reviews = vendorProvider.reviewsFor(vendorId);

    final categories = <String>{'All', ...vendor.menu.map((f) => f.category).where((c) => c.isNotEmpty)};

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 190,
              pinned: true,
              actions: [
                IconButton(
                  icon: Icon(
                    favorites.isVendorFavorite(vendor.id) ? Icons.favorite : Icons.favorite_border,
                    color: favorites.isVendorFavorite(vendor.id) ? AppColors.danger : null,
                  ),
                  onPressed: () => favorites.toggleVendor(vendor.id),
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final thread =
                          await context.read<ChatProvider>().getOrCreateThread(vendor);
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ChatScreen(threadId: thread.id)));
                    } catch (_) {
                      messenger.showSnackBar(const SnackBar(
                          content: Text('Could not open the chat — try again')));
                    }
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    RemoteImage(url: vendor.bannerUrl, icon: Icons.storefront),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 12,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              vendor.storeName,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (vendor.isVerified) const Icon(Icons.verified, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        RatingStars(rating: vendor.rating),
                        const SizedBox(width: 8),
                        Text('(${vendor.totalReviews} reviews)',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (vendor.isOpen ? AppColors.success : AppColors.danger).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            vendor.isOpen ? 'Open' : 'Closed',
                            style: TextStyle(
                              color: vendor.isOpen ? AppColors.success : AppColors.danger,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (vendor.description.isNotEmpty)
                      Text(vendor.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    // Active promotions — coded promos are entered at
                    // checkout; uncoded ones apply automatically.
                    if (vendor.promotions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: vendor.promotions.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final promo = vendor.promotions[i];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_offer, size: 13, color: AppColors.primary),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      promo.code != null && promo.code!.isNotEmpty
                                          ? '${promo.discountLabel} · Code ${promo.code}'
                                          : '${promo.title} — ${promo.discountLabel}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(vendor.address,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (vendor.deliverySettings.deliveryEnabled) ...[
                          _infoTag(Icons.two_wheeler, 'Delivery ₱${vendor.deliverySettings.baseDeliveryFee.toStringAsFixed(0)}+'),
                          if (vendor.deliverySettings.hasDeliveryAreas)
                            _infoTag(
                              Icons.location_city_outlined,
                              _deliveryAreaLabel(vendor, customerBarangay),
                            ),
                        ],
                        if (vendor.deliverySettings.pickupEnabled) _infoTag(Icons.storefront_outlined, 'Pickup available'),
                        if (vendor.deliverySettings.scheduledDeliveryEnabled)
                          _infoTag(Icons.schedule, 'Schedule ahead'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                const TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  tabs: [Tab(text: 'Menu'), Tab(text: 'Reviews')],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _MenuTab(vendor: vendor, categories: categories.toList()),
              _ReviewsTab(vendor: vendor, reviews: reviews),
            ],
          ),
        ),
        bottomNavigationBar: cart.vendorId == vendor.id && !cart.isEmpty
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
                    child: Text('View Cart (${cart.itemCount}) · ₱${cart.subtotal.toStringAsFixed(0)}'),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  /// Delivery-area tag: highlights the customer's barangay when covered,
  /// otherwise shows how many areas the vendor serves.
  String _deliveryAreaLabel(VendorProfile vendor, String customerBarangay) {
    if (customerBarangay.isNotEmpty && vendor.deliverySettings.deliversToBarangay(customerBarangay)) {
      return 'Delivers to Brgy. $customerBarangay';
    }
    final count = vendor.deliverySettings.deliveryBarangays.length;
    return 'Delivers to $count barangay${count == 1 ? '' : 's'}';
  }

  Widget _infoTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _MenuTab extends StatefulWidget {
  final VendorProfile vendor;
  final List<String> categories;
  const _MenuTab({required this.vendor, required this.categories});

  @override
  State<_MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<_MenuTab> {
  String _activeCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final items = widget.vendor.menu
        .where((f) => _activeCategory == 'All' || f.category == _activeCategory)
        .toList();

    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: widget.categories
                .map((c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: _activeCategory == c,
                        onSelected: (_) => setState(() => _activeCategory = c),
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const EmptyState(
                  icon: Icons.restaurant_menu, title: 'No items here yet', subtitle: 'Check another category.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final food = items[i];
                    return _FoodTile(vendor: widget.vendor, food: food);
                  },
                ),
        ),
      ],
    );
  }
}

class _FoodTile extends StatelessWidget {
  final VendorProfile vendor;
  final FoodItemRef food;
  const _FoodTile({required this.vendor, required this.food});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: !food.isAvailable
            ? null
            : () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => FoodDetailSheet(vendor: vendor, food: food),
                ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                children: [
                  RemoteImage(
                    url: food.imageUrl,
                    width: 72,
                    height: 72,
                    icon: Icons.fastfood,
                    borderRadius: AppRadius.md,
                  ),
                  if (!food.isAvailable)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Sold Out',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    if (food.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(food.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                    const SizedBox(height: 6),
                    Text('₱${food.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ),
              ),
              if (food.isAvailable) const Icon(Icons.add_circle, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  final VendorProfile vendor;
  final List<dynamic> reviews;
  const _ReviewsTab({required this.vendor, required this.reviews});

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const EmptyState(
          icon: Icons.reviews_outlined, title: 'No reviews yet', subtitle: 'Be the first to review this store.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reviews.length,
      separatorBuilder: (_, __) => const Divider(height: 24),
      itemBuilder: (context, i) {
        final r = reviews[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(r.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Row(
                  children: List.generate(
                    5,
                    (idx) => Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: idx < r.stars ? AppColors.warning : AppColors.border,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(r.comment, style: const TextStyle(fontSize: 13)),
            if (r.vendorResponse != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.storefront, size: 14, color: AppColors.secondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(r.vendorResponse!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppColors.background, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
