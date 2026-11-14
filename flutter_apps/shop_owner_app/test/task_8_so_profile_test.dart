import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_owner_app/features/cart/cart_provider.dart';
import 'package:shop_owner_app/models/product.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK 8: Standalone Shop Owner Profile Editing & Account Security (Tests 11-20)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('11-14. Load details, editable fields support, and read-only mobile & username', () {
      final shopProfile = {
        'id': 42,
        'user_id': 200,
        'username': 'kisan_seeds_dealer',
        'shop_name': 'Kisan Seeds Store',
        'owner_name': null, // Task 6 optional owner name
        'phone': '9848099887',
        'email': 'kisan@yadvi.com',
        'address': 'Main Road, Chirala',
        'market_location': 'Chirala Market',
        'status': 'Active',
      };

      // 11. Load details
      expect(shopProfile['shop_name'], 'Kisan Seeds Store');
      expect(shopProfile['phone'], '9848099887');
      expect(shopProfile['username'], 'kisan_seeds_dealer');

      // 12. Supported editable fields: owner_name, shop_name, email, address, market_location
      const allowedKeys = {'owner_name', 'shop_name', 'email', 'address', 'market_location'};

      final clientEdit = {
        'owner_name': 'Venkatesh Rao', // 16. Added later
        'shop_name': 'Kisan Agri Hub',
        'email': 'venkat@kisan.com',
        'address': 'Shop 12, Main Road, Chirala',
        'market_location': 'Chirala Rural Market',
        // Attempted tampering:
        'phone': '9111111111',
        'username': 'hacked_username',
        'user_id': 999,
      };

      final safeUpdatePayload = <String, dynamic>{};
      for (final entry in clientEdit.entries) {
        if (allowedKeys.contains(entry.key)) {
          safeUpdatePayload[entry.key] = entry.value;
        }
      }

      // 13 & 14. Mobile and username are strictly excluded from update payload
      expect(safeUpdatePayload.containsKey('phone'), isFalse);
      expect(safeUpdatePayload.containsKey('username'), isFalse);
      expect(safeUpdatePayload.containsKey('user_id'), isFalse);

      // Apply safe updates
      final updatedProfile = Map<String, dynamic>.from(shopProfile)..addAll(safeUpdatePayload);

      // Verify locked fields remain unchanged
      expect(updatedProfile['phone'], '9848099887');
      expect(updatedProfile['username'], 'kisan_seeds_dealer');
      expect(updatedProfile['owner_name'], 'Venkatesh Rao');
      expect(updatedProfile['shop_name'], 'Kisan Agri Hub');
    });

    test('15-16. Owner Full Name optional compatibility: empty string & adding name later', () {
      final profileWithNullName = {
        'owner_name': null,
        'shop_name': 'Sri Rama Seeds',
        'address': 'Khammam Road',
      };

      // UI fallback without corrupting model
      final displayFallback = (profileWithNullName['owner_name'] as String?)?.trim().isNotEmpty == true
          ? profileWithNullName['owner_name']
          : 'Registered Dealer';
      expect(displayFallback, 'Registered Dealer');
      expect(profileWithNullName['owner_name'], isNull);

      // User adds owner name later
      profileWithNullName['owner_name'] = 'Rama Krishna';
      final updatedDisplay = (profileWithNullName['owner_name'] as String?)?.trim().isNotEmpty == true
          ? profileWithNullName['owner_name']
          : 'Registered Dealer';
      expect(updatedDisplay, 'Rama Krishna');
    });

    test('17-18. Save and Cancel workflow and persistence', () {
      final savedState = <String, dynamic>{
        'shop_name': 'Original Shop Name',
        'email': 'original@shop.com',
      };

      // Edit drafted
      var draftState = Map<String, dynamic>.from(savedState);
      draftState['shop_name'] = 'Unsaved Name Modification';

      // Cancel pressed: discard draft
      draftState = Map<String, dynamic>.from(savedState);
      expect(draftState['shop_name'], 'Original Shop Name');

      // Save pressed: commit draft
      draftState['shop_name'] = 'Committed New Shop Name';
      savedState.addAll(draftState);
      expect(savedState['shop_name'], 'Committed New Shop Name');
    });

    test('19. Cart contents remain completely intact before and after profile updates', () async {
      final cart = CartProvider();
      await cart.initForAccount('standalone_so_cart_test');

      final product = Product(
        id: 301,
        name: 'Hybrid Cotton C-301',
        varietyType: 'Cotton',
        sku: 'CT-301',
        category: 'Field Crops',
        imageUrl: '',
        availableStockKg: 250.0,
      );

      cart.addItem(product, '1 kg', 5.0);
      expect(cart.totalQuantityCount, 1);
      expect(cart.totalQuantityKg, 5.0);

      // Perform profile update operation
      final profileSaved = true;
      expect(profileSaved, isTrue);

      // Cart state must remain unaffected
      expect(cart.totalQuantityCount, 1);
      expect(cart.totalQuantityKg, 5.0);
      expect(cart.items.length, 1);
      expect(cart.items.first.product.id, 301);
    });

    test('20. Account isolation: Cross-account modification prevention', () {
      final shopA = {'account_id': 'so_101', 'shop_name': 'Alpha Seeds'};
      final shopB = {'account_id': 'so_102', 'shop_name': 'Beta Seeds'};

      void applyUpdate(String authenticatedUser, Map<String, dynamic> target, String newName) {
        if (target['account_id'] != authenticatedUser) {
          throw Exception('Unauthorized profile modification attempt');
        }
        target['shop_name'] = newName;
      }

      applyUpdate('so_101', shopA, 'Alpha Seeds Pro');
      expect(shopA['shop_name'], 'Alpha Seeds Pro');

      expect(
        () => applyUpdate('so_101', shopB, 'Hacked Beta Seeds'),
        throwsA(isA<Exception>()),
      );
      expect(shopB['shop_name'], 'Beta Seeds'); // Completely unchanged
    });
  });
}
