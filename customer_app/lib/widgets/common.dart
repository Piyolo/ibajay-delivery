import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!, style: const TextStyle(color: AppColors.primary)),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Placeholder image box used wherever a real network image (Cloudinary URL)
/// would render — keeps the UI fully functional without real assets.
class PlaceholderImage extends StatelessWidget {
  final double? width;
  final double? height;
  final IconData icon;
  final double? iconSize;
  final double borderRadius;
  const PlaceholderImage({
    super.key,
    this.width,
    this.height,
    this.icon = Icons.restaurant,
    this.iconSize,
    this.borderRadius = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(icon, color: AppColors.textSecondary.withValues(alpha: 0.4), size: iconSize ?? (height ?? 48) * 0.4),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
            )
          : Text(label),
    );
  }
}

class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  const RatingStars({super.key, required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: AppColors.warning, size: size),
        const SizedBox(width: 2),
        Text(rating.toStringAsFixed(1), style: TextStyle(fontSize: size * 0.85, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
