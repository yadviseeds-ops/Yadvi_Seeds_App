import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/features/admin/employees/employees_screen.dart';
import 'package:unified_app/features/admin/employees/employee_profile_screen.dart';
import 'package:unified_app/models/employee_model.dart';
import 'package:unified_app/providers/admin_provider.dart';
import 'package:unified_app/providers/auth_provider.dart';

class MockAdminProvider extends AdminProvider {
  final List<EmployeeModel> mockEmployees;

  MockAdminProvider(this.mockEmployees);

  @override
  List<EmployeeModel> get employees => mockEmployees;

  @override
  bool get isLoadingEmployees => false;

  @override
  Future<void> fetchEmployees() async {
    // No-op for tests
  }

  @override
  Future<EmployeeModel?> fetchEmployeeDetails(int employeeId) async {
    final matches = mockEmployees.where((e) => e.id == employeeId);
    if (matches.isNotEmpty) return matches.first;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testEmployees = [
    EmployeeModel(
      id: 101,
      userId: 1,
      employeeCode: 'EMP-101',
      designation: 'Senior Field Executive',
      assignedTerritory: 'Guntur Rural',
      currentLat: 16.3067,
      currentLng: 80.4365,
      batteryLevel: 85,
      attendanceStatus: 'Present',
      distanceCoveredKm: 14.5,
      lastLocationUpdate: DateTime(2026, 10, 24, 14, 30),
      fullName: 'Ramesh Kumar',
      phone: '9848011223',
      email: 'ramesh.k@yadviseeds.com',
      isActive: true,
    ),
    EmployeeModel(
      id: 102,
      userId: 2,
      employeeCode: 'EMP-102',
      designation: 'Field Sales Officer',
      assignedTerritory: 'Tenali East',
      currentLat: null,
      currentLng: null,
      batteryLevel: 15,
      attendanceStatus: 'Absent',
      distanceCoveredKm: 0.0,
      lastLocationUpdate: null,
      fullName: 'Suresh Patel',
      phone: '9848022334',
      email: null,
      isActive: false,
    ),
    EmployeeModel(
      id: 103,
      userId: 3,
      employeeCode: 'EMP-103',
      designation: 'Field Sales Executive',
      assignedTerritory: 'Vijayawada West',
      currentLat: 16.5062,
      currentLng: 80.6480,
      batteryLevel: 90,
      attendanceStatus: 'In Field',
      distanceCoveredKm: 22.0,
      lastLocationUpdate: DateTime(2026, 10, 24, 15, 0),
      fullName: 'Venkat Rao',
      phone: '9848033445',
      email: 'venkat.r@yadviseeds.com',
      isActive: true,
    ),
  ];

  group('Field Executive List & Profile View Tests', () {
    testWidgets('Active FE names remain visible in list, while inactive FE is excluded from active directory',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProvider(testEmployees);

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

      // Verify active FE names are rendered and visible
      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('Venkat Rao'), findsOneWidget);
      expect(find.text('EMP-101 • Senior Field Executive'), findsOneWidget);
      expect(find.text('EMP-103 • Field Sales Executive'), findsOneWidget);

      // Verify inactive FE is excluded from directory list
      expect(find.text('Suresh Patel'), findsNothing);
      expect(find.text('EMP-102 • Field Sales Officer'), findsNothing);
    });

    testWidgets('Battery icon and battery text/status are completely absent from FE list',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProvider(testEmployees);

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

      // Verify no battery icons exist anywhere on the screen
      expect(find.byIcon(Icons.battery_charging_full), findsNothing);
      expect(find.byIcon(Icons.battery_alert), findsNothing);
      expect(find.byIcon(Icons.battery_full), findsNothing);
      expect(find.byIcon(Icons.battery_std), findsNothing);

      // Verify no battery percentage text exists
      expect(find.textContaining('Battery'), findsNothing);
      expect(find.textContaining('85%'), findsNothing);
      expect(find.textContaining('15%'), findsNothing);

      // But distance covered and attendance status ARE preserved for active FEs
      expect(find.text('14.5 KM Covered'), findsOneWidget);
      expect(find.text('22.0 KM Covered'), findsOneWidget);
      expect(find.text('Present'), findsOneWidget);
      expect(find.text('In Field'), findsOneWidget);
    });

    testWidgets('Tapping an active FE item opens dedicated EmployeeProfileScreen with correct ID',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProvider(testEmployees);

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

      // Tap on Ramesh Kumar's card
      final rameshTap = find.byKey(const ValueKey('fe_tap_101'));
      expect(rameshTap, findsOneWidget);
      await tester.tap(rameshTap);
      await tester.pumpAndSettle();

      // Verify EmployeeProfileScreen opened
      expect(find.byType(EmployeeProfileScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('fe_profile_name')), findsOneWidget);
      expect(find.text('Ramesh Kumar'), findsNWidgets(2)); // AppBar title + card name
      expect(find.text('EMP-101'), findsOneWidget);
      expect(find.text('9848011223'), findsOneWidget);
      expect(find.text('ramesh.k@yadviseeds.com'), findsOneWidget);
      expect(find.text('Guntur Rural'), findsOneWidget);
      expect(find.text('Active Account'), findsOneWidget);
      expect(find.text('16.30670, 80.43650'), findsOneWidget);

      // Verify battery indicators are absent on profile screen too
      expect(find.byIcon(Icons.battery_charging_full), findsNothing);
      expect(find.textContaining('Battery'), findsNothing);

      // Verify back navigation works
      final backButton = find.byKey(const ValueKey('fe_profile_back_button'));
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify returned to FE list
      expect(find.byType(EmployeesScreen), findsOneWidget);
      expect(find.byType(EmployeeProfileScreen), findsNothing);
    });

    testWidgets('EmployeeProfileScreen correctly displays details and Inactive Account badge for an inactive employee',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProvider(testEmployees);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminProvider>.value(value: mockProvider),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: MaterialApp(
            home: EmployeeProfileScreen(
              employeeId: 102,
              initialEmployee: testEmployees[1],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Suresh Patel'), findsNWidgets(2));
      expect(find.text('EMP-102'), findsOneWidget);
      expect(find.text('Inactive Account'), findsOneWidget);
      expect(find.text('Tenali East'), findsOneWidget);
      expect(find.text('Not provided'), findsOneWidget); // For email
      expect(find.text('No GPS fix recorded'), findsOneWidget);
      expect(find.text('Never updated'), findsOneWidget);
      expect(find.textContaining('Battery'), findsNothing);
    });

    testWidgets('EmployeeProfileScreen displays error state when employee ID not found',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProvider([]); // empty

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminProvider>.value(value: mockProvider),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(
            home: EmployeeProfileScreen(
              employeeId: 9999,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Field Executive with ID #9999 not found.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });
  });
}
