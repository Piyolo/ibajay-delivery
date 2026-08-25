import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A lightweight, code-drawn hero graphic for the Welcome screen — echoes
/// the app logo's "bowl + delivery scooter" motif without needing a new
/// binary illustration asset. Kept simple and flat, consistent with the
/// rest of the app's restrained visual language.
class HeroIllustration extends StatelessWidget {
  final double size;
  const HeroIllustration({super.key, this.size = 220});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft backdrop blob
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: size * 0.72,
            height: size * 0.72,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
          ),
          // Food bowl, lower-left
          Positioned(
            left: size * 0.08,
            bottom: size * 0.18,
            child: _iconBadge(
              icon: Icons.ramen_dining_rounded,
              color: AppColors.secondary,
              diameter: size * 0.34,
            ),
          ),
          // Delivery scooter, upper-right — slightly larger, reads as "in motion"
          Positioned(
            right: size * 0.04,
            top: size * 0.14,
            child: _iconBadge(
              icon: Icons.two_wheeler_rounded,
              color: AppColors.primary,
              diameter: size * 0.40,
            ),
          ),
          // Small motion mark to suggest delivery speed
          Positioned(
            right: size * 0.30,
            top: size * 0.10,
            child: Icon(Icons.bolt_rounded, color: AppColors.warning, size: size * 0.14),
          ),
        ],
      ),
    );
  }

  Widget _iconBadge({required IconData icon, required Color color, required double diameter}) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Icon(icon, color: Colors.white, size: diameter * 0.5),
    );
  }
}
