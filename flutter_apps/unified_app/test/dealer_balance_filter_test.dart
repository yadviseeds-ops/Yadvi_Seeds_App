import 'package:flutter_test/flutter_test.dart';
import 'package:unified_app/models/shop_model.dart';

void main() {
  group('Admin Dealer Network Balance Filtering & Sorting Tests', () {
    late List<ShopModel> testShops;

    setUp(() {
      testShops = [
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
          totalBalance: 0.0, // Zero balance & Fully Repaid
        ),
        ShopModel(
          id: 3,
          userId: 103,
          shopName: 'Nandini Agro Seeds',
          ownerName: 'Mahesh',
          phone: '9876543212',
          marketLocation: 'Ujjain',
          address: 'Bus Stand',
          openingStockBags: 0,
          currentStockBags: 0,
          status: 'Active',
          debtTaken: 100000.0,
          debtRepaid: 15000.0,
          totalBalance: 85000.0, // Outstanding
        ),
        ShopModel(
          id: 4,
          userId: 104,
          shopName: 'Agro World Plus',
          ownerName: 'Ganesh',
          phone: '9876543213',
          marketLocation: 'Dewas',
          address: 'Station Road',
          openingStockBags: 0,
          currentStockBags: 0,
          status: 'Active',
          debtTaken: 10000.0,
          debtRepaid: 12000.0,
          totalBalance: -2000.0, // Negative balance & Fully Repaid (debtRepaid >= debtTaken)
        ),
      ];
    });

    test('1. Outstanding Balance filter returns only shops with totalBalance > 0', () {
      final outstanding = testShops.where((s) => s.totalBalance > 0).toList();
      expect(outstanding.length, 2);
      expect(outstanding.map((s) => s.id), containsAll([1, 3]));
    });

    test('2. Zero Balance filter returns only shops with totalBalance == 0', () {
      final zeroBal = testShops.where((s) => s.totalBalance == 0.0).toList();
      expect(zeroBal.length, 1);
      expect(zeroBal.first.id, 2);
    });

    test('3. Fully Repaid filter returns shops where debtRepaid >= debtTaken', () {
      final fullyRepaid = testShops.where((s) => s.debtRepaid >= s.debtTaken).toList();
      expect(fullyRepaid.length, 2);
      expect(fullyRepaid.map((s) => s.id), containsAll([2, 4]));
    });

    test('4. Highest Balance First sorts numeric totalBalance in descending order', () {
      final list = List<ShopModel>.from(testShops);
      list.sort((a, b) => b.totalBalance.compareTo(a.totalBalance));
      expect(list.map((s) => s.totalBalance).toList(), [85000.0, 30000.0, 0.0, -2000.0]);
      expect(list.first.shopName, 'Nandini Agro Seeds');
    });

    test('5. Lowest Balance First sorts numeric totalBalance in ascending order', () {
      final list = List<ShopModel>.from(testShops);
      list.sort((a, b) => a.totalBalance.compareTo(b.totalBalance));
      expect(list.map((s) => s.totalBalance).toList(), [-2000.0, 0.0, 30000.0, 85000.0]);
      expect(list.first.shopName, 'Agro World Plus');
    });

    test('6. Dealer Name A-Z and Z-A alphabetical sorting', () {
      final listAsc = List<ShopModel>.from(testShops);
      listAsc.sort((a, b) => a.shopName.toLowerCase().compareTo(b.shopName.toLowerCase()));
      expect(listAsc.first.shopName, 'Agro World Plus');
      expect(listAsc.last.shopName, 'Shree Seeds');

      final listDesc = List<ShopModel>.from(testShops);
      listDesc.sort((a, b) => b.shopName.toLowerCase().compareTo(a.shopName.toLowerCase()));
      expect(listDesc.first.shopName, 'Shree Seeds');
      expect(listDesc.last.shopName, 'Agro World Plus');
    });

    test('7. Search + Balance Filter combination works accurately', () {
      // Search for 'Agro' AND Filter 'Outstanding'
      const query = 'Agro';
      final filtered = testShops.where((s) {
        final matchesSearch = s.shopName.toLowerCase().contains(query.toLowerCase());
        final matchesFilter = s.totalBalance > 0;
        return matchesSearch && matchesFilter;
      }).toList();

      expect(filtered.length, 1);
      expect(filtered.first.shopName, 'Nandini Agro Seeds');
    });
  });
}
