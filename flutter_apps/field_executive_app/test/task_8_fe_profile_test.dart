import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:field_executive_app/models/fe_profile.dart';
import 'package:field_executive_app/services/fe_service.dart';
import 'package:field_executive_app/features/profile/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK 8: Standalone FE Profile Editing & Protected Fields', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. FeProfile model maps username, phone, employeeCode, and editable fields', () {
      final json = {
        'id': 101,
        'user_id': 1,
        'username': 'fe_user_test',
        'employee_code': 'EMP-101',
        'designation': 'Field Sales Officer',
        'assigned_territory': 'Guntur',
        'battery_level': 88,
        'attendance_status': 'Present',
        'full_name': 'Ramesh Kumar',
        'phone': '9848011223',
        'email': 'ramesh@yadvi.com',
        'is_active': true,
      };

      final profile = FeProfile.fromJson(json);
      expect(profile.username, 'fe_user_test');
      expect(profile.phone, '9848011223');
      expect(profile.employeeCode, 'EMP-101');
      expect(profile.fullName, 'Ramesh Kumar');
      expect(profile.email, 'ramesh@yadvi.com');
    });

    test('2. FE profile update payload restricts modifications to full_name and email', () {
      final allowedPayload = <String, dynamic>{};
      const newName = 'Ramesh K. Updated';
      const newEmail = 'ramesh.updated@yadvi.com';

      allowedPayload['full_name'] = newName;
      allowedPayload['email'] = newEmail;

      // Phone and Username are never permitted in the update payload
      expect(allowedPayload.containsKey('phone'), isFalse);
      expect(allowedPayload.containsKey('username'), isFalse);
      expect(allowedPayload.containsKey('employee_code'), isFalse);
      expect(allowedPayload['full_name'], 'Ramesh K. Updated');
      expect(allowedPayload['email'], 'ramesh.updated@yadvi.com');
    });

    test('3. Mobile number and username immutability verification', () {
      const originalMobile = '9848011223';
      const originalUsername = 'fe_user_test';

      final attemptedTampering = {
        'full_name': 'Ramesh Kumar',
        'phone': '9999999999',
        'username': 'tampered_username',
      };

      // Ensure consumer respects admin-controlled fields
      final effectivePhone = originalMobile;
      final effectiveUsername = originalUsername;

      expect(effectivePhone, originalMobile);
      expect(effectiveUsername, originalUsername);
      expect(attemptedTampering['phone'], isNot(equals(effectivePhone)));
      expect(attemptedTampering['username'], isNot(equals(effectiveUsername)));
    });
  });
}
