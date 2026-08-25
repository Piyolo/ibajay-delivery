import 'package:flutter/material.dart';
import '../models/vendor.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class FeaturedFoodCard extends StatelessWidget {
  final FoodItemRef food;
  final String vendorName;
  final VoidCallback onTap;
  const FeaturedFoodCard({super.key, required this.food, required this.vendorName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 158,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: const PlaceholderImage(
                      width: double.infinity,
                      icon: Icons.fastfood,
                      iconSize: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  food.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  vendorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  '₱${food.price.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 13.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
