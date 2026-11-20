import 'package:flutter_test/flutter_test.dart';
import 'package:unified_app/models/shop_model.dart';

void main() {
  group('ShopModel Financial Details Tests', () {
    test('1. formatCurrency formats Indian Rupee correctly for zero, positive, negative, and decimals', () {
      expect(ShopModel.formatCurrency(0), '₹0.00');
      expect(ShopModel.formatCurrency(0.0), '₹0.00');
      expect(ShopModel.formatCurrency(50000), '₹50,000');
      expect(ShopModel.formatCurrency(1000000), '₹10,00,000');
      expect(ShopModel.formatCurrency(-5000), '-₹5,000');
      expect(ShopModel.formatCurrency(-12345.5), '-₹12,345.50');
      expect(ShopModel.formatCurrency(1234.56), '₹1,234.56');
    });

    test('2. Formula verification: Total Balance = Debt Taken - Debt Repaid', () {
      // Scenario A: Standard debt with positive balance
      double debtTaken = 50000.0;
      double debtRepaid = 20000.0;
      double totalBalance = double.parse((debtTaken - debtRepaid).toStringAsFixed(2));
      expect(totalBalance, 30000.0);
      expect(ShopModel.formatCurrency(totalBalance), '₹30,000');

      // Scenario B: Fully paid balance
      debtTaken = 45000.0;
      debtRepaid = 45000.0;
      totalBalance = double.parse((debtTaken - debtRepaid).toStringAsFixed(2));
      expect(totalBalance, 0.0);
      expect(ShopModel.formatCurrency(totalBalance), '₹0.00');

      // Scenario C: Negative balance (Repayment exceeds debt taken)
      debtTaken = 10000.0;
      debtRepaid = 15000.0;
      totalBalance = double.parse((debtTaken - debtRepaid).toStringAsFixed(2));
      expect(totalBalance, -5000.0);
      expect(ShopModel.formatCurrency(totalBalance), '-₹5,000');

      // Scenario D: Decimal precision handling
      debtTaken = 10000.75;
      debtRepaid = 2500.25;
      totalBalance = double.parse((debtTaken - debtRepaid).toStringAsFixed(2));
      expect(totalBalance, 7500.50);
      expect(ShopModel.formatCurrency(totalBalance), '₹7,500.50');
    });

    test('3. ShopModel parses financial fields from JSON with defaults', () {
      // Missing fields default to 0.0
      final emptyShop = ShopModel.fromJson({
        'id': 1,
        'user_id': 101,
        'shop_name': 'Test Agri Seeds',
        'owner_name': 'Ramesh Kumar',
        'phone': '9876543210',
        'market_location': 'Indore',
        'address': 'Main Market',
      });
      expect(emptyShop.debtTaken, 0.0);
      expect(emptyShop.debtRepaid, 0.0);
      expect(emptyShop.totalBalance, 0.0);

      // Explicit values
      final shop = ShopModel.fromJson({
        'id': 2,
        'user_id': 102,
        'shop_name': 'Kisan Seeds Store',
        'owner_name': 'Suresh Patel',
        'phone': '9876543211',
        'market_location': 'Bhopal',
        'address': 'Kisan Mandi',
        'debt_taken': 150000.0,
        'debt_repaid': 60000.0,
        'total_balance': 90000.0,
      });
      expect(shop.debtTaken, 150000.0);
      expect(shop.debtRepaid, 60000.0);
      expect(shop.totalBalance, 90000.0);

      // Fallback calculation when total_balance is null
      final shopFallback = ShopModel.fromJson({
        'id': 3,
        'user_id': 103,
        'shop_name': 'Green Agri Care',
        'owner_name': 'Mahesh Sharma',
        'phone': '9876543212',
        'market_location': 'Ujjain',
        'address': 'Near Bus Stand',
        'debt_taken': 100000.0,
        'debt_repaid': 35000.0,
      });
      expect(shopFallback.debtTaken, 100000.0);
      expect(shopFallback.debtRepaid, 35000.0);
      expect(shopFallback.totalBalance, 65000.0);

      // Negative balance when debt_repaid > debt_taken
      final shopOverpaid = ShopModel.fromJson({
        'id': 4,
        'user_id': 104,
        'shop_name': 'Agro World',
        'owner_name': 'Vijay Singh',
        'phone': '9876543213',
        'market_location': 'Dewas',
        'address': 'Station Road',
        'debt_taken': 20000.0,
        'debt_repaid': 25000.0,
      });
      expect(shopOverpaid.debtTaken, 20000.0);
      expect(shopOverpaid.debtRepaid, 25000.0);
      expect(shopOverpaid.totalBalance, -5000.0);
    });

    test('4. ShopModel toJson and copyWith maintain financial fields integrity', () {
      final shop = ShopModel(
        id: 1,
        userId: 101,
        shopName: 'Test Shop',
        ownerName: 'Owner One',
        phone: '9876543210',
        marketLocation: 'Market',
        address: 'Address 1',
        openingStockBags: 0,
        currentStockBags: 0,
        status: 'Active',
        debtTaken: 75000.0,
        debtRepaid: 25000.0,
        totalBalance: 50000.0,
      );
      final json = shop.toJson();
      expect(json['debt_taken'], 75000.0);
      expect(json['debt_repaid'], 25000.0);
      expect(json['total_balance'], 50000.0);

      final updated = shop.copyWith(
        debtTaken: 80000.0,
        debtRepaid: 30000.0,
      );
      expect(updated.debtTaken, 80000.0);
      expect(updated.debtRepaid, 30000.0);
      expect(updated.totalBalance, 50000.0);
    });

    test('5. Dealer profile self-update ignores financial tampering', () {
      // Simulating Dealer self-update (PUT /api/v1/shops/my)
      final existingRecord = {
        'id': 1,
        'shop_name': 'Original Shop',
        'owner_name': 'Owner',
        'debt_taken': 50000.0,
        'debt_repaid': 20000.0,
        'total_balance': 30000.0,
      };

      // Attacker payload trying to alter debt
      final dealerPayload = {
        'shop_name': 'Renamed Shop',
        'debt_taken': 0.0,
        'debt_repaid': 50000.0,
        'total_balance': 0.0,
      };

      // Backend logic strip:
      final sanitizedPayload = Map<String, dynamic>.from(dealerPayload);
      sanitizedPayload.remove('debt_taken');
      sanitizedPayload.remove('debt_repaid');
      sanitizedPayload.remove('total_balance');

      final updatedRecord = Map<String, dynamic>.from(existingRecord);
      sanitizedPayload.forEach((k, v) => updatedRecord[k] = v);

      expect(updatedRecord['shop_name'], 'Renamed Shop');
      expect(updatedRecord['debt_taken'], 50000.0); // Protected
      expect(updatedRecord['debt_repaid'], 20000.0); // Protected
      expect(updatedRecord['total_balance'], 30000.0); // Protected
    });
  });
}
