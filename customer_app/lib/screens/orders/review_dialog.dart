import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/review.dart';
import '../../providers/order_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';

/// Shared rate-and-review dialog for delivered/completed orders
/// (`GET/POST /orders/{order_id}/review`).
///
/// Behaviour:
///  - Opens by checking whether the order already has a review; if it
///    does, the EXISTING review is shown (stars + comment) read-only.
///  - Otherwise the customer picks 1-5 stars, optionally comments, and
///    submits. A 409 (already reviewed — e.g. reviewed on another
///    device) is handled gracefully: the dialog reloads and displays the
///    stored review instead of erroring out.
Future<void> showOrderReviewDialog(
  BuildContext context, {
  required String orderId,
  String? vendorName,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _OrderReviewDialog(orderId: orderId, vendorName: vendorName),
  );
}

class _OrderReviewDialog extends StatefulWidget {
  final String orderId;
  final String? vendorName;
  const _OrderReviewDialog({required this.orderId, this.vendorName});

  @override
  State<_OrderReviewDialog> createState() => _OrderReviewDialogState();
}

class _OrderReviewDialogState extends State<_OrderReviewDialog> {
  /// Existing (or just-submitted) review — non-null switches the dialog
  /// into read-only display mode.
  OrderReviewView? _existing;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  int _stars = 5;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final review = await context.read<OrderProvider>().getReview(widget.orderId);
      if (!mounted) return;
      setState(() {
        _existing = review == null ? null : OrderReviewView.fromReview(review);
        _loading = false;
      });
    } catch (_) {
      // Unknown (offline/5xx): assume unreviewed — the server still
      // rejects duplicates with 409, which we handle on submit.
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final comment = _commentController.text;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final review = await context
          .read<OrderProvider>()
          .submitReview(widget.orderId, stars: _stars, comment: comment);
      if (!mounted) return;
      setState(() {
        _existing = OrderReviewView.fromReview(review);
        _submitting = false;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Thanks for your review!')));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        // Already reviewed (probably elsewhere) — show what's stored.
        messenger.showSnackBar(
            const SnackBar(content: Text('You already reviewed this order')));
        await _loadExisting();
        return;
      }
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not submit your review — please try again';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = _existing;
    return AlertDialog(
      title: Text(existing != null
          ? 'Your review'
          : 'Rate ${widget.vendorName ?? 'your order'}'),
      content: SingleChildScrollView(
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child:
                        SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            : existing != null
                ? _ExistingReview(review: existing)
                : _compose(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(existing != null ? 'Close' : 'Cancel'),
        ),
        if (existing == null)
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit Review'),
          ),
      ],
    );
  }

  Widget _compose() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 1; i <= 5; i++)
              IconButton(
                icon: Icon(
                  i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: AppColors.warning,
                  size: 34,
                ),
                onPressed: () => setState(() => _stars = i),
              ),
          ],
        ),
        TextField(
          controller: _commentController,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(hintText: 'Share your experience (optional)'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

/// Display view of a stored review (stars + comment + store reply).
class OrderReviewView {
  final int stars;
  final String comment;
  final String? vendorResponse;
  final DateTime createdAt;

  OrderReviewView({
    required this.stars,
    required this.comment,
    this.vendorResponse,
    required this.createdAt,
  });

  factory OrderReviewView.fromReview(OrderReview review) => OrderReviewView(
        stars: review.stars,
        comment: review.comment,
        vendorResponse: review.vendorResponse,
        createdAt: review.createdAt,
      );
}

class _ExistingReview extends StatelessWidget {
  final OrderReviewView review;
  const _ExistingReview({required this.review});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 1; i <= 5; i++)
              Icon(
                i <= review.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                color: AppColors.warning,
                size: 30,
              ),
          ],
        ),
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(review.comment, style: const TextStyle(fontSize: 14)),
        ],
        if (review.vendorResponse != null && review.vendorResponse!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              'Store reply: ${review.vendorResponse}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Reviewed on ${review.createdAt.toLocal().toString().split(' ').first}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
