import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_app/models/visit_model.dart';
import 'package:unified_app/models/eod_model.dart';
import 'package:unified_app/models/fe_profile.dart';
import 'package:unified_app/models/order_model.dart';
import 'package:unified_app/services/fe_service.dart';
import 'package:unified_app/features/field_executive/dashboard/dashboard_screen.dart';
import 'package:unified_app/features/field_executive/eod/eod_report_screen.dart';
import 'package:unified_app/providers/admin_provider.dart';

class MockFeServiceForCounts extends FeService {
  List<VisitModel> mockVisits;
  int submitEodCalls = 0;
  int? lastCompletedSubmitted;
  int? lastPendingSubmitted;
  int? lastBagsSubmitted;

  MockFeServiceForCounts({required this.mockVisits});

  @override
  Future<FeProfile> getMyProfile() async {
    return FeProfile(
      id: 2,
      userId: 3,
      fullName: 'Ravi Kumar',
      phone: '9848099001',
      employeeCode: 'YHS-EMP-003',
      assignedTerritory: 'Krishna - Vijayawada Belt',
      designation: 'Field Executive',
      batteryLevel: 100,
      attendanceStatus: 'Present',
      isActive: true,
    );
  }

  @override
  Future<List<VisitModel>> getVisits() async {
    return List.from(mockVisits);
  }

  @override
  Future<List<OrderModel>> getMyOrders() async {
    return [];
  }

  @override
  Future<void> submitEodReport({
    required int completedVisits,
    required int pendingVisits,
    required int totalBagsOrdered,
    String? notes,
  }) async {
    submitEodCalls++;
    lastCompletedSubmitted = completedVisits;
    lastPendingSubmitted = pendingVisits;
    lastBagsSubmitted = totalBagsOrdered;
  }
}

