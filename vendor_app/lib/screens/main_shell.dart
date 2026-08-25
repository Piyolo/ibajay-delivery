import 'package:flutter/material.dart';
import 'dashboard/dashboard_screen.dart';
import 'orders/orders_dashboard_screen.dart';
import 'menu/menu_screen.dart';
import 'chat/chat_list_screen.dart';
import 'settings/store_settings_screen.dart';
import '../theme/app_theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _goToTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onNavigateToTab: _goToTab),
      const OrdersDashboardScreen(),
      const MenuScreen(),
      const ChatListScreen(),
      const StoreSettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goToTab,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: AppColors.primary), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long, color: AppColors.primary), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu, color: AppColors.primary), label: 'Menu'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble, color: AppColors.primary), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront, color: AppColors.primary), label: 'Store'),
        ],
      ),
    );
  }
}