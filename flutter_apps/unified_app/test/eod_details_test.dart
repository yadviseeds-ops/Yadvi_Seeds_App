import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/features/admin/reports/eod_reports_screen.dart';
import 'package:unified_app/features/admin/reports/eod_report_details_screen.dart';
import 'package:unified_app/models/eod_model.dart';
import 'package:unified_app/models/visit_model.dart';
import 'package:unified_app/providers/admin_provider.dart';

class MockAdminProviderWithVisits extends AdminProvider {
  final List<EODReportModel> mockReports;
  final List<VisitModel> mockVisits;
  bool simulateError = false;
  bool simulateLoading = false;

  MockAdminProviderWithVisits({
    required this.mockReports,
    required this.mockVisits,
  });

  @override
  List<EODReportModel> get eodReports => mockReports;

  @override
  bool get isLoadingEod => false;

  @override
  List<VisitModel> get visits => mockVisits;

  @override
  bool get isLoadingVisits => simulateLoading;

  @override
  String? get visitsError =>
      simulateError ? 'Failed to fetch visit records from server' : null;

  @override
  Future<void> fetchEodReports({DateTime? date}) async {
    // No-op for tests: prevents real network requests during widget testing
  }

  @override
  Future<void> fetchVisits({int? executiveId}) async {
    // Error state simulation is controlled via visitsError getter
  }

  @override
  List<VisitModel> getVisitsForEodReport(EODReportModel report) {
    return mockVisits.where((v) {
      if (v.executiveId != report.executiveId) return false;
      final repDate = report.reportDate;
      if (v.visitedAt != null) {
        final d = v.visitedAt!;
        if (d.year == repDate.year &&
            d.month == repDate.month &&
            d.day == repDate.day) {
          return true;
        }
      }
      final s = v.scheduledDate;
      return s.year == repDate.year &&
          s.month == repDate.month &&
          s.day == repDate.day;
    }).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 10, 24, 10, 0);

  final List<EODReportModel> testReports = [
    EODReportModel(
      id: 1,
      executiveId: 101,
      executiveName: 'Ramesh Kumar',
      reportDate: testDate,
      completedVisits: 2,
      pendingVisits: 1,
      totalBagsOrdered: 50,
      notes: 'Territory coverage smooth. Orders placed at Sri Balaji Seeds.',
      createdAt: DateTime(2026, 10, 24, 18, 30),
    ),
    EODReportModel(
      id: 2,
      executiveId: 102,
      executiveName: 'Suresh Patel',
      reportDate: testDate,
      completedVisits: 0,
      pendingVisits: 2,
      totalBagsOrdered: 0,
      notes: 'Bike breakdown near Tenali. Visits rescheduled.',
      createdAt: DateTime(2026, 10, 24, 17, 45),
    ),
  ];

  final List<VisitModel> testVisits = [
    // Ramesh (101) visits on 2026-10-24
    VisitModel(
      id: 201,
      executiveId: 101,
      executiveName: 'Ramesh Kumar',
      employeeCode: 'EMP-101',
      shopId: 11,
      shopName: 'Sri Balaji Seeds & Pesticides',
      shopLocation: 'Main Bazar, Guntur',
      scheduledDate: testDate,
      visitedAt: DateTime(2026, 10, 24, 11, 30),
      status: 'Visited',
      purpose: 'Order Booking',
      notes: 'Booked 30 bags of cotton seeds',
      bagsOrdered: 30,
      photoUrl: 'https://example.com/visits/visit_201.jpg',
    ),
    VisitModel(
      id: 202,
      executiveId: 101,
      executiveName: 'Ramesh Kumar',
      employeeCode: 'EMP-101',
      shopId: 12,
      shopName: 'Kisan Krishi Kendra',
      shopLocation: 'Station Road, Guntur',
      scheduledDate: testDate,
      visitedAt: DateTime(2026, 10, 24, 14, 15),
      status: 'Completed',
      purpose: 'Product Demo',
      notes: 'Demonstrated Hybrid Maize 707',
      bagsOrdered: 20,
    ),
    VisitModel(
      id: 203,
      executiveId: 101,
      executiveName: 'Ramesh Kumar',
      employeeCode: 'EMP-101',
      shopId: 13,
      shopName: 'Annapurna Agro Agencies',
      shopLocation: 'Market Yard, Guntur',
      scheduledDate: testDate,
      visitedAt: null,
      status: 'Pending',
      purpose: 'Payment Collection',
      notes: 'Owner was not available, visit postponed',
      bagsOrdered: 0,
    ),
    // Ramesh visit on a DIFFERENT date (2026-10-23) - must NOT be included in 2026-10-24 report
    VisitModel(
      id: 204,
      executiveId: 101,
      executiveName: 'Ramesh Kumar',
      employeeCode: 'EMP-101',
      shopId: 14,
      shopName: 'Unrelated Date Shop',
      shopLocation: 'Old Town',
      scheduledDate: DateTime(2026, 10, 23, 10, 0),
      visitedAt: DateTime(2026, 10, 23, 11, 0),
      status: 'Visited',
      purpose: 'Routine',
      bagsOrdered: 0,
    ),
    // Suresh (102) visits on 2026-10-24
    VisitModel(
      id: 205,
      executiveId: 102,
      executiveName: 'Suresh Patel',
      employeeCode: 'EMP-102',
      shopId: 21,
      shopName: 'Tenali Farmer Service Point',
      shopLocation: 'Tenali East',
      scheduledDate: testDate,
      visitedAt: null,
      status: 'Pending',
      purpose: 'Seasonal Stock Check',
      notes: 'Pending due to bike breakdown',
      bagsOrdered: 0,
    ),
    VisitModel(
      id: 206,
      executiveId: 102,
      executiveName: 'Suresh Patel',
      employeeCode: 'EMP-102',
      shopId: 22,
      shopName: 'Laxmi Seeds Corporation',
      shopLocation: 'Tenali Highway',
      scheduledDate: testDate,
      visitedAt: null,
      status: 'Scheduled',
      purpose: 'Introduction',
      bagsOrdered: 0,
    ),
    // Another FE (103) visit - must NEVER be displayed for Ramesh or Suresh
    VisitModel(
      id: 207,
      executiveId: 103,
      executiveName: 'Venkat Rao',
      employeeCode: 'EMP-103',
      shopId: 31,
      shopName: 'Other FE Secret Store',
      shopLocation: 'Vijayawada',
      scheduledDate: testDate,
      visitedAt: testDate,
      status: 'Visited',
      purpose: 'Confidential',
      bagsOrdered: 0,
    ),
  ];

