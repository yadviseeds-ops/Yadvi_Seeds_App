import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/features/admin/main_scaffold.dart';
import 'package:unified_app/features/admin/profile/admin_profile_screen.dart';
import 'package:unified_app/providers/admin_provider.dart';
import 'package:unified_app/providers/auth_provider.dart';
import 'package:unified_app/core/auth/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Profile & Settings — Widget and Flow Tests', () {
    testWidgets(
        'AdminMainScaffold Settings gear icon navigates to AdminProfileScreen and does not show server config dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AdminProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(
            home: AdminMainScaffold(),
          ),
        ),
      );

      // Verify the Settings gear button exists with the new user-friendly tooltip
      final settingsBtn = find.byTooltip('Admin Settings & Profile');
      expect(settingsBtn, findsOneWidget);

      // Ensure the old technical tooltip is not present
      expect(find.byTooltip('Server Settings'), findsNothing);

      // Tap settings button and pump navigation frame
      await tester.tap(settingsBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify AdminProfileScreen opened
      expect(find.text('Admin Profile & Settings'), findsOneWidget);

      // Verify the old technical dialog and technical Base URL fields are NOT shown
      expect(find.text('Backend Server Configuration'), findsNothing);
      expect(find.text('Active backend base URL:'), findsNothing);
      expect(find.text('Save & Reconnect'), findsNothing);
      expect(find.text('Reset Default'), findsNothing);
    });

    testWidgets('AdminProfileScreen displays initial loading state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(
            home: AdminProfileScreen(),
          ),
        ),
      );

      // Verify initial loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading administrator profile...'), findsOneWidget);
    });

    testWidgets(
        'AdminProfileScreen correctly displays loaded profile details and handles edit mode toggle & validation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockProfile = {
        'id': 1,
        'full_name': 'Ramesh Kumar',
        'username': 'ADMIN',
        'phone': '9529403798',
        'email': 'admin@yadvi.com',
        'role': 'administrator',
        'is_active': true,
      };

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: MaterialApp(
            home: AdminProfileScreen(initialProfile: mockProfile),
          ),
        ),
      );

      // Settle widget tree
      await tester.pump();

      // 1. Verify Profile Display
      expect(find.text('Admin Profile & Settings'), findsOneWidget);
      expect(find.text('Ramesh Kumar'), findsNWidgets(2)); // Avatar header & Account Details
      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('9529403798'), findsOneWidget);
      expect(find.text('admin@yadvi.com'), findsOneWidget);
      expect(find.text('RK'), findsOneWidget); // Initials
      expect(find.text('System Administrator'), findsOneWidget);
      expect(find.text('Active Account'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Authentication Mode'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      // 2. Toggle into Edit Mode (via AppBar edit icon or button)
      await tester.tap(find.byTooltip('Edit Profile'));
      await tester.pump();

      // Verify Edit Mode indicators and actions appear
      expect(find.text('Editing Mode'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // 3. Clear Full Name and attempt to Save -> verify validation error
      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), '');
      await tester.tap(find.text('Save Changes'));
      await tester.pump();

      expect(find.text('Full name is required'), findsOneWidget);

      // 4. Tap Cancel -> verify reverts to View Mode
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(find.text('Editing Mode'), findsNothing);
      expect(find.text('Save Changes'), findsNothing);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Ramesh Kumar'), findsNWidgets(2));
    });

    testWidgets('PhoneChangeVerificationSession properly distinguishes auto-verified from manual OTP session',
        (WidgetTester tester) async {
      const autoSession = PhoneChangeVerificationSession(autoVerifiedToken: 'firebase_jwt_token_123');
      expect(autoSession.isAutoVerified, isTrue);
      expect(autoSession.verificationId, isNull);

      const manualSession = PhoneChangeVerificationSession(verificationId: 'verification_id_456');
      expect(manualSession.isAutoVerified, isFalse);
      expect(manualSession.verificationId, 'verification_id_456');
    });

    testWidgets('AdminProfileScreen validates 10-digit mobile number format before verification',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockProfile = {
        'id': 1,
        'full_name': 'Ramesh Kumar',
        'username': 'ADMIN',
        'phone': '9529403798',
        'email': 'admin@yadvi.com',
        'role': 'administrator',
        'is_active': true,
      };

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: MaterialApp(
            home: AdminProfileScreen(initialProfile: mockProfile),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.byTooltip('Edit Profile'));
      await tester.pump();

      // Enter invalid 5-digit number
      await tester.enterText(find.widgetWithText(TextFormField, 'Registered Mobile Number'), '12345');
      await tester.tap(find.text('Save Changes'));
      await tester.pump();

      expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
    });
  });
}
