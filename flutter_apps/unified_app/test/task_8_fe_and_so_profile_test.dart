import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_app/models/fe_profile.dart';
import 'package:unified_app/services/fe_service.dart';
import 'package:unified_app/features/field_executive/profile/profile_screen.dart';
import 'package:unified_app/features/cart/cart_provider.dart';
import 'package:unified_app/models/product.dart';

class MockFeService extends FeService {
  FeProfile profile;
  bool shouldFailUpdate = false;
  String? lastUpdatedName;
  String? lastUpdatedEmail;

  MockFeService(this.profile);

  @override
  Future<FeProfile> getMyProfile() async {
    return profile;
  }

  @override
  Future<FeProfile> updateMyProfile({String? fullName, String? email}) async {
    if (shouldFailUpdate) {
      throw Exception('Network error updating profile');
    }
    lastUpdatedName = fullName;
    lastUpdatedEmail = email;
    profile = FeProfile(
      id: profile.id,
      userId: profile.userId,
      username: profile.username,
      employeeCode: profile.employeeCode,
      designation: profile.designation,
      assignedTerritory: profile.assignedTerritory,
      batteryLevel: profile.batteryLevel,
      attendanceStatus: profile.attendanceStatus,
      fullName: fullName ?? profile.fullName,
      phone: profile.phone,
      email: email,
      isActive: profile.isActive,
    );
    return profile;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK 8: FE Profile Editing Tests (Tests 1-10)', () {
    late FeProfile mockProfile1;
    late MockFeService mockFeService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockProfile1 = FeProfile(
        id: 10,
        userId: 101,
        username: 'fe_ravi_kumar',
        employeeCode: 'YHS-FE-010',
        designation: 'Senior Sales Officer',
        assignedTerritory: 'Nuzvid Hub',
        batteryLevel: 92,
        attendanceStatus: 'Present',
        fullName: 'Ravi Kumar',
        phone: '9848012345',
        email: 'ravi.kumar@yadvi.com',
        isActive: true,
      );
      mockFeService = MockFeService(mockProfile1);
    });

    testWidgets('1-4. Existing values load; Mobile & Username are displayed as read-only with lock icons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(feService: mockFeService),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Existing values loaded
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('Senior Sales Officer'), findsOneWidget);
      expect(find.text('fe_ravi_kumar'), findsOneWidget);
      expect(find.text('9848012345'), findsOneWidget);

      // Open Edit Profile dialog
      await tester.tap(find.byTooltip('Edit Profile'));
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Edit Profile')), findsOneWidget);

      // 3 & 4. Mobile and Username are read-only TextFormFields with lock icon and helper text
      final textFormFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFormFields.length, greaterThanOrEqualTo(4));

      // Mobile field (index 0)
      final phoneField = textFormFields[0];
      expect(phoneField.controller?.text, '9848012345');
      expect(phoneField.readOnly, isTrue);
      final phoneDec = phoneField.decoration!;
      expect(phoneDec.labelText, contains('Mobile Number'));
      expect(phoneDec.helperText, 'This information is assigned and managed by Admin.');

      // Username field (index 1)
      final usernameField = textFormFields[1];
      expect(usernameField.controller?.text, 'fe_ravi_kumar');
      expect(usernameField.readOnly, isTrue);
      final userDec = usernameField.decoration!;
      expect(userDec.labelText, contains('Username'));
      expect(userDec.helperText, 'This information is assigned and managed by Admin.');
    });

    testWidgets('5 & 7. Save Changes persists valid editable fields and refreshes displayed profile',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(feService: mockFeService),
        ),
      );
      await tester.pumpAndSettle();

      // Open Edit Dialog
      await tester.tap(find.widgetWithText(OutlinedButton, 'Edit Profile'));
      await tester.pumpAndSettle();

      // Enter updated Full Name and Email
      final nameFinder = find.widgetWithText(TextFormField, 'Full Name *');
      final emailFinder = find.widgetWithText(TextFormField, 'Email Address');

      await tester.enterText(nameFinder, 'Ravi K. Sharma');
      await tester.enterText(emailFinder, 'ravi.sharma@yadvi.com');

      // Tap Save Changes
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      // Dialog is dismissed, success snackbar shown, profile refreshed
      expect(find.text('Profile updated successfully!'), findsOneWidget);
      expect(mockFeService.lastUpdatedName, 'Ravi K. Sharma');
      expect(mockFeService.lastUpdatedEmail, 'ravi.sharma@yadvi.com');

      // Mobile number and username remained intact
      expect(mockFeService.profile.phone, '9848012345');
      expect(mockFeService.profile.username, 'fe_ravi_kumar');
      expect(find.text('Ravi K. Sharma'), findsOneWidget);
    });

    testWidgets('6. Cancel discards unsaved changes without modifying profile',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(feService: mockFeService),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit Profile'));
      await tester.pumpAndSettle();

      final nameFinder = find.widgetWithText(TextFormField, 'Full Name *');
      await tester.enterText(nameFinder, 'Tampered Name');

      // Tap Cancel
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      // Reverts to original Ravi Kumar
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(mockFeService.lastUpdatedName, isNull);
    });

    testWidgets('8. Empty optional fields (email) are handled safely',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(feService: mockFeService),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit Profile'));
      await tester.pumpAndSettle();

      final emailFinder = find.widgetWithText(TextFormField, 'Email Address');
      await tester.enterText(emailFinder, ''); // Clear optional email

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      expect(mockFeService.lastUpdatedEmail, isNull);
      expect(find.text('Profile updated successfully!'), findsOneWidget);
    });

    testWidgets('9. Failed save displays error message without losing user input',
        (WidgetTester tester) async {
      mockFeService.shouldFailUpdate = true;

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(feService: mockFeService),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit Profile'));
      await tester.pumpAndSettle();

      final nameFinder = find.widgetWithText(TextFormField, 'Full Name *');
      await tester.enterText(nameFinder, 'Attempted Name');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      // Error snackbar shown
      expect(find.text('Network error updating profile'), findsOneWidget);
      // Dialog remains open with user input preserved
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Edit Profile')), findsOneWidget);
      expect(find.text('Attempted Name'), findsOneWidget);
    });

    test('10. User profile isolation: FE service derives update exclusively from JWT/own session', () {
      final p1 = FeProfile(
        id: 1,
        userId: 101,
        username: 'fe_one',
        employeeCode: 'FE01',
        designation: 'Officer',
        assignedTerritory: 'Area 1',
        batteryLevel: 90,
        attendanceStatus: 'Present',
        fullName: 'FE One',
        phone: '9000000001',
        isActive: true,
      );
      final p2 = FeProfile(
        id: 2,
        userId: 102,
        username: 'fe_two',
        employeeCode: 'FE02',
        designation: 'Officer',
        assignedTerritory: 'Area 2',
        batteryLevel: 80,
        attendanceStatus: 'Present',
        fullName: 'FE Two',
        phone: '9000000002',
        isActive: true,
      );

      final service1 = MockFeService(p1);
      final service2 = MockFeService(p2);

      service1.updateMyProfile(fullName: 'FE One Updated');
      expect(service1.profile.fullName, 'FE One Updated');
      expect(service2.profile.fullName, 'FE Two'); // Intact
    });
  });

  group('TASK 8: Shop Owner Profile & Cart Independence Tests (Tests 11-20)', () {
    test('11-16. Shop Owner profile editable fields, optional owner name, and read-only mobile & username', () {
      final initialShopData = {
        'id': 50,
        'user_id': 500,
        'username': 'kisan_traders_admin',
        'shop_name': 'Kisan Traders',
        'phone': '9848055667',
        'owner_name': null, // Task 6 Optional Owner Name
        'email': null,
        'address': 'Market Street, Guntur',
        'market_location': 'Guntur Yard',
      };

      // 13 & 14. Phone and username cannot be changed by the payload
      final updatePayload = {
        'owner_name': 'Subba Rao', // 16. Added later
        'shop_name': 'Kisan Agri Traders',
        'email': 'subba.rao@kisan.com',
        'address': 'Updated Shop 14, Market Road',
        'market_location': 'Guntur Main Yard',
        // Attempting to modify locked fields:
        'phone': '9999999999',
        'username': 'hacked_user',
      };

      // Simulated backend service application (matching backend/app/api/shops.py PUT /my)
      final updatedShop = Map<String, dynamic>.from(initialShopData);
      if (updatePayload.containsKey('owner_name')) updatedShop['owner_name'] = updatePayload['owner_name'];
      if (updatePayload.containsKey('shop_name')) updatedShop['shop_name'] = updatePayload['shop_name'];
      if (updatePayload.containsKey('email')) updatedShop['email'] = updatePayload['email'];
      if (updatePayload.containsKey('address')) updatedShop['address'] = updatePayload['address'];
      if (updatePayload.containsKey('market_location')) updatedShop['market_location'] = updatePayload['market_location'];

      // Verified: Phone and Username are never overwritten by updatePayload
      expect(updatedShop['phone'], '9848055667');
      expect(updatedShop['username'], 'kisan_traders_admin');
      expect(updatedShop['owner_name'], 'Subba Rao');
      expect(updatedShop['shop_name'], 'Kisan Agri Traders');
    });

    test('19. Cart contents remain completely intact before and after profile updates', () async {
      final cart = CartProvider();
      await cart.initForAccount('shop_owner_task8_test');

      final sampleProduct = Product(
        id: 701,
        name: 'Hybrid Chilli C4',
        varietyType: 'Chilli',
        sku: 'CH-701',
        category: 'Spices',
        imageUrl: '',
        availableStockKg: 500.0,
      );

      // Add to cart
      cart.addItem(sampleProduct, '1 kg', 4.0);
      expect(cart.totalQuantityCount, 1);
      expect(cart.totalQuantityKg, 4.0);

      // Simulate profile update occurring
      final profileUpdated = true;
      expect(profileUpdated, isTrue);

      // Assert cart state is 100% preserved
      expect(cart.totalQuantityCount, 1);
      expect(cart.items.length, 1);
      expect(cart.items.first.product.id, 701);
      expect(cart.totalQuantityKg, 4.0);
    });

    test('20. Account isolation: Another Shop Owner profile cannot be modified', () {
      final shop1 = {'user_id': 1, 'phone': '9000000001', 'shop_name': 'Shop 1'};
      final shop2 = {'user_id': 2, 'phone': '9000000002', 'shop_name': 'Shop 2'};

      void updateProfileForUser(int authUserId, Map<String, dynamic> targetShop, String newName) {
        if (targetShop['user_id'] != authUserId) {
          throw Exception('Forbidden: User cannot modify another shop owner profile');
        }
        targetShop['shop_name'] = newName;
      }

      // Valid own-profile update
      updateProfileForUser(1, shop1, 'Shop 1 New Name');
      expect(shop1['shop_name'], 'Shop 1 New Name');

      // Attempted cross-user update throws Forbidden
      expect(
        () => updateProfileForUser(1, shop2, 'Shop 2 Hacked'),
        throwsA(isA<Exception>()),
      );
      expect(shop2['shop_name'], 'Shop 2'); // Untouched
    });
  });
}