  group('EOD Reports Screen & Expandable Visit Details Tests', () {
    testWidgets(
        '1. Existing Completed and Pending counts remain unchanged in EOD list',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderWithVisits(
        mockReports: testReports,
        mockVisits: testVisits,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: mockProvider,
          child: const MaterialApp(
            home: EodReportsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check report 1 FE and stats
      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // Completed visits for Ramesh
      expect(find.text('1'), findsWidgets); // Pending visits for Ramesh
      expect(find.text('50'), findsWidgets); // Orders booked for Ramesh

      // Check report 2 FE and stats
      expect(find.text('Suresh Patel'), findsOneWidget);
      expect(find.text('0'), findsWidgets); // Completed visits for Suresh

      // Check stat labels
      expect(find.text('Completed Visits'), findsNWidgets(2));
      expect(find.text('Pending Visits'), findsNWidgets(2));
      expect(find.text('Orders Booked'), findsNWidgets(2));

      // Ensure no battery indicators exist on the screen
      expect(find.byIcon(Icons.battery_full), findsNothing);
      expect(find.byIcon(Icons.battery_alert), findsNothing);
      expect(find.byIcon(Icons.battery_charging_full), findsNothing);
    });

    testWidgets(
        '2. Tapping an EOD report navigates to EodReportDetailsScreen for matching FE',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderWithVisits(
        mockReports: testReports,
        mockVisits: testVisits,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: mockProvider,
          child: const MaterialApp(
            home: EodReportsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Ramesh Kumar's EOD report
      final tapTarget = find.byKey(const ValueKey('eod_tap_1'));
      expect(tapTarget, findsOneWidget);
      await tester.tap(tapTarget);
      await tester.pumpAndSettle();

      // Verify EOD Report Details screen is displayed with executive title
      expect(find.text('EOD: Ramesh Kumar'), findsOneWidget);
      expect(find.text('Executive ID: #101 • Report #1'), findsOneWidget);
      expect(find.text('Completed Visits'), findsOneWidget);
      expect(find.text('Pending Visits'), findsOneWidget);
    });

    testWidgets(
        '3. Completed Visits section displays correct shop names, IDs, and notes',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderWithVisits(
        mockReports: testReports,
        mockVisits: testVisits,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: mockProvider,
          child: MaterialApp(
            home: Scaffold(
              body: EodReportDetailsScreen(report: testReports[0]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Completed section shop names
      expect(find.byKey(const ValueKey('completed_shop_201')), findsOneWidget);
      expect(find.text('Sri Balaji Seeds & Pesticides'), findsOneWidget);
      expect(find.byKey(const ValueKey('completed_shop_202')), findsOneWidget);
      expect(find.text('Kisan Krishi Kendra'), findsOneWidget);

      // Verify Shop ID & Visit ID
      expect(find.text('Shop ID: #11 • Visit ID: #201'), findsOneWidget);
      expect(find.text('Shop ID: #12 • Visit ID: #202'), findsOneWidget);

      // Verify notes and purposes
      expect(find.text('Purpose: Order Booking'), findsOneWidget);
      expect(
          find.text('Notes: "Booked 30 bags of cotton seeds"'), findsOneWidget);
      expect(find.text('Purpose: Product Demo'), findsOneWidget);
      expect(find.text('Notes: "Demonstrated Hybrid Maize 707"'),
          findsOneWidget);
    });

    testWidgets(
        '4. Pending Visits section displays correct shop names, IDs, and pending notes',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderWithVisits(
        mockReports: testReports,
        mockVisits: testVisits,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: mockProvider,
          child: MaterialApp(
            home: Scaffold(
              body: EodReportDetailsScreen(report: testReports[0]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Pending section shop name
      expect(find.byKey(const ValueKey('pending_shop_203')), findsOneWidget);
      expect(find.text('Annapurna Agro Agencies'), findsOneWidget);
      expect(find.text('Shop ID: #13 • Visit ID: #203'), findsOneWidget);
      expect(find.text('Purpose: Payment Collection'), findsOneWidget);
      expect(find.text('Notes: "Owner was not available, visit postponed"'),
          findsOneWidget);
    });

    testWidgets(
        '5. Visits from another FE or different date are strictly excluded',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderWithVisits(
        mockReports: testReports,
        mockVisits: testVisits,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: mockProvider,
          child: MaterialApp(
            home: Scaffold(
              body: EodReportDetailsScreen(report: testReports[0]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Different FE's shop must NOT exist
      expect(find.text('Other FE Secret Store'), findsNothing);
      expect(find.text('Tenali Farmer Service Point'), findsNothing);
      expect(find.text('Laxmi Seeds Corporation'), findsNothing);

      // Different date shop for the same FE must NOT exist
      expect(find.text('Unrelated Date Shop'), findsNothing);
    });

    testWidgets('6. Empty state displays properly when a section has 0 visits',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderWithVisits(
        mockReports: testReports,
        mockVisits: testVisits,
      );

      // Open Suresh's report which has 0 completed visits and 2 pending visits
      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: mockProvider,
          child: MaterialApp(
            home: Scaffold(
              body: EodReportDetailsScreen(report: testReports[1]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Completed Visits shows empty message
      expect(find.text('No completed visits recorded for this reporting period.'),
          findsOneWidget);

      // Verify Pending Visits shows both pending shops
      expect(find.text('Tenali Farmer Service Point'), findsOneWidget);
      expect(find.text('Laxmi Seeds Corporation'), findsOneWidget);
      expect(find.text('Notes: "Pending due to bike breakdown"'), findsOneWidget);
    });

    testWidgets('7. Error state displays error message and Retry action',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderWithVisits(
        mockReports: testReports,
        mockVisits: testVisits,
      );
      mockProvider.simulateError = true;

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: mockProvider,
          child: MaterialApp(
            home: Scaffold(
              body: EodReportDetailsScreen(report: testReports[0]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to fetch visit records from server'),
          findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('8. No battery indicators present on details screen',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderWithVisits(
        mockReports: testReports,
        mockVisits: testVisits,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: mockProvider,
          child: MaterialApp(
            home: Scaffold(
              body: EodReportDetailsScreen(report: testReports[0]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.battery_full), findsNothing);
      expect(find.byIcon(Icons.battery_alert), findsNothing);
      expect(find.byIcon(Icons.battery_charging_full), findsNothing);
      expect(find.textContaining('% battery'), findsNothing);
    });

    testWidgets('9. Completed visits display visit photo proof under corresponding visit card',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderWithVisits(
        mockReports: testReports,
        mockVisits: testVisits,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: mockProvider,
          child: MaterialApp(
            home: Scaffold(
              body: EodReportDetailsScreen(report: testReports[0]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Visit 201 has photoUrl -> Should display 'Visit Photo Proof' and photo widget
      expect(find.text('Visit Photo Proof'), findsOneWidget);
      expect(find.byKey(const ValueKey('visit_photo_201')), findsOneWidget);

      // Visit 202 is completed but has no photo -> Shows 'No visit photo recorded'
      expect(find.text('No visit photo recorded'), findsOneWidget);

      // Both completed shops must be visible
      expect(find.text('Sri Balaji Seeds & Pesticides'), findsOneWidget);
      expect(find.text('Kisan Krishi Kendra'), findsOneWidget);
    });

    testWidgets('10. Pending visits remain pending and do not show photo proof',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderWithVisits(
        mockReports: testReports,
        mockVisits: testVisits,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: mockProvider,
          child: MaterialApp(
            home: Scaffold(
              body: EodReportDetailsScreen(report: testReports[0]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pending visit (203 - Annapurna Agro Agencies) is listed under Pending
      expect(find.text('Annapurna Agro Agencies'), findsOneWidget);
      expect(find.byKey(const ValueKey('pending_shop_203')), findsOneWidget);
      expect(find.byKey(const ValueKey('visit_photo_203')), findsNothing);
    });
  });
}
