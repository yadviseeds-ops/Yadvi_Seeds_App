import 'package:flutter_test/flutter_test.dart';
import 'package:field_executive_app/models/fe_profile.dart';
import 'package:field_executive_app/models/visit_model.dart';
import 'package:field_executive_app/models/order_model.dart';

void main() {
  group('Field Executive App — Models Unit Tests', () {
    test('FeProfile correctly parses profile JSON', () {
      final json = {
        'id': 1,
        'user_id': 101,
        'employee_code': 'FE001',
        'full_name': 'Ramesh Kumar',
        'email': 'ramesh.kumar@yadviseeds.com',
        'phone': '9848011223',
        'designation': 'Field Sales Executive',
        'assigned_territory': 'Guntur Rural',
        'battery_level': 85,
        'attendance_status': 'Present',
        'is_active': true,
      };

      final profile = FeProfile.fromJson(json);
      expect(profile.id, equals(1));
      expect(profile.fullName, equals('Ramesh Kumar'));
      expect(profile.employeeCode, equals('FE001'));
      expect(profile.phone, equals('9848011223'));
      expect(profile.designation, equals('Field Sales Executive'));
      expect(profile.assignedTerritory, equals('Guntur Rural'));
      expect(profile.batteryLevel, equals(85));
      expect(profile.isActive, isTrue);
      expect(profile.attendanceStatus, equals('Present'));
    });

    test('VisitModel correctly parses visit JSON', () {
      final json = {
        'id': 10,
        'executive_id': 1,
        'executive_name': 'Ramesh Kumar',
        'employee_code': 'FE001',
        'shop_id': 105,
        'shop_name': 'Sri Rama Krishi Seva Kendra',
        'shop_location': 'Nuzvid',
        'status': 'Visited',
        'purpose': 'Stock Audit',
        'visited_at': '2026-10-19T10:30:00Z',
        'bags_ordered': 10,
        'scheduled_date': '2026-10-19',
      };

      final visit = VisitModel.fromJson(json);
      expect(visit.id, equals(10));
      expect(visit.executiveId, equals(1));
      expect(visit.shopId, equals(105));
      expect(visit.shopName, equals('Sri Rama Krishi Seva Kendra'));
      expect(visit.status, equals('Visited'));
      expect(visit.purpose, equals('Stock Audit'));
      expect(visit.bagsOrdered, equals(10));
    });

    test('OrderModel correctly parses order JSON', () {
      final json = {
        'id': 501,
        'order_number': 'ORD-501',
        'shop_name': 'Balaji Seeds & Fertilizers',
        'shop_location': 'Tenali',
        'owner_name': 'K. Balaji',
        'contact_phone': '9848033445',
        'delivery_address': 'Market Yard Road, Tenali',
        'total_quantity_bags': 50,
        'status': 'Delivered',
        'created_at': '2026-10-19T08:00:00Z',
      };

      final order = OrderModel.fromJson(json);
      expect(order.id, equals(501));
      expect(order.orderNumber, equals('ORD-501'));
      expect(order.totalQuantityBags, equals(50));
      expect(order.status, equals('Delivered'));
    });
  });
}
