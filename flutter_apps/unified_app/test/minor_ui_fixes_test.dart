import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/features/admin/main_scaffold.dart';
import 'package:unified_app/features/admin/shops/shops_screen.dart';
import 'package:unified_app/features/field_executive/home/home_screen.dart';
import 'package:unified_app/models/dashboard_model.dart';
import 'package:unified_app/models/fe_profile.dart';
import 'package:unified_app/models/order_model.dart';
import 'package:unified_app/models/shop_model.dart';
import 'package:unified_app/models/visit_model.dart';
import 'package:unified_app/providers/admin_provider.dart';
import 'package:unified_app/providers/auth_provider.dart';
import 'package:unified_app/services/fe_service.dart';

class MockFeService extends FeService {
  final FeProfile? mockProfile;
  MockFeService({this.mockProfile});

  @override
  Future<FeProfile> getMyProfile() async {
    return mockProfile ??
        FeProfile(
          id: 1,
          userId: 10,
          employeeCode: 'EMP001',
          fullName: 'Ramesh Patel',
          email: 'ramesh@example.com',
          phone: '9876543210',
          designation: 'Senior Field Executive',
          assignedTerritory: 'Indore Central',
          batteryLevel: 95,
          attendanceStatus: 'Present',
          isActive: true,
        );
  }

  @override
  Future<List<VisitModel>> getVisits() async => [];

  @override
  Future<List<OrderModel>> getMyOrders() async => [];
}

class MockAdminProviderForShops extends AdminProvider {
  final List<ShopModel> _mockShops;

  MockAdminProviderForShops(this._mockShops);

  @override
  List<ShopModel> get shops => _mockShops;

  @override
  DashboardDataModel? get dashboardData => null;

  @override
  bool get isLoadingEod => false;
  @override
  bool get isLoadingEmployees => false;
  @override
  bool get isLoadingShops => false;
  @override
  bool get isLoadingProducts => false;
  @override
  bool get isLoadingDashboard => false;

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('YADVI Minor UI Fixes Tests', () {
    testWidgets(
      '1. FE Home Screen: Back button and Good Day greeting do not overlap',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockFe = MockFeService();

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(feService: mockFe, onBack: () {}),
          ),
        );
        await tester.pumpAndSettle();

        final backBtnFinder = find.byTooltip('Back');
        expect(backBtnFinder, findsOneWidget);

        final greetingFinder = find.text('Good Day, Ramesh');
        expect(greetingFinder, findsOneWidget);

        final Rect backBtnRect = tester.getRect(backBtnFinder);
        final Rect greetingRect = tester.getRect(greetingFinder);

        // The greeting must be strictly below the back button toolbar area
        expect(
          greetingRect.top,
          greaterThanOrEqualTo(backBtnRect.bottom),
          reason:
              'Greeting top (${greetingRect.top}) should be below back button bottom (${backBtnRect.bottom})',
        );
        // No intersection
        expect(
          backBtnRect.overlaps(greetingRect),
          isFalse,
          reason: 'Back button should not overlap with greeting text',
        );
      },
    );

    testWidgets(
      '2. Admin Module: Bottom navigation bar shows Dealers label instead of Shop Owners',
      (WidgetTester tester) async {
        final mockProvider = MockAdminProviderForShops([]);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>(
                create: (_) => AuthProvider(),
              ),
              ChangeNotifierProvider<AdminProvider>.value(value: mockProvider),
            ],
            child: const MaterialApp(home: AdminMainScaffold()),
          ),
        );
        await tester.pumpAndSettle();

        // Navigation bar must have 'Dealers'
        final navBarDealers = find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Dealers'),
        );
        expect(navBarDealers, findsOneWidget);

        // 'Shop Owners' must NOT be present in navigation bar
        final navBarShopOwners = find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Shop Owners'),
        );
        expect(navBarShopOwners, findsNothing);
      },
    );

    testWidgets(
      '3. Admin Dealer Network: Zero Balance filter is retained and Fully Repaid is removed',
      (WidgetTester tester) async {
        final List<ShopModel> testShops = [
          ShopModel(
            id: 1,
            userId: 101,
            shopName: 'Shree Seeds',
            ownerName: 'Ramesh',
            phone: '9876543210',
            marketLocation: 'Indore',
            address: 'Main Road',
            openingStockBags: 0,
            currentStockBags: 0,
            status: 'Active',
            debtTaken: 50000.0,
            debtRepaid: 20000.0,
            totalBalance: 30000.0, // Outstanding
          ),
          ShopModel(
            id: 2,
            userId: 102,
            shopName: 'Bhavani Agri Store',
            ownerName: 'Suresh',
            phone: '9876543211',
            marketLocation: 'Bhopal',
            address: 'Mandi Gate',
            openingStockBags: 0,
            currentStockBags: 0,
            status: 'Active',
            debtTaken: 40000.0,
            debtRepaid: 40000.0,
            totalBalance: 0.0, // Zero Balance
          ),
        ];

        final mockProvider = MockAdminProviderForShops(testShops);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AdminProvider>.value(
              value: mockProvider,
              child: const ShopsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Filter chips checks
        expect(find.text('All Dealers (2)'), findsOneWidget);
        expect(find.text('Outstanding (1)'), findsOneWidget);
        expect(find.text('Zero Balance (1)'), findsOneWidget);

        // Redundant 'Fully Repaid' chip must not exist in UI
        expect(find.textContaining('Fully Repaid'), findsNothing);

        // Tapping Zero Balance filter filters to Bhavani Agri Store
        await tester.tap(find.text('Zero Balance (1)'));
        await tester.pumpAndSettle();

        expect(find.text('Bhavani Agri Store'), findsOneWidget);
        expect(find.text('Shree Seeds'), findsNothing);
      },
    );
  });
}
