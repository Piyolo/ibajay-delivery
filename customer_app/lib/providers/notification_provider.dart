import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/api_client.dart';

/// In-app notification center for order status updates (explicitly NOT
/// push/FCM — beta chose in-app notifications).
///
/// Backed by:
///  - `GET /notifications`            → newest-first list (cap 50)
///  - `POST /notifications/read-all`  → {"updated": n}
///
/// Wired like the other providers: constructed in main.dart with the
/// shared auth [ApiClient], loaded when a session becomes known, cleared
/// on sign-out. [OrderProvider] calls [refresh] whenever an order's
/// status changes so the bell badge is current without polling.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  List<AppNotification> _items = [];
  bool _isLoading = false;
  String? _userId;

  /// Error from the last failed load (UI display); null when healthy.
  String? lastError;

  List<AppNotification> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  int get unreadCount => _items.where((n) => !n.isRead).length;
  bool get hasUnread => unreadCount > 0;

  /// Binds the feed to an account and loads it. Called from the auth
  /// listener in main.dart.
  Future<void> attachUser(String uid) async {
    final changed = _userId != uid;
    _userId = uid;
    if (changed) {
      _items = [];
      lastError = null;
      notifyListeners();
    }
    await refresh();
  }

  /// Clears the feed on sign-out so the next account starts clean.
  void detachUser() {
    _userId = null;
    _items = [];
    lastError = null;
    notifyListeners();
  }

  /// Pulls the latest notifications (`GET /notifications`). Silent about
  /// errors after the first load so a background refresh never nukes an
  /// already-visible list with an error state.
  Future<void> refresh() async {
    if (_userId == null || _api.authToken == null || _isLoading) return;
    _isLoading = true;
    if (_items.isEmpty) notifyListeners();
    try {
      final data = await _api.get('/notifications') as List;
      _items = data
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      lastError = null;
    } on ApiException catch (e) {
      // Keep whatever is on screen; just record the failure.
      lastError = _items.isEmpty ? e.message : null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Marks everything read (`POST /notifications/read-all`) — clears the
  /// home-screen bell badge immediately, then reconciles with the server
  /// response.
  Future<void> markAllRead() async {
    if (_items.isEmpty || _userId == null || _api.authToken == null) return;
    final previous = _items;
    // Optimistic: the badge must clear the instant the user taps it.
    _items = [for (final n in previous) _copyRead(n)];
    notifyListeners();
    try {
      await _api.post('/notifications/read-all');
      lastError = null;
    } on ApiException catch (e) {
      _items = previous;
      lastError = e.message;
      notifyListeners();
    }
  }

  AppNotification _copyRead(AppNotification n) => AppNotification(
        id: n.id,
        title: n.title,
        body: n.body,
        type: n.type,
        relatedOrderId: n.relatedOrderId,
        isRead: true,
        createdAt: n.createdAt,
      );
}
