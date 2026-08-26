import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/promotion.dart';
import '../../providers/promotions_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'promotion_form_screen.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PromotionsProvider>().load();
    });
  }

  Future<void> _confirmDelete(StorePromotion promo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete promotion?'),
        content: Text('"${promo.title}" will no longer be available to customers.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<PromotionsProvider>();
    await provider.delete(promo.id);
    if (!mounted) return;
    if (provider.lastError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Not deleted — ${provider.lastError}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PromotionsProvider>();
    final promos = provider.promotions;

    return Scaffold(
      appBar: AppBar(title: const Text('Promotions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PromotionFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Promo'),
      ),
      body: SafeArea(
        child: provider.isLoading && promos.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : promos.isEmpty
                ? const EmptyState(
                    icon: Icons.local_offer_outlined,
                    title: 'No promotions yet',
                    subtitle:
                        'Create discounts or promo codes to bring customers in. They appear on your storefront automatically.',
                  )
                : RefreshIndicator(
                    onRefresh: () => provider.load(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: promos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final p = promos[i];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(p.title,
                                                style: const TextStyle(fontWeight: FontWeight.w700),
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(AppRadius.pill),
                                            ),
                                            child: Text(p.discountLabel,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        [
                                          if (p.code != null && p.code!.isNotEmpty) 'Code: ${p.code}',
                                          if (p.minSubtotal > 0) 'Min spend ₱${p.minSubtotal.toStringAsFixed(0)}',
                                          if (p.endsAt != null) 'Until ${_fmt(p.endsAt!)}',
                                          '${p.timesUsed} used',
                                        ].join(' · '),
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (!p.isActive || _expired(p)) ...[
                                        const SizedBox(height: 4),
                                        Text(_expired(p) ? 'Expired' : 'Inactive',
                                            style: const TextStyle(color: AppColors.danger, fontSize: 11)),
                                      ],
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: p.isActive && !_expired(p),
                                  activeThumbColor: AppColors.primary,
                                  onChanged: _expired(p)
                                      ? null
                                      : (v) => provider.toggleActive(p, v),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                                  onPressed: () => _confirmDelete(p),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  bool _expired(StorePromotion p) =>
      p.endsAt != null && DateTime.now().isAfter(p.endsAt!);

  String _fmt(DateTime d) =>
      '${d.year}/${d.month}/${d.day}';
}
