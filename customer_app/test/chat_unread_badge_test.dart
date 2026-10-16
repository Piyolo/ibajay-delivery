import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ibajay_eats/providers/chat_provider.dart';
import 'package:ibajay_eats/services/api_client.dart';

/// Startup unread badges: GET /chats/my rows carry `unread_count`, which
/// is what the bottom-nav badge derives for threads the user never opened
/// (their message list is empty until a chat screen loads history). Once
/// a thread HAS messages, the messages-derived count wins — it is the
/// live truth kept fresh by history loads and the WebSocket.
void main() {
  Map<String, dynamic> threadJson(
    String id, {
    int? unreadCount,
    List<Map<String, dynamic>>? messages,
  }) =>
      {
        'id': id,
        'vendor_id': 'vendor-$id',
        'vendor_name': 'Store $id',
        'vendor_logo_url': null,
        'order_id': null,
        'last_message': 'hello',
        'last_message_at': '2026-10-16T10:00:00Z',
        'message_count': messages?.length ?? 0,
        if (unreadCount != null) 'unread_count': unreadCount,
        if (messages != null) 'messages': messages,
      };

  Map<String, dynamic> messageJson(String id, {required bool read}) => {
        'id': id,
        'sender_id': 'vendor-user',
        'content': 'hi',
        'image_url': null,
        'is_read': read,
        'created_at': '2026-10-16T10:00:00Z',
      };

  ChatProvider providerServing(List<Map<String, dynamic>> rows) {
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/chats/my')) {
        return http.Response(jsonEncode(rows), 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{"detail": "not found"}', 404);
    });
    return ChatProvider(
        apiClient: ApiClient(client: mock, baseUrl: 'https://test.local'));
  }

  test('loadThreads() populates badges from unread_count for unopened threads',
      () async {
    SharedPreferences.setMockInitialValues({});
    final provider = providerServing([
      threadJson('a', unreadCount: 3),
      threadJson('b', unreadCount: 0),
      // Row missing the key entirely — must degrade to 0, not crash.
      threadJson('c'),
    ]);

    await provider.loadThreads();

    expect(provider.threads, hasLength(3));
    final byId = {for (final t in provider.threads) t.id: t};
    expect(byId['a']!.unreadCount, 3,
        reason: 'never-opened thread derives from the server field');
    expect(byId['b']!.unreadCount, 0);
    expect(byId['c']!.unreadCount, 0,
        reason: 'absent unread_count parses to null -> 0');

    // Same derivation the bottom nav uses (main_shell.dart).
    final badgeCount =
        provider.threads.where((t) => t.unreadCount > 0).length;
    expect(badgeCount, 1);
  });

  test('a thread that carries messages prefers the messages-derived count',
      () async {
    SharedPreferences.setMockInitialValues({});
    // The server says 5 unread, but the payload ALSO carries messages
    // (open/merged thread) — live message state wins over the summary.
    final provider = providerServing([
      threadJson('a', unreadCount: 5, messages: [
        messageJson('m1', read: false), // unread, other side
        messageJson('m2', read: false), // unread, other side
        messageJson('m3', read: true),
        {
          'id': 'm4',
          'sender_id': 'me',
          'content': 'outgoing',
          'image_url': null,
          'is_read': false, // my own unread message never counts
          'created_at': '2026-10-16T10:00:00Z',
        },
      ]),
    ]);

    await provider.loadThreads();

    final thread = provider.threadById('a')!;
    expect(thread.serverUnreadCount, 5);
    expect(thread.unreadCount, 2,
        reason: 'non-empty messages override the server summary');
  });

  test('markThreadRead flips a server-counted thread to 0 once opened',
      () async {
    SharedPreferences.setMockInitialValues({});
    final provider = providerServing([
      threadJson('a', unreadCount: 4, messages: [
        messageJson('m1', read: false),
        messageJson('m2', read: false),
      ]),
    ]);

    await provider.loadThreads();
    // Two unread messages shipped in the payload — the messages branch
    // is live now and reports 2, not the stale server summary of 4.
    expect(provider.threadById('a')!.unreadCount, 2);

    provider.markThreadRead('a');
    expect(provider.threadById('a')!.unreadCount, 0,
        reason: 'opening the thread must clear the badge');
  });

  test('a /chats/my reply landing after reset() is discarded (cross-account)',
      () async {
    SharedPreferences.setMockInitialValues({});
    // The reply only lands once we release it — standing in for a slow
    // network response that outlives the session it was fetched for.
    final gate = Completer<http.Response>();
    final mock = MockClient((request) {
      if (request.url.path.endsWith('/chats/my')) return gate.future;
      return Future.value(http.Response('{"detail": "not found"}', 404));
    });
    final provider = ChatProvider(
        apiClient: ApiClient(client: mock, baseUrl: 'https://test.local'));

    final inFlight = provider.loadThreads(); // previous account's fetch
    await provider.reset(); // sign-out lands BEFORE the reply
    gate.complete(http.Response(
      jsonEncode([
        threadJson('stale-a', unreadCount: 3),
        threadJson('stale-b', unreadCount: 1),
      ]),
      200,
      headers: {'content-type': 'application/json'},
    ));
    await inFlight;

    expect(provider.threads, isEmpty,
        reason: 'rows fetched for the signed-out account must not repopulate');
    expect(provider.isLoading, isFalse,
        reason: 'the loading flag must still reset on the discard path');
  });
}
