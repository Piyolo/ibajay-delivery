import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vendor.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';

class OperatingHoursScreen extends StatefulWidget {
  const OperatingHoursScreen({super.key});

  @override
  State<OperatingHoursScreen> createState() => _OperatingHoursScreenState();
}

class _OperatingHoursScreenState extends State<OperatingHoursScreen> {
  late List<OperatingHours> _hours;

  @override
  void initState() {
    super.initState();
    final current = context.read<VendorProvider>().vendor.operatingHours;
    _hours = current
        .map((h) => OperatingHours(day: h.day, isOpen: h.isOpen, openTime: h.openTime, closeTime: h.closeTime))
        .toList();
  }

  void _save() {
    context.read<VendorProvider>().updateOperatingHours(_hours);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Operating hours saved')));
    Navigator.of(context).pop();
  }

  Future<void> _editTime(OperatingHours h, {required bool isOpenTime}) async {
    final parts = (isOpenTime ? h.openTime : h.closeTime).split(':');
    final initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isOpenTime) {
        h.openTime = formatted;
      } else {
        h.closeTime = formatted;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operating Hours'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: _hours.map((h) => _dayRow(h)).toList(),
        ),
      ),
    );
  }

  Widget _dayRow(OperatingHours h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(h.day, style: const TextStyle(fontWeight: FontWeight.w700))),
              Switch(value: h.isOpen, activeThumbColor: AppColors.primary, onChanged: (v) => setState(() => h.isOpen = v)),
            ],
          ),
          if (h.isOpen)
            Row(
              children: [
                _timeChip(h.openTime, () => _editTime(h, isOpenTime: true)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('to')),
                _timeChip(h.closeTime, () => _editTime(h, isOpenTime: false)),
              ],
            )
          else
            const Text('Closed', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _timeChip(String time, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Text(time, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}