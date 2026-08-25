import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/vendor_card.dart';
import '../vendor/vendor_profile_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    final favoriteVendors = context
        .watch<VendorProvider>()
        .allVendors
        .where((v) => favorites.isVendorFavorite(v.id))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: favoriteVendors.isEmpty
          ? const EmptyState(
              icon: Icons.favorite_border,
              title: 'No favorites yet',
              subtitle: 'Tap the heart icon on a store to save it here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: favoriteVendors.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final vendor = favoriteVendors[i];
                return VendorCard(
                  vendor: vendor,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => VendorProfileScreen(vendorId: vendor.id))),
                );
              },
            ),
    );
  }
}
