import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/features/admin/main_scaffold.dart';
import 'package:unified_app/features/admin/profile/admin_profile_screen.dart';
import 'package:unified_app/providers/admin_provider.dart';
import 'package:unified_app/providers/auth_provider.dart';

class MockAdminDrawerProvider extends AdminProvider {
  @override
  bool get isLoadingEod => false;

  @override
  bool get isLoadingEmployees => false;

  @override
  bool get isLoadingShops => false;

  @override
  bool get isLoadingProducts => false;

  @override
  Future<void> refreshAll() async {}

  @override
  Future<void> fetchDashboard() async {}

  @override
  Future<void> fetchOrders() async {}

  @override
  Future<void> fetchProducts() async {}

  @override
  Future<void> fetchEmployees() async {}

  @override
  Future<void> fetchShops() async {}

  @override
  Future<void> fetchVisits({int? executiveId}) async {}

  @override
  Future<void> fetchShipments() async {}

  @override
  Future<void> fetchEodReports({DateTime? date}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createAdminScaffoldApp({double bottomInset = 0.0}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AdminProvider>(create: (_) => MockAdminDrawerProvider()),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        builder: (context, child) {
          final existing = MediaQuery.of(context);
          return MediaQuery(
            data: existing.copyWith(
              viewPadding: existing.viewPadding.copyWith(bottom: bottomInset),
              padding: existing.padding.copyWith(bottom: bottomInset),
            ),
            child: child!,
          );
        },
        home: const AdminMainScaffold(),
      ),
    );
  }

  Future<void> openDrawer(WidgetTester tester) async {
    final drawerBtn = find.byTooltip('Open Navigation Drawer');
    expect(drawerBtn, findsOneWidget);
    await tester.tap(drawerBtn);
    await tester.pumpAndSettle();
  }

  group('Admin Navigation Drawer Safe Area & Bottom Items Tests', () {
    testWidgets(
        'Drawer displays bottom items separated from scrollable operations list',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createAdminScaffoldApp(bottomInset: 0.0));
      await tester.pumpAndSettle();

      await openDrawer(tester);

      // Drawer is open, verify upper operations items exist
      expect(find.text('OPERATIONS & AUDITING'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Drawer), matching: find.text('Dashboard')),
        findsOneWidget,
      );

      // Verify bottom items exist and are rendered
      expect(find.text('Profile & Settings'), findsOneWidget);
      expect(find.text('Logout Session'), findsOneWidget);

      // Verify SafeArea wraps the bottom items Column
      final safeAreas = tester.widgetList<SafeArea>(find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(SafeArea),
      ));
      expect(safeAreas.any((sa) => sa.bottom == true), isTrue);
    });

    testWidgets(
        'Simulated 3-button navigation (bottom: 48dp) positions Logout Session strictly above navigation bar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const double navBarHeight = 48.0;
      await tester.pumpWidget(createAdminScaffoldApp(bottomInset: navBarHeight));
      await tester.pumpAndSettle();

      await openDrawer(tester);

      // Find bottom coordinate of the 'Logout Session' widget
      final logoutFinder = find.widgetWithText(ListTile, 'Logout Session');
      expect(logoutFinder, findsOneWidget);

      final logoutRect = tester.getRect(logoutFinder);
      final double screenHeight = tester.view.physicalSize.height;

      // The bottom of Logout Session ListTile must be at or above (screenHeight - navBarHeight)
      expect(
        logoutRect.bottom,
        lessThanOrEqualTo(screenHeight - navBarHeight),
        reason:
            'Logout Session must not overlap the 48dp 3-button system navigation bar',
      );

      // Profile & Settings must be above Logout Session
      final profileFinder = find.widgetWithText(ListTile, 'Profile & Settings');
      expect(profileFinder, findsOneWidget);

      final profileRect = tester.getRect(profileFinder);
      expect(profileRect.bottom, lessThanOrEqualTo(logoutRect.top));
    });

    testWidgets(
        'Simulated Gesture navigation (bottom: 24dp) respects system gesture bar insets',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const double gestureBarHeight = 24.0;
      await tester.pumpWidget(createAdminScaffoldApp(bottomInset: gestureBarHeight));
      await tester.pumpAndSettle();

      await openDrawer(tester);

      final logoutFinder = find.widgetWithText(ListTile, 'Logout Session');
      final logoutRect = tester.getRect(logoutFinder);
      final double screenHeight = tester.view.physicalSize.height;

      expect(
        logoutRect.bottom,
        lessThanOrEqualTo(screenHeight - gestureBarHeight),
        reason:
            'Logout Session must not overlap the 24dp gesture system navigation bar',
      );
    });

    testWidgets('Tapping Profile & Settings navigates to AdminProfileScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createAdminScaffoldApp(bottomInset: 0.0));
      await tester.pumpAndSettle();

      await openDrawer(tester);

      final profileTile = find.widgetWithText(ListTile, 'Profile & Settings');
      expect(profileTile, findsOneWidget);

      await tester.tap(profileTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Navigated to AdminProfileScreen
      expect(find.byType(AdminProfileScreen), findsOneWidget);
    });

    testWidgets('Tapping Logout Session opens confirmation dialog',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createAdminScaffoldApp(bottomInset: 0.0));
      await tester.pumpAndSettle();

      await openDrawer(tester);

      final logoutTile = find.widgetWithText(ListTile, 'Logout Session');
      expect(logoutTile, findsOneWidget);

      await tester.tap(logoutTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the logout confirmation dialog appears
      expect(find.text('Confirm Logout'), findsOneWidget);
      expect(find.text('Are you sure you want to log out of the Administrator Console?'),
          findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Logout'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Confirm Logout'), findsNothing);
    });
  });
}
