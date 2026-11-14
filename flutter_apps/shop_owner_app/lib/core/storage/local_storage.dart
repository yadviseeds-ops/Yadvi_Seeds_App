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

  static Future<void> saveUserData({
    required int userId,
    required String fullName,
  }) async {
    await _secureStorage.write(key: 'user_id', value: userId.toString());
    await _secureStorage.write(key: 'user_name', value: fullName);
  }

  static Future<Map<String, String?>> getUserData() async {
    return {
      'id': await _secureStorage.read(key: 'user_id'),
      'name': await _secureStorage.read(key: 'user_name'),
      'role': await _secureStorage.read(key: 'user_role'),
    };
  }

  static Future<void> clearToken() async {
    await _secureStorage.delete(key: 'jwt_token');
    await _secureStorage.delete(key: 'user_role');
    await _secureStorage.delete(key: 'user_id');
    await _secureStorage.delete(key: 'user_name');
  }

  static Future<bool> hasSession() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
