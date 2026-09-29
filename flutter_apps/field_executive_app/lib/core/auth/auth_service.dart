import 'dart:convert';
import '../network/api_client.dart';
import '../storage/local_storage.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();

  Future<bool> requestOtp(String username, String mobile) async {
    final response = await _apiClient.post('/api/v1/auth/request-otp', {
      'username': username,
      'mobile': mobile,
    });
    
    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Failed to request OTP: ${response.body}');
    }
  }

  Future<bool> verifyOtp(String username, String mobile, String otp) async {
    final response = await _apiClient.post('/api/v1/auth/verify-otp', {
      'username': username,
      'mobile': mobile,
      'otp': otp,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['access_token'];
      if (token != null) {
        await LocalStorage.saveToken(token);
        return true;
      }
    }
    throw Exception('Invalid OTP or Verification Failed');
  }

  Future<void> logout() async {
    await LocalStorage.clearToken();
  }

  Future<bool> isAuthenticated() async {
    return await LocalStorage.hasSession();
  }
}