void main() {
  group("FE Visits & EOD Authoritative Counts Regression Tests", () {
    test("1. VisitModel.isToday accurately identifies today's visits including visits scheduled earlier but completed today", () {
      final now = DateTime.now();

      // Case A: Scheduled today
      final visitScheduledToday = VisitModel(
        id: 1,
        executiveId: 2,
        executiveName: 'Ravi Kumar',
        employeeCode: 'YHS-EMP-003',
        shopId: 10,
        shopName: 'ABC Seeds',
        shopLocation: 'Guntur',
        purpose: 'Scheduled Visit',
        status: 'Pending',
        bagsOrdered: 0,
        scheduledDate: now,
      );
      expect(visitScheduledToday.isToday, isTrue);

      // Case B: Scheduled 2 days ago, but visited today with photo
      final visitScheduledEarlierVisitedToday = VisitModel(
        id: 2,
        executiveId: 2,
        executiveName: 'Ravi Kumar',
        employeeCode: 'YHS-EMP-003',
        shopId: 20,
        shopName: 'Sri Ram Agro',
        shopLocation: 'Vijayawada',
        purpose: 'Follow-up',
        status: 'Visited',
        visitedAt: now,
        photoUrl: '/public/visits/visit_2.jpg',
        bagsOrdered: 10,
        scheduledDate: now.subtract(const Duration(days: 2)),
      );
      expect(visitScheduledEarlierVisitedToday.isToday, isTrue);

      // Case C: Scheduled and visited in the past
      final visitInPast = VisitModel(
        id: 3,
        executiveId: 2,
        executiveName: 'Ravi Kumar',
        employeeCode: 'YHS-EMP-003',
        shopId: 30,
        shopName: 'Old Shop',
        shopLocation: 'Ongole',
        purpose: 'Audit',
        status: 'Visited',
        visitedAt: now.subtract(const Duration(days: 5)),
        scheduledDate: now.subtract(const Duration(days: 5)),
        bagsOrdered: 0,
      );
      expect(visitInPast.isToday, isFalse);
    });

    test("2. ISO UTC-to-IST midnight boundary parsing in VisitModel and EODReportModel", () {
      // Backend naive UTC string for 18:40 UTC on Oct 25 (00:10 IST on Oct 26)
      const rawIso = "2026-10-25T18:40:00.000000";

      final visit = VisitModel.fromJson({
        "id": 16,
        "executive_id": 2,
        "executive_name": "Ravi Kumar",
        "employee_code": "YHS-EMP-003",
        "shop_id": 1,
        "shop_name": "ABC Seeds & Fertilizers",
        "shop_location": "Guntur",
        "purpose": "Scheduled Visit",
        "status": "Visited",
        "scheduled_date": rawIso,
        "visited_at": "2026-10-25T18:42:00.000000",
        "photo_url": "/public/visits/visit_16.jpg",
        "bags_ordered": 10,
      });

      final eodReport = EODReportModel.fromJson({
        "id": 2,
        "executive_id": 2,
        "executive_name": "Ravi Kumar",
        "report_date": "2026-10-25T18:42:47.000000",
        "completed_visits": 0,
        "pending_visits": 0,
        "total_bags_ordered": 0,
        "created_at": "2026-10-25T18:42:47.000000",
      });

      // Both should have parsed the date in local timezone matching each other
      expect(visit.scheduledDate.toLocal().day, equals(eodReport.reportDate.toLocal().day));
      expect(visit.scheduledDate.toLocal().year, equals(eodReport.reportDate.toLocal().year));
      expect(visit.scheduledDate.toLocal().month, equals(eodReport.reportDate.toLocal().month));
    });

    test("3. Scenario Visits #16, #17, #18: AdminProvider correctly counts completed=2, pending=1", () {
      final now = DateTime.now();

      final v16 = VisitModel(
        id: 16,
        executiveId: 2,
        executiveName: 'Ravi Kumar',
        employeeCode: 'YHS-EMP-003',
        shopId: 1,
        shopName: 'ABC Seeds & Fertilizers',
        shopLocation: 'Guntur Market Yard',
        purpose: 'Scheduled Visit',
        status: 'Visited',
        visitedAt: now.subtract(const Duration(minutes: 5)),
        photoUrl: '/public/visits/visit_16.jpg',
        bagsOrdered: 10,
        scheduledDate: now,
      );

      final v17 = VisitModel(
        id: 17,
        executiveId: 2,
        executiveName: 'Ravi Kumar',
        employeeCode: 'YHS-EMP-003',
        shopId: 2,
        shopName: 'Sri Ram Agro Stores',
        shopLocation: 'Vijayawada Rythu Bazar',
        purpose: 'Scheduled Visit',
        status: 'Visited',
        visitedAt: now.subtract(const Duration(minutes: 3)),
        photoUrl: '/public/visits/visit_17.jpg',
        bagsOrdered: 15,
        scheduledDate: now,
      );

      final v18 = VisitModel(
        id: 18,
        executiveId: 2,
        executiveName: 'Ravi Kumar',
        employeeCode: 'YHS-EMP-003',
        shopId: 3,
        shopName: 'Krishna Agri Mart',
        shopLocation: 'Ongole Main Market',
        purpose: 'Scheduled Visit',
        status: 'Pending',
        bagsOrdered: 0,
        scheduledDate: now,
      );

      final eodReport = EODReportModel(
        id: 2,
        executiveId: 2,
        executiveName: 'Ravi Kumar',
        reportDate: now,
        completedVisits: 0, // Stale client value
        pendingVisits: 0,   // Stale client value
        totalBagsOrdered: 0,
        createdAt: now,
      );

      final adminProvider = AdminProvider();
      // Inject visits into provider
      adminProvider.setVisitsForTesting([v16, v17, v18]);

      final matchedVisits = adminProvider.getVisitsForEodReport(eodReport);
      expect(matchedVisits.length, equals(3));

      final completed = matchedVisits.where((v) =>
          v.status.toLowerCase() == 'visited' || v.status.toLowerCase() == 'completed').toList();
      final pending = matchedVisits.where((v) =>
          v.status.toLowerCase() != 'visited' && v.status.toLowerCase() != 'completed').toList();

      expect(completed.length, equals(2));
      expect(pending.length, equals(1));
      expect(completed.map((v) => v.id).toList(), containsAll([16, 17]));
      expect(pending.first.id, equals(18));
      expect(pending.first.shopName, equals('Krishna Agri Mart'));
    });

    testWidgets("4. Tab switching from Today's Plan to Visits and EOD reloads fresh visits", (WidgetTester tester) async {
      final now = DateTime.now();

      // Initial state: Only 1 historic visit
      final historicVisit = VisitModel(
        id: 4,
        executiveId: 2,
        executiveName: 'Ravi Kumar',
        employeeCode: 'YHS-EMP-003',
        shopId: 1,
        shopName: 'ABC Seeds & Fertilizers',
        shopLocation: 'Guntur',
        purpose: 'Old Visit',
        status: 'Visited',
        visitedAt: now.subtract(const Duration(days: 3)),
        scheduledDate: now.subtract(const Duration(days: 3)),
        bagsOrdered: 5,
      );

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockService = MockFeServiceForCounts(mockVisits: [historicVisit]);

      await tester.pumpWidget(MaterialApp(
        home: DashboardScreen(feService: mockService),
      ));
      await tester.pumpAndSettle();

      // Switch to Visits tab (index 2)
      await tester.tap(find.text('Visits'));
      await tester.pumpAndSettle();

      // Shows Today (0) and History (1) initially
      expect(find.text('Today (0)'), findsOneWidget);
      expect(find.text('History (1)'), findsOneWidget);

      // Now simulate visits 16, 17, 18 created and completed in Today's Plan
      final v16 = VisitModel(
        id: 16,
        executiveId: 2,
        executiveName: 'Ravi Kumar',
        employeeCode: 'YHS-EMP-003',
        shopId: 1,
        shopName: 'ABC Seeds & Fertilizers',
        shopLocation: 'Guntur',
        purpose: 'Scheduled Visit',
        status: 'Visited',
        visitedAt: now,
        photoUrl: '/public/visits/visit_16.jpg',
        bagsOrdered: 10,
        scheduledDate: now,
      );

      final v17 = VisitModel(
        id: 17,
        executiveId: 2,
        executiveName: 'Ravi Kumar',
        employeeCode: 'YHS-EMP-003',
        shopId: 2,
        shopName: 'Sri Ram Agro Stores',
        shopLocation: 'Vijayawada',
        purpose: 'Scheduled Visit',
        status: 'Visited',
        visitedAt: now,
        photoUrl: '/public/visits/visit_17.jpg',
        bagsOrdered: 15,
        scheduledDate: now,
      );

      final v18 = VisitModel(
        id: 18,
        executiveId: 2,
        executiveName: 'Ravi Kumar',
        employeeCode: 'YHS-EMP-003',
        shopId: 3,
        shopName: 'Krishna Agri Mart',
        shopLocation: 'Ongole',
        purpose: 'Scheduled Visit',
        status: 'Pending',
        bagsOrdered: 0,
        scheduledDate: now,
      );

      mockService.mockVisits = [historicVisit, v16, v17, v18];

      // Switch to Plan tab, then back to Visits tab
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Visits'));
      await tester.pumpAndSettle();

      // Today's count refreshed! 3 visits today (16, 17, 18), 1 in history (4)
      expect(find.text('Today (3)'), findsOneWidget);
      expect(find.text('History (1)'), findsOneWidget);

      // Verify shop name and Shop ID are displayed in the visit cards
      expect(find.text('ABC Seeds & Fertilizers'), findsWidgets);
      expect(find.text('Shop ID: #1'), findsOneWidget);
      expect(find.text('Shop ID: #2'), findsOneWidget);
      expect(find.text('Shop ID: #3'), findsOneWidget);
    });

    testWidgets("5. EOD submission fetches fresh authoritative visits right before submission", (WidgetTester tester) async {
      final now = DateTime.now();

      // Start with empty visits
      final mockService = MockFeServiceForCounts(mockVisits: []);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EodReportScreen(feService: mockService),
        ),
      ));
      await tester.pumpAndSettle();

      // Now visits #16, #17 (Visited) and #18 (Pending) are completed in backend
      final v16 = VisitModel(
        id: 16,
        executiveId: 2,
        executiveName: 'Ravi Kumar',
        employeeCode: 'YHS-EMP-003',
        shopId: 1,
        shopName: 'ABC Seeds & Fertilizers',
        shopLocation: 'Guntur',
        purpose: 'Scheduled Visit',
        status: 'Visited',
        visitedAt: now,
        bagsOrdered: 10,
        scheduledDate: now,
      );
      final v17 = VisitModel(
        id: 17,
        executiveId: 2,
        executiveName: 'Ravi Kumar',
        employeeCode: 'YHS-EMP-003',
        shopId: 2,
        shopName: 'Sri Ram Agro Stores',
        shopLocation: 'Vijayawada',
        purpose: 'Scheduled Visit',
        status: 'Visited',
        visitedAt: now,
        bagsOrdered: 15,
        scheduledDate: now,
      );
      final v18 = VisitModel(
        id: 18,
        executiveId: 2,
        executiveName: 'Ravi Kumar',
        employeeCode: 'YHS-EMP-003',
        shopId: 3,
        shopName: 'Krishna Agri Mart',
        shopLocation: 'Ongole',
        purpose: 'Scheduled Visit',
        status: 'Pending',
        bagsOrdered: 0,
        scheduledDate: now,
      );

      mockService.mockVisits = [v16, v17, v18];

      // Submit EOD
      final submitButton = find.widgetWithText(ElevatedButton, 'Submit EOD Report');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify that _submitEod fetched the fresh visits: 2 completed, 1 pending, 25 bags
      expect(mockService.submitEodCalls, equals(1));
      expect(mockService.lastCompletedSubmitted, equals(2));
      expect(mockService.lastPendingSubmitted, equals(1));
      expect(mockService.lastBagsSubmitted, equals(25));
    });
  });
}
