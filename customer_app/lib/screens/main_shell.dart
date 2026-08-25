import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/order_provider.dart';
import 'chat/chat_list_screen.dart';
import 'favorites/favorites_screen.dart';
import 'home/home_screen.dart';
import 'orders/order_history_screen.dart';
import 'settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    OrderHistoryScreen(),
    ChatListScreen(),
    FavoritesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final activeOrderCount = context.watch<OrderProvider>().activeOrders.length;
    final unreadChats = context.watch<ChatProvider>().threads.where((t) => t.unreadCount > 0).length;

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
            icon: _badgeIcon(Icons.receipt_long_outlined, activeOrderCount),
            selectedIcon: _badgeIcon(Icons.receipt_long, activeOrderCount),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: _badgeIcon(Icons.chat_bubble_outline, unreadChats),
            selectedIcon: _badgeIcon(Icons.chat_bubble, unreadChats),
            label: 'Chats',
          ),
          const NavigationDestination(
              icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Favorites'),
          const NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _badgeIcon(IconData icon, int count) {
    if (count == 0) return Icon(icon);
    return Badge(label: Text('$count'), child: Icon(icon));
  }
}
