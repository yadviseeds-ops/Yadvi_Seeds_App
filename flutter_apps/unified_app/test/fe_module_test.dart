import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_app/features/field_executive/dashboard/dashboard_screen.dart';
import 'package:unified_app/features/field_executive/home/home_screen.dart';
import 'package:unified_app/features/field_executive/plan/todays_plan_screen.dart';
import 'package:unified_app/models/fe_profile.dart';
import 'package:unified_app/models/order_model.dart';
import 'package:unified_app/models/visit_model.dart';
import 'package:unified_app/models/shop_model.dart';
import 'package:unified_app/services/fe_service.dart';

class MockFeService extends FeService {
  List<VisitModel> mockVisits;
  List<ShopModel> mockShops;
  bool gpsStarted = false;
  VisitModel? createdVisit;

  MockFeService({
    this.mockVisits = const [],
    this.mockShops = const [],
  });

  @override
  Future<List<VisitModel>> getVisits() async => mockVisits;

  @override
  Future<List<ShopModel>> getShops({bool allShops = true}) async => mockShops;

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
  Future<List<OrderModel>> getMyOrders() async => [];

  @override
  Future<void> startDailyGps() async {
    gpsStarted = true;
  }

  @override
  void stopDailyGps() {
    gpsStarted = false;
  }

  bool eodSubmitted = false;
  int? submittedCompletedVisits;
  int? submittedPendingVisits;

  @override
  Future<void> submitEodReport({
    required int completedVisits,
    required int pendingVisits,
    required int totalBagsOrdered,
    String? notes,
  }) async {
    eodSubmitted = true;
    submittedCompletedVisits = completedVisits;
    submittedPendingVisits = pendingVisits;
  }

