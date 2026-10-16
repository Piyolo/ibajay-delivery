import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ibajay_eats_vendor/models/vendor.dart';
import 'package:ibajay_eats_vendor/providers/vendor_provider.dart';
import 'package:ibajay_eats_vendor/screens/settings/account_center_screen.dart';
import 'package:ibajay_eats_vendor/screens/settings/store_profile_screen.dart';

class FakeVendorProvider extends ChangeNotifier implements VendorProvider {
  final VendorProfile _customVendor;
  FakeVendorProvider(this._customVendor);

  @override
  VendorProfile get vendor => _customVendor;

  @override
  String? get lastError => null;

  @override
  String? get lastAuthError => null;

  @override
  Future<void> updateProfile({
    String? ownerName,
    String? storeName,
    String? description,
    String? address,
    String? contactNumber,
    String? logoUrl,
    String? bannerUrl,
  }) async {}

  @override
  Future<bool> verifyPassword(String currentPassword) async => true;

  @override
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => true;

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late VendorProfile mockVendor;

  setUp(() {
    mockVendor = VendorProfile(
      id: 'v-123',
      ownerName: 'Juan Dela Cruz',
      storeName: 'Juan Bakery',
      description: 'Fresh bread daily',
      mobileNumber: '09123456789',
      email: 'juan@example.com',
      address: 'Poblacion, Ibajay',
      latitude: 11.8167,
      longitude: 122.1667,
      logoUrl: '',
      bannerUrl: '',
    );
  });

  Widget buildTestableWidget(Widget child, VendorProvider provider) {
    return MaterialApp(
      home: ChangeNotifierProvider<VendorProvider>.value(
        value: provider,
        child: child,
      ),
    );
  }

  group('AccountCenterScreen Dialog Lifecycle Tests', () {
    testWidgets('Owner Name dialog cancel does not throw disposed controller error', (tester) async {
      final provider = FakeVendorProvider(mockVendor);
      await tester.pumpWidget(buildTestableWidget(const AccountCenterScreen(), provider));
      await tester.pumpAndSettle();

      // Tap the Owner Name tile
      expect(find.text('Owner Name'), findsOneWidget);
      await tester.tap(find.text('Owner Name'));
      await tester.pumpAndSettle();

      // Dialog is open with the current value
      expect(find.text('Full name'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Enter new text
      await tester.enterText(find.byType(TextField), 'Updated Owner Name');
      await tester.pump();

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));

      // Wait for exit animation to settle - if controller was used after dispose, this throws
      await tester.pumpAndSettle();

      // Dialog is dismissed and Account Settings is visible
      expect(find.text('Full name'), findsNothing);
      expect(find.text('Account Settings'), findsOneWidget);
    });

    testWidgets('Email Address row is read-only — no edit dialog opens', (tester) async {
      final provider = FakeVendorProvider(mockVendor);
      await tester.pumpWidget(buildTestableWidget(const AccountCenterScreen(), provider));
      await tester.pumpAndSettle();

      // The row explains why it can't be edited instead of faking a save.
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Contact support to change your email'), findsOneWidget);

      // Tapping the row must not open an edit dialog.
      await tester.tap(find.text('Email Address'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Email'), findsNothing);
    });

    testWidgets('Mobile Number row is read-only — no edit dialog opens', (tester) async {
      final provider = FakeVendorProvider(mockVendor);
      await tester.pumpWidget(buildTestableWidget(const AccountCenterScreen(), provider));
      await tester.pumpAndSettle();

      expect(find.text('Mobile Number'), findsOneWidget);
      expect(find.text('Contact support to change your mobile number'), findsOneWidget);

      await tester.tap(find.text('Mobile Number'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Mobile number'), findsNothing);
    });

    testWidgets('Change Password dialog cancel does not throw disposed error', (tester) async {
      final provider = FakeVendorProvider(mockVendor);
      await tester.pumpWidget(buildTestableWidget(const AccountCenterScreen(), provider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change Password'));
      await tester.pumpAndSettle();

      expect(find.text('Current password'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'oldpassword123');
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Current password'), findsNothing);
      expect(find.text('Account Settings'), findsOneWidget);
    });
  });

  group('StoreProfileScreen Layout & Clip Tests', () {
    testWidgets('Banner Stack uses Clip.none and circular avatar renders', (tester) async {
      final provider = FakeVendorProvider(mockVendor);
      await tester.pumpWidget(buildTestableWidget(const StoreProfileScreen(), provider));
      await tester.pumpAndSettle();

      // Find Stack in StoreProfileScreen
      final stackFinder = find.byType(Stack);
      expect(stackFinder, findsWidgets);

      final stackWidget = tester.widget<Stack>(stackFinder.first);
      // Verify that clipBehavior is Clip.none
      expect(stackWidget.clipBehavior, equals(Clip.none));

      // Verify store name and info are present
      expect(find.text('Store Name'), findsOneWidget);
      expect(find.text('Juan Bakery'), findsOneWidget);
      expect(find.text('Poblacion, Ibajay'), findsOneWidget);
    });
  });
}
