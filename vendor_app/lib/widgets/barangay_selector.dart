import 'package:flutter/material.dart';

import '../models/vendor.dart';
import '../theme/app_theme.dart';

/// Shared barangay picker for delivery areas: search + All/None buttons +
/// checkbox list. Used by BOTH the store-setup wizard's delivery step and
/// the logged-in Delivery Settings screen so setup gets the same UX as the
/// settings screen (the old setup step was a bare chip wrap with no search
/// and no select-all/none).
class BarangaySelector extends StatefulWidget {
  final String title;
  final String? description;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const BarangaySelector({
    super.key,
    this.title = 'Delivery Areas',
    this.description,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<BarangaySelector> createState() => _BarangaySelectorState();
}

class _BarangaySelectorState extends State<BarangaySelector> {
  String _search = '';

  List<String> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return kIbajayBarangays;
    return kIbajayBarangays.where((b) => b.toLowerCase().contains(q)).toList();
  }

  void _toggle(String b) {
    final next = [...widget.selected];
    next.contains(b) ? next.remove(b) : next.add(b);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Text(
              '${widget.selected.length} of ${kIbajayBarangays.length} barangays selected',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        if (widget.description != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.description!,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: 'Search barangay',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => widget.onChanged([...kIbajayBarangays]),
              child: const Text('All'),
            ),
            TextButton(
              onPressed: () => widget.onChanged([]),
              child: const Text('None'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ..._filtered.map(_barangayTile),
        if (_filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No barangays match your search.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _barangayTile(String b) {
    final selected = widget.selected.contains(b);
    return CheckboxListTile(
      value: selected,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(b, style: const TextStyle(fontSize: 14)),
      activeColor: AppColors.primary,
      onChanged: (_) => _toggle(b),
    );
  }
}
