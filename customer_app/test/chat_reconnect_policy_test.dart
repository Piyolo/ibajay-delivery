import 'package:flutter_test/flutter_test.dart';
import 'package:ibajay_eats/providers/chat_provider.dart';

/// The chat WebSocket reconnect policy is deliberately bounded: at most
/// [ChatProvider.maxReconnectAttempts] tries, [ChatProvider.reconnectDelay]
/// apart, and only while the thread is intended-open (the Timer itself is
/// owned by ChatProvider and cancelled on disconnect/reset — not
/// unit-testable without a real socket, so the schedule math is what we
/// pin down here).
void main() {
  test('reconnect attempts are bounded at 3, 5s apart', () {
    expect(ChatProvider.maxReconnectAttempts, 3);
    expect(ChatProvider.reconnectDelay, const Duration(seconds: 5));
  });

  test('shouldReconnect allows retries only under the cap', () {
    expect(ChatProvider.shouldReconnect(0), isTrue,
        reason: 'first drop always earns a retry');
    expect(ChatProvider.shouldReconnect(2), isTrue,
        reason: 'the 3rd attempt is still allowed');
    expect(ChatProvider.shouldReconnect(3), isFalse,
        reason: 'attempts are exhausted at the cap');
    expect(ChatProvider.shouldReconnect(99), isFalse);
  });
}