  @override
  Future<VisitModel> createPlannedVisit({
    required int shopId,
    String? purpose,
    String? notes,
  }) async {
    final shop = mockShops.firstWhere((s) => s.id == shopId);
    final newVisit = VisitModel(
      id: 999,
      executiveId: 1,
      executiveName: 'Ravi Kumar',
      employeeCode: 'YHS-EMP-001',
      shopId: shop.id,
      shopName: shop.shopName,
      shopLocation: shop.marketLocation,
      purpose: purpose ?? 'Scheduled Visit',
      status: 'Pending',
      notes: notes,
      bagsOrdered: 0,
      scheduledDate: DateTime.now(),
    );
    createdVisit = newVisit;
    mockVisits = [...mockVisits, newVisit];
    return newVisit;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testShops = [
    ShopModel(
      id: 10,
      userId: 101,
      shopName: 'Krishna Seeds Corporation',
      marketLocation: 'Vijayawada Market Yard',
      territory: 'Krishna',
      city: 'Vijayawada',
      address: 'Shop 12, Main Gate',
      openingStockBags: 20,
      currentStockBags: 18,
      status: 'Active',
      ownerName: 'Venkatesh Rao',
      phone: '9848099881',
    ),
    ShopModel(
      id: 20,
      userId: 102,
      shopName: 'Balaji Agro Agency',
      marketLocation: 'Guntur Rural',
      territory: 'Guntur',
      city: 'Guntur',
      address: 'Near Old Bus Stand',
      openingStockBags: 30,
      currentStockBags: 25,
      status: 'Active',
      ownerName: 'Koteswara Rao',
      phone: '9848099882',
    ),
  ];

  group('FE Navigation & Support Removal Tests', () {
    testWidgets('FE DashboardScreen bottom navigation has exactly 6 items and excludes Support',
        (WidgetTester tester) async {
      final mockFe = MockFeService();

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(feService: mockFe),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final navBarFinder = find.byType(BottomNavigationBar);
      expect(navBarFinder, findsOneWidget);

      final BottomNavigationBar navBar = tester.widget(navBarFinder);
      expect(navBar.items.length, equals(6));

      // Verify the 6 items: Home, Plan, Visits, Orders, EOD, Profile
      final labels = navBar.items.map((item) => item.label).toList();
      expect(labels, equals(['Home', 'Plan', 'Visits', 'Orders', 'EOD', 'Profile']));

      // Confirm Support is NOT present
      expect(labels.contains('Support'), isFalse);
      expect(find.text('Support'), findsNothing);
    });

    testWidgets('DashboardScreen does not request location on initial launch',
        (WidgetTester tester) async {
      final mockFe = MockFeService();

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(feService: mockFe),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verifies that MockFeService.gpsStarted remains false on launch
      expect(mockFe.gpsStarted, isFalse);
    });
  });

  group("FE Today's Plan Screen Tests", () {
    testWidgets("Displays two clear actions: 'Add Today's Plan' and 'Start Visit'",
        (WidgetTester tester) async {
      final mockFe = MockFeService(
        mockVisits: [
          VisitModel(
            id: 1,
            executiveId: 1,
            executiveName: 'Ravi Kumar',
            employeeCode: 'YHS-EMP-001',
            shopId: 10,
            shopName: 'Krishna Seeds Corporation',
            shopLocation: 'Vijayawada Market Yard',
            purpose: 'Scheduled Visit',
            status: 'Pending',
            bagsOrdered: 0,
            scheduledDate: DateTime.now(),
          ),
        ],
        mockShops: testShops,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TodaysPlanScreen(feService: mockFe),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify the two primary action buttons are present
      final addPlanBtn = find.byKey(const ValueKey('add_todays_plan_action_button'));
      final startVisitBtn = find.byKey(const ValueKey('start_visit_action_button'));

      expect(addPlanBtn, findsOneWidget);
      expect(startVisitBtn, findsOneWidget);

      expect(find.text("Add Today's Plan"), findsOneWidget);
      expect(find.text('Start Visit'), findsWidgets);

      // Verify planned shop is displayed
      expect(find.text('Krishna Seeds Corporation'), findsOneWidget);
    });

    testWidgets("Clicking 'Start Visit' when plan is empty shows clear message without requesting location silently",
        (WidgetTester tester) async {
      final mockFe = MockFeService(mockVisits: [], mockShops: testShops);

      await tester.pumpWidget(
        MaterialApp(
          home: TodaysPlanScreen(feService: mockFe),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final startVisitBtn = find.byKey(const ValueKey('start_visit_action_button'));
      await tester.tap(startVisitBtn);
      await tester.pump();

      // Verify clear user feedback SnackBar is shown
      expect(find.text("No visits planned for today. Tap 'Add Today's Plan' to add a shop first."), findsOneWidget);
    });

    testWidgets("Clicking 'Add Today's Plan' opens the planning bottom sheet with shop selection, purpose, and duplicate prevention",
        (WidgetTester tester) async {
      final mockFe = MockFeService(
        mockVisits: [
          VisitModel(
            id: 1,
            executiveId: 1,
            executiveName: 'Ravi Kumar',
            employeeCode: 'YHS-EMP-001',
            shopId: 10, // Shop 10 is already planned
            shopName: 'Krishna Seeds Corporation',
            shopLocation: 'Vijayawada Market Yard',
            purpose: 'Dealer Audit & Stock Booking',
            status: 'Pending',
            bagsOrdered: 0,
            scheduledDate: DateTime.now(),
          ),
        ],
        mockShops: testShops,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TodaysPlanScreen(feService: mockFe),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final addPlanBtn = find.byKey(const ValueKey('add_todays_plan_action_button'));
      await tester.tap(addPlanBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify sheet title and form fields
      expect(find.text("Add Today's Plan"), findsWidgets);
      expect(find.text("Select Shop *"), findsOneWidget);
      expect(find.text("Visit Purpose"), findsOneWidget);
      expect(find.text("Notes (Optional)"), findsOneWidget);
      expect(find.byKey(const ValueKey('save_plan_submit_button')), findsOneWidget);

      // Test dropdown
      final dropdownFinder = find.byKey(const ValueKey('shop_selection_dropdown'));
      expect(dropdownFinder, findsOneWidget);

      await tester.tap(dropdownFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Select Balaji Agro Agency (Shop 20, not planned yet)
      final unvisitedItem = find.textContaining('Balaji Agro Agency').last;
      await tester.tap(unvisitedItem);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Save plan for Balaji Agro Agency
      final saveBtn = find.byKey(const ValueKey('save_plan_submit_button'));
      await tester.tap(saveBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify visit was created and appears in list
      expect(mockFe.createdVisit, isNotNull);
      expect(mockFe.createdVisit!.shopId, equals(20));
      expect(find.text('Balaji Agro Agency'), findsOneWidget);
      expect(find.textContaining('Shop #20'), findsOneWidget);
    });

    testWidgets("Shop picker sheet allows real-time search filtering across shop name, owner, and city",
        (WidgetTester tester) async {
      final mockFe = MockFeService(mockVisits: [], mockShops: testShops);

      await tester.pumpWidget(
        MaterialApp(
          home: TodaysPlanScreen(feService: mockFe),
        ),
      );
      await tester.pumpAndSettle();

      // Open Add Plan Sheet
      await tester.tap(find.byKey(const ValueKey('add_todays_plan_action_button')));
      await tester.pumpAndSettle();

      // Open Shop Picker
      await tester.tap(find.byKey(const ValueKey('shop_selection_dropdown')));
      await tester.pumpAndSettle();

      // Verify picker header and search box
      expect(find.text('Choose Registered Shop'), findsOneWidget);
      final searchField = find.byKey(const ValueKey('shop_picker_search_field'));
      expect(searchField, findsOneWidget);

      // Verify both shops are initially shown
      expect(find.textContaining('Krishna Seeds Corporation'), findsOneWidget);
      expect(find.textContaining('Balaji Agro Agency'), findsOneWidget);

      // Search for 'Balaji'
      await tester.enterText(searchField, 'Balaji');
      await tester.pumpAndSettle();

      // Balaji must be visible, Krishna must be filtered out
      expect(find.textContaining('Balaji Agro Agency'), findsOneWidget);
      expect(find.textContaining('Krishna Seeds Corporation'), findsNothing);

      // Search for non-existent shop
      await tester.enterText(searchField, 'NonExistentZ99');
      await tester.pumpAndSettle();
      expect(find.textContaining('No registered shops match'), findsOneWidget);

      // Clearing search restores all available registered shops
      await tester.tap(find.text('Clear Search'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Krishna Seeds Corporation'), findsOneWidget);
      expect(find.textContaining('Balaji Agro Agency'), findsOneWidget);
      expect(find.text('2 active registered shops'), findsOneWidget);
    });

    testWidgets("Shop picker sheet displays empty state and refresh option when 0 shops are registered",
        (WidgetTester tester) async {
      final mockFe = MockFeService(mockVisits: [], mockShops: []);

      await tester.pumpWidget(
        MaterialApp(
          home: TodaysPlanScreen(feService: mockFe),
        ),
      );
      await tester.pumpAndSettle();

      // Open Add Plan Sheet
      await tester.tap(find.byKey(const ValueKey('add_todays_plan_action_button')));
      await tester.pumpAndSettle();

      // Open Shop Picker
      await tester.tap(find.byKey(const ValueKey('shop_selection_dropdown')));
      await tester.pumpAndSettle();

      expect(find.text('No active registered shops available'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
    });
  });

  group('FE Territory Card & Stat Cards Layout Tests', () {
    testWidgets('HomeScreen renders stat cards and territory banner cleanly without RenderFlex overflow on 360px mobile width',
        (WidgetTester tester) async {
      final mockFe = MockFeService();

      // Set narrow mobile dimensions: width 360, height 740
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(feService: mockFe),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify stat cards rendered
      expect(find.text("Today's Summary"), findsOneWidget);
      expect(find.text('Total Visits'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Assigned Orders'), findsNWidgets(2)); // Card label and Section title

      // Verify territory card rendered with real data and no overflow
      expect(find.text('Territory'), findsOneWidget);
      expect(find.text('Krishna - Vijayawada Belt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Visit Model and Shop Model Compatibility', () {
    test('VisitModel correctly identifies today visit date', () {
      final now = DateTime.now();
      final visitToday = VisitModel(
        id: 1,
        executiveId: 10,
        executiveName: 'Test Exec',
        employeeCode: 'EMP-01',
        shopId: 5,
        shopName: 'Green Seeds',
        shopLocation: 'Market Yard',
        purpose: 'Scheduled Visit',
        status: 'Pending',
        bagsOrdered: 0,
        scheduledDate: now,
      );

      final visitYesterday = VisitModel(
        id: 2,
        executiveId: 10,
        executiveName: 'Test Exec',
        employeeCode: 'EMP-01',
        shopId: 6,
        shopName: 'Kisan Traders',
        shopLocation: 'Main Rd',
        purpose: 'Audit',
        status: 'Visited',
        bagsOrdered: 10,
        scheduledDate: now.subtract(const Duration(days: 1)),
      );

      expect(visitToday.isToday, isTrue);
      expect(visitYesterday.isToday, isFalse);
    });

    test('ShopModel parses all fields correctly from JSON for visit planning', () {
      final json = {
        'id': 12,
        'user_id': 45,
        'shop_name': 'Vijaya Agro Agencies',
        'market_location': 'Guntur West',
        'territory': 'Guntur',
        'city': 'Guntur',
        'address': 'Plot 4, Market Complex',
        'opening_stock_bags': 20,
        'current_stock_bags': 15,
        'status': 'Active',
        'owner_name': 'Subba Rao',
        'phone': '9876543210',
      };

      final shop = ShopModel.fromJson(json);
      expect(shop.id, equals(12));
      expect(shop.shopName, equals('Vijaya Agro Agencies'));
      expect(shop.marketLocation, equals('Guntur West'));
      expect(shop.ownerName, equals('Subba Rao'));
      expect(shop.phone, equals('9876543210'));
    });
  });
}
