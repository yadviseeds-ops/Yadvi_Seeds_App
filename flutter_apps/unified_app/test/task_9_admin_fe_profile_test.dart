import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/features/admin/employees/employees_screen.dart';
import 'package:unified_app/features/admin/employees/employee_profile_screen.dart';
import 'package:unified_app/models/employee_model.dart';
import 'package:unified_app/providers/admin_provider.dart';
import 'package:unified_app/providers/auth_provider.dart';

class MockAdminProviderForTask9 extends AdminProvider {
  final List<EmployeeModel> mockEmployees;

  MockAdminProviderForTask9(this.mockEmployees);

  @override
  List<EmployeeModel> get employees => mockEmployees;

  @override
  bool get isLoadingEmployees => false;

  @override
  Future<void> fetchEmployees() async {}

  @override
  Future<EmployeeModel?> fetchEmployeeDetails(int employeeId) async {
    final matches = mockEmployees.where((e) => e.id == employeeId);
    if (matches.isNotEmpty) return matches.first;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testShops = [
    AssignedShopModel(
      id: 11,
      shopName: 'Sri Sai Agri Agency',
      marketLocation: 'Guntur Market Yard',
      address: 'Shop 45, Commercial Complex, Guntur',
      status: 'Active',
      phone: '9848011223',
      ownerName: 'Venkata Rao',
    ),
    AssignedShopModel(
      id: 12,
      shopName: 'Balaji Seeds & Fertilizers',
      marketLocation: 'Tenali Market',
      address: 'Main Bazaar Road, Tenali',
      status: 'Active',
      phone: '9848033445',
      ownerName: 'Subba Rao',
    ),
  ];

  final feWithShopsAndVisits = EmployeeModel(
    id: 201,
    userId: 21,
    username: 'ravi_kumar_fe',
    employeeCode: 'EMP-201',
    designation: 'Senior Field Sales Officer',
    assignedTerritory: 'Guntur & Tenali Zone',
    currentLat: 16.3067,
    currentLng: 80.4365,
    batteryLevel: 90,
    attendanceStatus: 'Present',
    distanceCoveredKm: 18.5,
    lastLocationUpdate: DateTime(2026, 10, 31, 10, 30),
    fullName: 'Ravi Kumar',
    phone: '9848099887',
    email: 'ravi.k@yadviseeds.com',
    isActive: true,
    assignedShops: testShops,
    totalAssignedShops: 2,
    completedVisits: 14,
    pendingVisits: 3,
  );

  final feWithZeroShopsAndVisits = EmployeeModel(
    id: 202,
    userId: 22,
    username: 'new_joiner_fe',
    employeeCode: 'EMP-202',
    designation: 'Trainee Officer',
    assignedTerritory: 'Unassigned',
    currentLat: null,
    currentLng: null,
    batteryLevel: 100,
    attendanceStatus: 'Present',
    distanceCoveredKm: 0.0,
    lastLocationUpdate: null,
    fullName: 'Anil Verma',
    phone: '9848012345',
    email: null,
    isActive: true,
    assignedShops: const [],
    totalAssignedShops: 0,
    completedVisits: 0,
    pendingVisits: 0,
  );

  group('Task 9: Admin FE Profile Assigned Shops and Visit Metrics Tests', () {
    testWidgets('1. Admin opens FE profile and verifies assigned shops and visit metrics',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderForTask9([feWithShopsAndVisits]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminProvider>.value(value: mockProvider),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(
            home: EmployeesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify FE card exists in FE list
      expect(find.byKey(const ValueKey('fe_tap_201')), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);

      // Tap on FE card to open FE profile
      await tester.tap(find.byKey(const ValueKey('fe_tap_201')));
      await tester.pumpAndSettle();

      // Verify EmployeeProfileScreen opened
      expect(find.byType(EmployeeProfileScreen), findsOneWidget);

      // Verify FE Profile details
      expect(find.byKey(const ValueKey('fe_profile_name')), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsNWidgets(2)); // AppBar + Card
      expect(find.text('EMP-201'), findsOneWidget);
      expect(find.text('ravi_kumar_fe'), findsOneWidget);
      expect(find.text('Senior Field Sales Officer'), findsNWidgets(2));
      expect(find.text('Guntur & Tenali Zone'), findsOneWidget);

      // Verify Visit Performance metrics
      expect(find.text('Completed Visits'), findsOneWidget);
      expect(find.byKey(const ValueKey('fe_profile_completed_visits')), findsOneWidget);
      expect(find.text('14'), findsOneWidget); // 14 completed visits

      expect(find.text('Pending Visits'), findsOneWidget);
      expect(find.byKey(const ValueKey('fe_profile_pending_visits')), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // 3 pending visits

      // Verify Assigned Shops Section & Total Count
      expect(find.text('Assigned Shops'), findsOneWidget);
      expect(find.byKey(const ValueKey('fe_profile_total_assigned_shops')), findsOneWidget);
      expect(find.text('Total Assigned Shops: 2'), findsOneWidget);

      // Verify individual assigned shops are rendered
      expect(find.byKey(const ValueKey('fe_assigned_shop_11')), findsOneWidget);
      expect(find.text('Sri Sai Agri Agency'), findsOneWidget);
      expect(find.text('#11'), findsOneWidget);
      expect(find.textContaining('Guntur Market Yard'), findsOneWidget);
      expect(find.text('Owner: Venkata Rao'), findsOneWidget);

      expect(find.byKey(const ValueKey('fe_assigned_shop_12')), findsOneWidget);
      expect(find.text('Balaji Seeds & Fertilizers'), findsOneWidget);
      expect(find.text('#12'), findsOneWidget);
      expect(find.textContaining('Tenali Market'), findsOneWidget);
      expect(find.text('Owner: Subba Rao'), findsOneWidget);

      // Verify Back Navigation
      final backButton = find.byKey(const ValueKey('fe_profile_back_button'));
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Returned safely to EmployeesScreen
      expect(find.byType(EmployeesScreen), findsOneWidget);
      expect(find.byType(EmployeeProfileScreen), findsNothing);
    });

    testWidgets('2. Admin opens FE profile with 0 assigned shops and 0 visits displays zero counts and empty state',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderForTask9([feWithZeroShopsAndVisits]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminProvider>.value(value: mockProvider),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: MaterialApp(
            home: EmployeeProfileScreen(
              employeeId: 202,
              initialEmployee: feWithZeroShopsAndVisits,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Anil Verma'), findsNWidgets(2));
      expect(find.text('EMP-202'), findsOneWidget);

      // Zero counts for visits
      expect(find.byKey(const ValueKey('fe_profile_completed_visits')), findsOneWidget);
      expect(find.text('0'), findsNWidgets(2)); // Completed=0, Pending=0

      // Total assigned shops: 0
      expect(find.text('Total Assigned Shops: 0'), findsOneWidget);
      expect(find.text('No shops currently assigned to this executive.'), findsOneWidget);
    });
  });
}
