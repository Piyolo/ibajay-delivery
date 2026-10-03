import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/vendor_provider.dart';
import '../../services/vendor_api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Read-only view of the store's legitimate customer reviews
/// (GET /vendors/{id}/reviews). Every review comes from a real completed
/// order — there is nothing to fabricate here.
class StoreReviewsScreen extends StatefulWidget {
  const StoreReviewsScreen({super.key});

  @override
  State<StoreReviewsScreen> createState() => _StoreReviewsScreenState();
}

class _StoreReviewsScreenState extends State<StoreReviewsScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    final vendorId = context.read<VendorProvider>().vendor.id;
    final service = VendorApiService(context.read<VendorProvider>().client);
    _future = vendorId.isEmpty ? Future.value([]) : service.getStoreReviews(vendorId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: EmptyState(
                  icon: Icons.rate_review_outlined,
                  title: 'Could not load reviews',
                  subtitle: snap.error?.toString() ?? 'Please try again.',
                ),
              );
            }
            final reviews = snap.data ?? [];
            if (reviews.isEmpty) {
              // Vertically centered so a first-time vendor lands on a
              // balanced screen rather than text stuck under the AppBar.
              return const Center(
                child: EmptyState(
                  icon: Icons.rate_review_outlined,
                  title: 'No reviews yet',
                  subtitle:
                      'Customers can review your store after their order is delivered. Reviews will appear here.',
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: reviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = reviews[i] as Map<String, dynamic>;
                final stars = (r['stars'] as num?)?.toInt() ?? 0;
                final name = r['customer_name'] as String? ?? 'Customer';
                final comment = r['comment'] as String?;
                final response = r['vendor_response'] as String?;
                final createdAt =
                    DateTime.tryParse(r['created_at'] as String? ?? '')?.toLocal();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '★' * stars + '☆' * (5 - stars),
                              style: const TextStyle(
                                  color: AppColors.warning, fontSize: 15, letterSpacing: 2),
                            ),
                            const Spacer(),
                            if (createdAt != null)
                              Text(DateFormat('MMM d, yyyy').format(createdAt),
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        if (comment != null && comment.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(comment, style: const TextStyle(fontSize: 13)),
                        ],
                        if (response != null && response.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text('Your response: $response',
                                style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
