import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Helper function implementing identical logic to AdminProvider._extractErrorMessage
String extractErrorMessage(http.Response res) {
  try {
    final body = jsonDecode(res.body);
    if (body is Map) {
      if (body['detail'] != null) {
        if (body['detail'] is String) return body['detail'];
        if (body['detail'] is List) {
          return (body['detail'] as List)
              .map(
                (e) => e is Map ? (e['msg'] ?? e.toString()) : e.toString(),
              )
              .join(', ');
        }
      }
      if (body['message'] != null) return body['message'].toString();
    }
  } catch (_) {}
  return 'Server error (HTTP ${res.statusCode})';
}

void main() {
  group('Admin Deletion Error Message Extraction Tests', () {
    test('extracts exact detail string when Shop Owner has associated orders', () {
      final res = http.Response(
        jsonEncode({
          'detail':
              'Cannot delete Shop Owner with associated orders. Historical order records must be preserved.',
        }),
        400,
      );
      final msg = extractErrorMessage(res);
      expect(
        msg,
        'Cannot delete Shop Owner with associated orders. Historical order records must be preserved.',
      );
    });

    test('extracts exact detail string when Field Executive has recorded visits', () {
      final res = http.Response(
        jsonEncode({
          'detail':
              'Cannot delete Field Executive with recorded visits. Historical visit records must be preserved.',
        }),
        400,
      );
      final msg = extractErrorMessage(res);
      expect(
        msg,
        'Cannot delete Field Executive with recorded visits. Historical visit records must be preserved.',
      );
    });

    test('extracts 404 not found message correctly', () {
      final res = http.Response(
        jsonEncode({'detail': 'Shop owner not found'}),
        404,
      );
      final msg = extractErrorMessage(res);
      expect(msg, 'Shop owner not found');
    });

    test('extracts validation error array properly joined', () {
      final res = http.Response(
        jsonEncode({
          'detail': [
            {'loc': ['body', 'employee_code'], 'msg': 'Field required'},
            {'loc': ['body', 'phone'], 'msg': 'Invalid phone number'},
          ],
        }),
        422,
      );
      final msg = extractErrorMessage(res);
      expect(msg, 'Field required, Invalid phone number');
    });

    test('falls back to HTTP status when body is non-JSON or HTML', () {
      final res = http.Response('<html>502 Bad Gateway</html>', 502);
      final msg = extractErrorMessage(res);
      expect(msg, 'Server error (HTTP 502)');
    });
  });
}
