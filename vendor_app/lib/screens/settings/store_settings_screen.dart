import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vendor.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';
import '../promotions/promotions_screen.dart';
import 'account_center_screen.dart';
import 'categories_screen.dart';
import 'delivery_settings_screen.dart';
import 'operating_hours_screen.dart';
import 'store_profile_screen.dart';
import 'store_reviews_screen.dart';
import 'store_status_screen.dart';

class StoreSettingsScreen extends StatelessWidget {
  const StoreSettingsScreen({super.key});

  Color _statusColor(StoreStatus status) {
    switch (status) {
      case StoreStatus.open:
        return AppColors.success;
      case StoreStatus.busy:
        return AppColors.warning;
      case StoreStatus.paused:
        return AppColors.info;
      case StoreStatus.closed:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorProvider = context.watch<VendorProvider>();
    final vendor = vendorProvider.vendor;
    final statusColor = _statusColor(vendor.status);

    return Scaffold(
      appBar: AppBar(title: const Text('Store')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StoreProfileScreen()),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      vendor.storeName.isNotEmpty ? vendor.storeName[0] : '?',
                      style: const TextStyle(fontSize: 24, color: AppColors.primary, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(vendor.storeName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (vendor.isVerified) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, size: 16, color: AppColors.secondary),
                            ],
                          ],
                        ),
                        // Only show a rating once customers have actually
                        // left reviews.
                        if (vendor.totalReviews > 0)
                          Text('${vendor.rating} ★  (${vendor.totalReviews} reviews)',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StoreStatusScreen()),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Store Status', style: TextStyle(fontWeight: FontWeight.w700)),
                            Text(
                              '${vendor.status.label} — ${vendor.status.description}',
                              style: TextStyle(fontSize: 12, color: statusColor),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Store Management'),
            _settingsTile(
              context,
              Icons.storefront_outlined,
              'Store Profile',
              'Logo, banner, description, contact',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StoreProfileScreen())),
            ),
            _settingsTile(
              context,
              Icons.schedule_outlined,
              'Operating Hours',
              'Set your weekly schedule',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OperatingHoursScreen())),
            ),
            _settingsTile(
              context,
              Icons.local_shipping_outlined,
              'Delivery Settings',
              'Delivery areas (barangays), pickup & fees',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeliverySettingsScreen())),
            ),
            _settingsTile(
              context,
              Icons.category_outlined,
              'Store Categories',
              vendor.categories.isEmpty ? 'Not set' : vendor.categories.join(', '),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesScreen())),
            ),
            _settingsTile(
              context,
              Icons.local_offer_outlined,
              'Promotions',
              'Discounts and promo codes for your store',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PromotionsScreen())),
            ),
            _settingsTile(
              context,
              Icons.rate_review_outlined,
              'Customer Reviews',
              vendor.totalReviews > 0
                  ? '${vendor.rating.toStringAsFixed(1)} ★ from ${vendor.totalReviews} reviews'
                  : 'No reviews yet',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StoreReviewsScreen())),
            ),
            const SizedBox(height: 12),
            const SectionHeader(title: 'Account'),
            _settingsTile(
              context,
              Icons.manage_accounts_outlined,
              'Account Settings',
              'Owner name, email, mobile & password',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountCenterScreen())),
            ),
            const SizedBox(height: 12),
            const SectionHeader(title: 'Support'),
            _settingsTile(
              context,
              Icons.pause_circle_outlined,
              'Pause Store Temporarily',
              'Emergency store pause',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StoreStatusScreen())),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                vendorProvider.signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout, color: AppColors.danger),
              label: const Text('Log Out', style: TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle, {
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle.isNotEmpty
            ? Text(subtitle, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}