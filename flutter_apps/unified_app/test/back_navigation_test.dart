import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/core/widgets/exit_dialog.dart';
import 'package:unified_app/features/auth/unified_role_selection_screen.dart';
import 'package:unified_app/features/admin/main_scaffold.dart';
import 'package:unified_app/features/admin/reports/eod_reports_screen.dart';
import 'package:unified_app/models/eod_model.dart';
import 'package:unified_app/providers/admin_provider.dart';
import 'package:unified_app/providers/auth_provider.dart';

class MockAdminNavProvider extends AdminProvider {
  DateTime? filteredDate;
  List<EODReportModel> mockReports = [];

  MockAdminNavProvider({this.mockReports = const []});

  @override
  List<EODReportModel> get eodReports => mockReports;

  @override
  bool get isLoadingEod => false;

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
  Future<void> fetchEodReports({DateTime? date}) async {
    filteredDate = date;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK 3: Authentication Back Navigation Tests', () {
    testWidgets('Role Selection -> Admin Login -> Back button returns to Role Selection', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(
            home: UnifiedRoleSelectionScreen(),
          ),
        ),
      );

      // Verify on Role Selection
      expect(find.text('Select Access Module'), findsOneWidget);

      // Tap Admin card
      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();

      // Now on Admin Login Screen
      expect(find.text('Administrator Login'), findsOneWidget);

