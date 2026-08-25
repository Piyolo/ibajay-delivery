import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../location/location_setup_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionItem {
  final IconData icon;
  final String title;
  final String purpose;
  final bool required;
  bool granted;

  _PermissionItem({
    required this.icon,
    required this.title,
    required this.purpose,
    required this.required,
    this.granted = false,
  });
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final List<_PermissionItem> _permissions = [
    _PermissionItem(
      icon: Icons.location_on,
      title: 'Location',
      purpose: 'Delivery address, nearby stores, and order tracking',
      required: true,
    ),
    _PermissionItem(
      icon: Icons.notifications_active,
      title: 'Notifications',
      purpose: 'Order updates, chat messages, and promotions',
      required: true,
    ),
    _PermissionItem(
      icon: Icons.wifi,
      title: 'Internet Access',
      purpose: 'Required for the app to function',
      required: true,
      granted: true,
    ),
    _PermissionItem(
      icon: Icons.phone,
      title: 'Phone Access',
      purpose: 'Optional — lets you call a vendor directly',
      required: false,
    ),
  ];

  bool get _allRequiredGranted => _permissions.where((p) => p.required).every((p) => p.granted);

  void _grant(_PermissionItem item) {
    // In production this triggers the native permission_handler / geolocator
    // prompts. Here we just flip local state so the flow is fully testable.
    setState(() => item.granted = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A few things we need',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'These permissions let Ibajay Eats find nearby stores and keep you updated on your orders.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: _permissions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final item = _permissions[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Icon(item.icon, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 6),
                                      if (item.required)
                                        Text('· Required',
                                            style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 11)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(item.purpose,
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                            item.granted
                                ? const Icon(Icons.check_circle, color: AppColors.success)
                                : TextButton(
                                    onPressed: () => _grant(item),
                                    child: const Text('Allow'),
                                  ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _allRequiredGranted
                      ? () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const LocationSetupScreen()))
                      : null,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
