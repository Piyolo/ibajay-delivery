import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vendor.dart';
import '../../providers/menu_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../analytics/analytics_screen.dart';
import '../settings/store_status_screen.dart';

/// Home tab — a quick-glance snapshot in the spirit of a Shopify/Stripe
/// admin home. Deep-dive charts live one tap away in AnalyticsScreen so
/// this screen stays fast to scan.
class DashboardScreen extends StatelessWidget {
  final ValueChanged<int>? onNavigateToTab;
  const DashboardScreen({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final vendor = context.watch<VendorProvider>().vendor;
    final orders = context.watch<OrderProvider>();
    final menu = context.watch<MenuProvider>();

    // The backend doesn't track per-item sold counts yet, so highlight
    // featured/first items instead of claiming fake sales numbers.
    final highlights = [
      ...menu.items.where((i) => i.isFeatured),
      ...menu.items.where((i) => !i.isFeatured),
    ];
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StoreStatusScreen()),
                ),
                child: _StoreStatusPill(status: vendor.status),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('$greeting, ${vendor.ownerName.split(' ').first} 👋',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(vendor.storeName, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _StatCard(
                  icon: Icons.receipt_long_outlined,
                  label: "Today's Orders",
                  value: '${orders.todaysOrders.length}',
                  color: AppColors.secondary,
                  onTap: () => onNavigateToTab?.call(1),
                ),
                _StatCard(
                  icon: Icons.payments_outlined,
                  label: "Today's Revenue",
                  value: '₱${orders.todaysRevenue.toStringAsFixed(0)}',
                  color: AppColors.primary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  ),
                ),
                _StatCard(
                  icon: Icons.pending_actions_outlined,
                  label: 'Pending Orders',
                  value: '${orders.pendingCount}',
                  color: AppColors.warning,
                  badge: orders.pendingCount > 0,
                  onTap: () => onNavigateToTab?.call(1),
                ),
                // No reviews yet → no rating to show; menu size is real.
                _StatCard(
                  icon: vendor.totalReviews > 0 ? Icons.star_outline : Icons.restaurant_menu_outlined,
                  label: vendor.totalReviews > 0 ? 'Store Rating' : 'Menu Items',
                  value: vendor.totalReviews > 0
                      ? vendor.rating.toStringAsFixed(1)
                      : '${menu.items.length}',
                  color: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SectionHeader(
              title: 'Menu Highlights',
              actionLabel: 'Full Analytics',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
              ),
            ),
            ...highlights.take(3).map(
                  (item) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.surfaceMuted,
                        child: item.imageUrl.isNotEmpty
                            ? ClipOval(
                                child: Image.network(item.imageUrl,
                                    fit: BoxFit.cover,
                                    width: 40,
                                    height: 40,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.fastfood_outlined,
                                            color: AppColors.textSecondary)),
                              )
                            : const Icon(Icons.fastfood_outlined, color: AppColors.textSecondary),
                      ),
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('₱${item.price.toStringAsFixed(0)}'),
                      trailing: item.isFeatured
                          ? const Icon(Icons.star_rounded, color: AppColors.warning)
                          : null,
                    ),
                  ),
                ),
            const SizedBox(height: 8),
            if (orders.newOrders.isNotEmpty) ...[
              SectionHeader(
                title: 'Needs Your Attention',
                actionLabel: 'View All',
                onAction: () => onNavigateToTab?.call(1),
              ),
              Card(
                color: AppColors.warning.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined, color: AppColors.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${orders.newOrders.length} new order${orders.newOrders.length > 1 ? 's' : ''} waiting for a response',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(onPressed: () => onNavigateToTab?.call(1), child: const Text('Review')),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool badge;
  final VoidCallback? onTap;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.badge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  if (badge) ...[
                    const Spacer(),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle)),
                  ],
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreStatusPill extends StatelessWidget {
  final StoreStatus status;
  const _StoreStatusPill({required this.status});

  Color get _color {
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: _color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(status.label, style: TextStyle(color: _color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}