      // Tap visible AppBar back button
      final backButton = find.byType(BackButton);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verified returned to Role Selection
      expect(find.text('Select Access Module'), findsOneWidget);
    });

    testWidgets('Role Selection -> FE Login -> Back button returns to Role Selection', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(
            home: UnifiedRoleSelectionScreen(),
          ),
        ),
      );

      // Tap Field Executive card
      await tester.tap(find.text('Field Executive (FE)'));
      await tester.pumpAndSettle();

      // Now on FE Role Login Screen
      expect(find.text('Field Executive (FE) Login'), findsOneWidget);

      // Tap visible AppBar back button
      final backButton = find.byType(BackButton);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verified returned to Role Selection
      expect(find.text('Select Access Module'), findsOneWidget);
    });

    testWidgets('Role Selection -> SO Login -> Back button returns to Role Selection', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(
            home: UnifiedRoleSelectionScreen(),
          ),
        ),
      );

      // Tap Shop Owner card
      await tester.tap(find.text('Shop Owner (SO)'));
      await tester.pumpAndSettle();

      // Now on SO Role Login Screen
      expect(find.text('Shop Owner (SO) Login'), findsOneWidget);

      // Tap visible AppBar back button
      final backButton = find.byType(BackButton);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verified returned to Role Selection
      expect(find.text('Select Access Module'), findsOneWidget);
    });
  });

  group('TASK 3: Exit Confirmation Dialog Tests', () {
    testWidgets('Exit dialog renders title, message, Stay and Exit buttons correctly', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showExitConfirmationDialog(context);
                },
                child: const Text('Open Exit Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('Open Exit Dialog'));
      await tester.pumpAndSettle();

      // Verify exact dialog text requirements
      expect(find.text('Exit App?'), findsOneWidget);
      expect(find.text('Are you sure you want to exit the application?'), findsOneWidget);
      expect(find.text('Stay'), findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);

      // Tap Stay -> should dismiss and return false
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      // Re-open and tap Exit -> should dismiss and return true
      await tester.tap(find.text('Open Exit Dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('Exit dialog concurrency guard prevents multiple dialogs from stacking', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  // Simulate rapid double tap
                  showExitConfirmationDialog(context);
                  showExitConfirmationDialog(context);
                },
                child: const Text('Rapid Tap'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Rapid Tap'));
      await tester.pumpAndSettle();

      // Verify only 1 instance of AlertDialog is created
      expect(find.byType(AlertDialog), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
    });
  });

  group('TASK 3: Bottom Navigation Tab History Unit Tests', () {
    test('Tab history records navigation without duplicate consecutive entries', () {
      final List<int> tabHistory = [0];
      int currentIndex = 0;

      void onTabTapped(int index) {
        if (currentIndex != index) {
          currentIndex = index;
          if (tabHistory.isEmpty || tabHistory.last != index) {
            tabHistory.add(index);
          }
        }
      }

      // Navigate 0 -> 1 -> 4
      onTabTapped(1);
      expect(currentIndex, 1);
      expect(tabHistory, [0, 1]);

      onTabTapped(4);
      expect(currentIndex, 4);
      expect(tabHistory, [0, 1, 4]);

      // Tapping same tab 4 again does not add duplicates
      onTabTapped(4);
      expect(tabHistory, [0, 1, 4]);

      // Navigate back
      bool handleBack() {
        if (tabHistory.length > 1) {
          tabHistory.removeLast();
          currentIndex = tabHistory.last;
          return true; // handled
        }
        return false; // at root, trigger exit dialog
      }

      // First back: from 4 -> returns to 1
      expect(handleBack(), isTrue);
      expect(currentIndex, 1);
      expect(tabHistory, [0, 1]);

      // Second back: from 1 -> returns to 0
      expect(handleBack(), isTrue);
      expect(currentIndex, 0);
      expect(tabHistory, [0]);

      // Third back: at root (0) -> returns false (signals exit dialog)
      expect(handleBack(), isFalse);
      expect(currentIndex, 0);
      expect(tabHistory, [0]);
    });
  });

  group('TASK 4: Admin Back Navigation and Drawer Preservation Tests', () {
    testWidgets('AdminMainScaffold preserves Drawer and Back arrow co-existence; drawer opens cleanly', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminProvider>(create: (_) => MockAdminNavProvider()),
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(
            home: AdminMainScaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check drawer icon and back arrow exist in leading area
      final drawerBtn = find.byTooltip('Open Navigation Drawer');
      expect(drawerBtn, findsOneWidget);
      final backBtn = find.byTooltip('Exit Application');
      expect(backBtn, findsOneWidget);

      // Open drawer
      await tester.tap(drawerBtn);
      await tester.pumpAndSettle();

      // Verify drawer menu items are visible
      expect(find.descendant(of: find.byType(Drawer), matching: find.text('Daily EOD Reports')), findsOneWidget);
      expect(find.text('Live Force Tracking'), findsOneWidget);
    });

    testWidgets('AdminMainScaffold visible back button unwinds tab history and triggers exit dialog at root', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminProvider>(create: (_) => MockAdminNavProvider()),
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(
            home: AdminMainScaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Starts on tab 0 (Admin Dashboard)
      expect(find.text('Admin Dashboard'), findsOneWidget);

      // Tap tab 1 (Orders)
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();
      expect(find.text('Manage Orders'), findsOneWidget);

      // Tap tab 2 (Products)
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      expect(find.text('Products & Seeds'), findsOneWidget);

      // First back press: unwinds Products -> Orders
      final backBtn = find.byTooltip('Back to Previous Tab');
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();
      expect(find.text('Manage Orders'), findsOneWidget);

      // Second back press: unwinds Orders -> Admin Dashboard
      await tester.tap(backBtn);
      await tester.pumpAndSettle();
      expect(find.text('Admin Dashboard'), findsOneWidget);

      // Third back press: at root, triggers exit confirmation dialog
      final exitBackBtn = find.byTooltip('Exit Application');
      expect(exitBackBtn, findsOneWidget);
      await tester.tap(exitBackBtn);
      await tester.pumpAndSettle();

      // Verify exit confirmation dialog
      expect(find.text('Exit App?'), findsOneWidget);
      expect(find.text('Are you sure you want to exit the application?'), findsOneWidget);

      // Tap Stay to dismiss
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.text('Admin Dashboard'), findsOneWidget);
    });
  });

  group('TASK 4: Detail Route Popping Tests (Priority 1)', () {
    testWidgets('Detail screen visible back button and hardware back pop correctly', (tester) async {
      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Scaffold(
            appBar: AppBar(title: const Text('Root Screen')),
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  navKey.currentState!.push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: const Text('Detail Screen'),
                          leading: BackButton(onPressed: () => navKey.currentState!.pop()),
                        ),
                        body: const Center(child: Text('Detail Content')),
                      ),
                    ),
                  );
                },
                child: const Text('Open Detail'),
              ),
            ),
          ),
        ),
      );

      // Open detail screen
      await tester.tap(find.text('Open Detail'));
      await tester.pumpAndSettle();
      expect(find.text('Detail Screen'), findsOneWidget);

      // 1. Visible back button pops detail screen
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Root Screen'), findsOneWidget);
      expect(find.text('Detail Screen'), findsNothing);

      // Open detail screen again
      await tester.tap(find.text('Open Detail'));
      await tester.pumpAndSettle();
      expect(find.text('Detail Screen'), findsOneWidget);

      // 2. Hardware back pops detail screen
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Root Screen'), findsOneWidget);
      expect(find.text('Detail Screen'), findsNothing);
    });
  });

  group('TASK 4: Admin EOD Date-Wise Filtering Tests', () {
    testWidgets('EodReportsScreen displays date filter button, empty state, and clear action', (tester) async {
      final mockProvider = MockAdminNavProvider(mockReports: []);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminProvider>.value(value: mockProvider),
          ],
          child: const MaterialApp(
            home: EodReportsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header title and calendar button
      expect(find.text('Daily EOD Reports'), findsOneWidget);
      final calendarBtn = find.byTooltip('Filter by Date');
      expect(calendarBtn, findsOneWidget);

      // Initially unfiltered empty state
      expect(find.text('No EOD reports submitted yet'), findsOneWidget);
    });
  });
}
