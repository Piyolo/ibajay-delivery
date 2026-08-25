import 'package:flutter/material.dart';
import '../models/vendor.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Fixed-width card for horizontal carousels (e.g. "Popular Stores").
/// For vertical browsable lists, use [VendorCard] instead.
class VendorCardCompact extends StatelessWidget {
  final VendorProfile vendor;
  final VoidCallback onTap;
  const VendorCardCompact({super.key, required this.vendor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: const PlaceholderImage(
                        width: double.infinity,
                        height: 90,
                        icon: Icons.storefront,
                      ),
                    ),
                    if (!vendor.isOpen)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          alignment: Alignment.center,
                          child: const Text('Closed',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    if (vendor.isVerified)
                      const Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(Icons.verified, color: AppColors.info, size: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  vendor.storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 4),
                RatingStars(rating: vendor.rating, size: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
