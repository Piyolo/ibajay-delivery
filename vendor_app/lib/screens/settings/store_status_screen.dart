import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vendor.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';

class StoreStatusScreen extends StatelessWidget {
  const StoreStatusScreen({super.key});

  static const _options = [
    (status: StoreStatus.open, icon: Icons.check_circle_outline, color: AppColors.success),
    (status: StoreStatus.busy, icon: Icons.hourglass_bottom_outlined, color: AppColors.warning),
    (status: StoreStatus.paused, icon: Icons.pause_circle_outline, color: AppColors.info),
    (status: StoreStatus.closed, icon: Icons.block_outlined, color: AppColors.danger),
  ];

  @override
  Widget build(BuildContext context) {
    final vendorProvider = context.watch<VendorProvider>();
    final current = vendorProvider.vendor.status;

    return Scaffold(
      appBar: AppBar(title: const Text('Store Status')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Text(
              'Set how your store appears to customers right now. This overrides your operating hours until you change it back.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ..._options.map((opt) {
              final selected = opt.status == current;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  onTap: () => context.read<VendorProvider>().setStoreStatus(opt.status),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected ? opt.color.withValues(alpha: 0.08) : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: selected ? opt.color : AppColors.border, width: selected ? 1.5 : 1),
                    ),
                    child: Row(
                      children: [
                        Icon(opt.icon, color: opt.color, size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt.status.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: selected ? opt.color : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(opt.status.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (selected) Icon(Icons.check_circle, color: opt.color),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}