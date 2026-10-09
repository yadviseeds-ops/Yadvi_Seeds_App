import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalStorage {
  static const _secureStorage = FlutterSecureStorage();

  static Future<void> saveToken(String token) async {
    await _secureStorage.write(key: 'jwt_token', value: token);
  }

  static Future<String?> getToken() async {
    return await _secureStorage.read(key: 'jwt_token');
  }

  static Future<void> saveRole(String role) async {
    await _secureStorage.write(key: 'user_role', value: role);
  }

  static Future<String?> getRole() async {
    return await _secureStorage.read(key: 'user_role');
  }

  static Future<void> clearToken() async {
    await _secureStorage.delete(key: 'jwt_token');
    await _secureStorage.delete(key: 'user_role');
  }

  static Future<bool> hasSession() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
