import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/features/dashboard/dashboard_screen.dart';
import 'package:admin_app/models/dashboard_model.dart';
import 'package:admin_app/providers/admin_provider.dart';

class MockAdminProvider extends AdminProvider {
  final DashboardDataModel? _mockData;
  final bool _loading;
  final String? _mockError;

  MockAdminProvider({
    DashboardDataModel? mockData,
    bool loading = false,
    String? mockError,
  })  : _mockData = mockData,
        _loading = loading,
        _mockError = mockError;

  @override
  DashboardDataModel? get dashboardData => _mockData;

  @override
  bool get isLoadingDashboard => _loading;

  @override
  String? get error => _mockError;

  @override
  Future<void> fetchDashboard() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDashboardData = DashboardDataModel(
    kpis: [],
    totalOrders: 164,
    pendingOrders: 153,
    dispatchedOrders: 7,
    deliveredOrders: 1,
    totalProducts: 43,
    totalShops: 10,
    totalExecutives: 9,
    presentToday: 4,
    totalVisitsToday: 27,
    completedVisitsToday: 12,
    totalEodReports: 18,
    eodReportsToday: 3,
  );

  group('Task 5 — Admin Welcome Dashboard Tests (Admin App)', () {
    testWidgets('Renders all 8 functional KPI cards with real database counts',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProvider(mockData: testDashboardData);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AdminProvider>.value(
            value: mockProvider,
            child: DashboardScreen(
              onNavigateTab: (index, {orderFilter}) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Card Titles
      expect(find.text('Total Orders'), findsOneWidget);
      expect(find.text('Pending Orders'), findsOneWidget);
      expect(find.text('In-Transit'), findsOneWidget);
      expect(find.text('Field Force'), findsOneWidget);
      expect(find.text('Shop Owners'), findsOneWidget);
      expect(find.text('Seed Varieties'), findsOneWidget);
      expect(find.text('Visits Today'), findsOneWidget);
      expect(find.text('Daily EOD Reports'), findsOneWidget);

      // Verify Real Metric Counts
      expect(find.text('164'), findsOneWidget); // Total Orders
      expect(find.text('153'), findsOneWidget); // Pending Orders
      expect(find.text('7'), findsOneWidget);   // In-Transit
      expect(find.text('9'), findsOneWidget);   // Field Force
      expect(find.text('10'), findsOneWidget);  // Shop Owners
      expect(find.text('43'), findsOneWidget);  // Seed Varieties
      expect(find.text('27'), findsOneWidget);  // Visits Today
      expect(find.text('18'), findsOneWidget);  // Daily EOD Reports

      // Verify Subtitles
      expect(find.text('1 Delivered'), findsOneWidget);
      expect(find.text('Awaiting Action'), findsOneWidget);
      expect(find.text('Active Dispatches'), findsOneWidget);
      expect(find.text('4 Active Today'), findsOneWidget);
      expect(find.text('Authorized Network'), findsOneWidget);
      expect(find.text('Active Catalog'), findsOneWidget);
      expect(find.text('12 Completed'), findsOneWidget);
      expect(find.text('3 Filed Today'), findsOneWidget);
    });

    testWidgets('Tapping Total Orders card navigates to Orders tab with All filter',
        (WidgetTester tester) async {
      int? navigatedIndex;
      String? navigatedFilter;

      final mockProvider = MockAdminProvider(mockData: testDashboardData);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AdminProvider>.value(
            value: mockProvider,
            child: DashboardScreen(
              onNavigateTab: (index, {orderFilter}) {
                navigatedIndex = index;
                navigatedFilter = orderFilter;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Total Orders'));
      await tester.pumpAndSettle();

      expect(navigatedIndex, equals(1));
      expect(navigatedFilter, equals('All'));
    });

    testWidgets('Tapping Pending Orders card navigates to Orders tab with Pending filter',
        (WidgetTester tester) async {
      int? navigatedIndex;
      String? navigatedFilter;

      final mockProvider = MockAdminProvider(mockData: testDashboardData);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AdminProvider>.value(
            value: mockProvider,
            child: DashboardScreen(
              onNavigateTab: (index, {orderFilter}) {
                navigatedIndex = index;
                navigatedFilter = orderFilter;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pending Orders'));
      await tester.pumpAndSettle();

      expect(navigatedIndex, equals(1));
      expect(navigatedFilter, equals('Pending'));
    });

    testWidgets('Tapping Field Force, Shop Owners, and Seed Varieties cards navigates to tabs 3, 4, 2',
        (WidgetTester tester) async {
      int? navigatedIndex;

      final mockProvider = MockAdminProvider(mockData: testDashboardData);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AdminProvider>.value(
            value: mockProvider,
            child: DashboardScreen(
              onNavigateTab: (index, {orderFilter}) {
                navigatedIndex = index;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Field Force -> Tab 3
      await tester.ensureVisible(find.text('Field Force'));
      await tester.tap(find.text('Field Force'));
      await tester.pumpAndSettle();
      expect(navigatedIndex, equals(3));

      // Shop Owners -> Tab 4
      await tester.ensureVisible(find.text('Shop Owners'));
      await tester.tap(find.text('Shop Owners'));
      await tester.pumpAndSettle();
      expect(navigatedIndex, equals(4));

      // Seed Varieties -> Tab 2
      await tester.ensureVisible(find.text('Seed Varieties'));
      await tester.tap(find.text('Seed Varieties'));
      await tester.pumpAndSettle();
      expect(navigatedIndex, equals(2));
    });

    testWidgets('Renders error state when dashboard data fails to load',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProvider(
        mockData: null,
        loading: false,
        mockError: 'Network connection timed out',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AdminProvider>.value(
            value: mockProvider,
            child: DashboardScreen(
              onNavigateTab: (index, {orderFilter}) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load dashboard metrics'), findsOneWidget);
      expect(find.text('Network connection timed out'), findsOneWidget);
      expect(find.text('Retry Connection'), findsOneWidget);
    });
  });
}
