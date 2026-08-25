import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_preferences_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../auth/landing_screen.dart';
import 'account_settings_screen.dart';
import 'addresses_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final prefs = context.watch<AppPreferencesProvider>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      (user?.fullName.isNotEmpty ?? false) ? user!.fullName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.fullName ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(user?.mobileNumber ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                        Text(user?.email ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel('Account'),
          _tile(Icons.manage_accounts_outlined, 'Account Settings',
              subtitle: 'Name, email, mobile & password',
              onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
                  )),
          _tile(Icons.location_on_outlined, 'Manage Addresses',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddressesScreen()))),
          const SizedBox(height: 20),
          _sectionLabel('Notification Preferences'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Order Updates'),
            value: prefs.orderNotifs,
            onChanged: (v) => context.read<AppPreferencesProvider>().setOrderNotifs(v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Chat Messages'),
            value: prefs.chatNotifs,
            onChanged: (v) => context.read<AppPreferencesProvider>().setChatNotifs(v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Promotions'),
            value: prefs.promoNotifs,
            onChanged: (v) => context.read<AppPreferencesProvider>().setPromoNotifs(v),
          ),
          const SizedBox(height: 12),
          _sectionLabel('Privacy'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Share Live Location During Delivery'),
            value: prefs.shareLocation,
            onChanged: (v) => context.read<AppPreferencesProvider>().setShareLocation(v),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () {
                context.read<AuthProvider>().signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LandingScreen()),
                  (route) => false,
                );
              },
              child: const Text('Sign Out'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 13)),
      );

  Widget _tile(IconData icon, String label, {String? subtitle, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(label),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
