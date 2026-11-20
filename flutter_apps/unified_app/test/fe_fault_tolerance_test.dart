import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_app/features/field_executive/home/home_screen.dart';
import 'package:unified_app/features/field_executive/eod/eod_report_screen.dart';
import 'package:unified_app/features/field_executive/orders/orders_screen.dart';
import 'package:unified_app/models/fe_profile.dart';
import 'package:unified_app/models/order_model.dart';
import 'package:unified_app/models/visit_model.dart';
import 'package:unified_app/services/fe_service.dart';

class MockFailingOrdersFeService extends FeService {
  @override
  Future<FeProfile> getMyProfile() async => FeProfile(
        id: 1,
        userId: 1,
        employeeCode: 'YHS-EMP-001',
        designation: 'Senior Field Executive',
        assignedTerritory: 'Krishna - Vijayawada Belt',
        batteryLevel: 90,
        attendanceStatus: 'Present',
        fullName: 'Ravi Kumar',
        phone: '9848011223',
        email: 'ravi@yadviseeds.com',
        isActive: true,
      );

  @override
  Future<List<VisitModel>> getVisits() async => [
        VisitModel(
          id: 101,
          executiveId: 1,
          executiveName: 'Ravi Kumar',
          employeeCode: 'YHS-EMP-001',
          shopId: 10,
          shopName: 'Sri Balaji Seeds',
          shopLocation: 'Guntur Rural',
          purpose: 'Order collection',
          status: 'Visited',
          bagsOrdered: 5,
          scheduledDate: DateTime.now(),
        ),
      ];

  @override
  Future<List<OrderModel>> getMyOrders() async {
    throw Exception('Failed to load orders: 500');
  }

  @override
  Future<void> submitEodReport({
    required int completedVisits,
    required int pendingVisits,
    required int totalBagsOrdered,
    String? notes,
  }) async {}

  @override
  void stopDailyGps() {}
}

void main() {
  group('FE Fault Tolerance & Decoupling Tests', () {
    testWidgets('HomeScreen remains functional when orders API returns 500', (tester) async {
      final mockService = MockFailingOrdersFeService();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(feService: mockService),
        ),
      );

      // Initial loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      // Home Screen must NOT crash into offline error or display orders error
      expect(find.byIcon(Icons.wifi_off), findsNothing);
      expect(find.text('Failed to load orders: 500'), findsNothing);

      // Profile greeting and designation must render
      expect(find.text('Good Day, Ravi'), findsOneWidget);
      expect(find.text('Senior Field Executive'), findsOneWidget);
      expect(find.text('Krishna - Vijayawada Belt'), findsOneWidget);

      // Today visits must render properly
      expect(find.text('Sri Balaji Seeds'), findsOneWidget);
      expect(find.text('Total Visits'), findsOneWidget);
      expect(find.text('Assigned Orders'), findsNWidgets(2));
    });

    testWidgets('EodReportScreen remains functional when orders API returns 500', (tester) async {
      final mockService = MockFailingOrdersFeService();

      await tester.pumpWidget(
        MaterialApp(
          home: EodReportScreen(feService: mockService),
        ),
      );

      // Initial loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      // EOD Screen must NOT show "Failed to load orders: 500"
      expect(find.text('Failed to load orders: 500'), findsNothing);

      // Header, profile name, and visit summary must render
      expect(find.text('End of Day Report'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('Visit Summary'), findsOneWidget);
      expect(find.textContaining('Sri Balaji Seeds'), findsOneWidget);
      expect(find.text('Submit EOD Report'), findsOneWidget);
    });

    testWidgets('OrdersScreen isolates orders 500 error with retry button', (tester) async {
      final mockService = MockFailingOrdersFeService();

      await tester.pumpWidget(
        MaterialApp(
          home: OrdersScreen(feService: mockService),
        ),
      );

      await tester.pumpAndSettle();

      // Displays error and retry button
      expect(find.text('Failed to load orders: 500'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsWidgets);
    });
  });
}
