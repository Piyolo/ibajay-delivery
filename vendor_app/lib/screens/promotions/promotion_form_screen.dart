import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/promotion.dart';
import '../../providers/promotions_provider.dart';
import '../../theme/app_theme.dart';

class PromotionFormScreen extends StatefulWidget {
  const PromotionFormScreen({super.key});

  @override
  State<PromotionFormScreen> createState() => _PromotionFormScreenState();
}

class _PromotionFormScreenState extends State<PromotionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _value = TextEditingController();
  final _code = TextEditingController();
  final _minSubtotal = TextEditingController();
  String _discountType = 'percent';
  DateTime? _endsAt;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _value.dispose();
    _code.dispose();
    _minSubtotal.dispose();
    super.dispose();
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    setState(() => _endsAt = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final promo = StorePromotion(
      id: 'new',
      title: _title.text.trim(),
      description: _description.text.trim(),
      discountType: _discountType,
      discountValue: double.tryParse(_value.text) ?? 0,
      code: _code.text.trim().isEmpty ? null : _code.text.trim().toUpperCase(),
      minSubtotal: double.tryParse(_minSubtotal.text) ?? 0,
      endsAt: _endsAt,
    );

    final provider = context.read<PromotionsProvider>();
    final ok = await provider.create(promo);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Not saved — ${provider.lastError}')));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Promotion')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Title', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(hintText: 'e.g. Opening Week Discount'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                const Text('Description (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(controller: _description, maxLines: 2),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Discount', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _value,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: _discountType == 'percent' ? '20' : '50',
                              prefixText: _discountType == 'fixed' ? '₱ ' : null,
                              suffixText: _discountType == 'percent' ? '%' : null,
                            ),
                            validator: (v) =>
                                (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter a valid amount' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Type', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _discountType,
                            items: const [
                              DropdownMenuItem(value: 'percent', child: Text('% off')),
                              DropdownMenuItem(value: 'fixed', child: Text('₱ off')),
                            ],
                            onChanged: (v) => setState(() => _discountType = v ?? _discountType),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Promo Code (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Leave empty to auto-apply to every order',
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Minimum Spend (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _minSubtotal,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '0', prefixText: '₱ '),
                ),
                const SizedBox(height: 14),
                const Text('End Date (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: _pickEndDate,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(_endsAt == null
                      ? 'No end date'
                      : '${_endsAt!.year}/${_endsAt!.month}/${_endsAt!.day}'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create Promotion'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
