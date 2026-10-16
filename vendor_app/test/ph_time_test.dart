import 'package:flutter_test/flutter_test.dart';
import 'package:ibajay_eats_vendor/models/vendor.dart';

void main() {
  group('PH time helpers', () {
    test('phNow is the current time shifted to UTC+8', () {
      final before = DateTime.now().toUtc().add(const Duration(hours: 8));
      final ph = phNow();
      final after = DateTime.now().toUtc().add(const Duration(hours: 8));
      expect(!ph.isBefore(before) && !ph.isAfter(after), isTrue);
    });

    test('isSamePhDay compares PH calendar days, not instants', () {
      // Raw instants (device-local or UTC) — the helper shifts internally.
      expect(isSamePhDay(DateTime.now()), isTrue);
      // ±48h is always a different PH calendar day (PH has no DST).
      expect(isSamePhDay(DateTime.now().add(const Duration(hours: 48))), isFalse);
      expect(
          isSamePhDay(DateTime.now().subtract(const Duration(hours: 48))), isFalse);
    });
  });
}
