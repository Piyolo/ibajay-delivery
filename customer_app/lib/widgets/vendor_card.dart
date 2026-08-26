import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/vendor.dart';
import 'common.dart';

class VendorCard extends StatelessWidget {
  final VendorProfile vendor;
  final double? distanceKm;
  final VoidCallback onTap;

  const VendorCard({super.key, required this.vendor, this.distanceKm, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final settings = vendor.deliverySettings;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  RemoteImage(
                    url: vendor.logoUrl,
                    width: 84,
                    height: 84,
                    icon: Icons.storefront,
                    borderRadius: AppRadius.md,
                  ),
                  if (!vendor.isOpen)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Closed',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vendor.storeName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (vendor.isVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.verified, color: AppColors.info, size: 16),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        RatingStars(rating: vendor.rating),
                        const SizedBox(width: 8),
                        Text('(${vendor.totalReviews})',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (settings.deliveryEnabled) _tag('Delivery', Icons.two_wheeler),
                        if (settings.pickupEnabled) _tag('Pickup', Icons.storefront_outlined),
                        if (settings.scheduledDeliveryEnabled) _tag('Schedule', Icons.schedule),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('${settings.estimatedPrepMinutes} min',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        if (distanceKm != null) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.location_on, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 2),
                          Text('${distanceKm!.toStringAsFixed(1)} km',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
