import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../network/api_client.dart';
import '../storage/local_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ApiClient _apiClient = ApiClient();

  String? _verificationId;

  Future<void> requestOtp(String username, String mobile) async {
    final verifyResponse = await _apiClient.post('/api/v1/auth/verify-user', {
      'username': username,
      'mobile': mobile,
    });
    
    if (verifyResponse.statusCode != 200) {
      throw Exception('Invalid username or registered mobile number.');
    }

    await _auth.verifyPhoneNumber(
      phoneNumber: '+91$mobile',
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        throw Exception(e.message ?? 'Phone verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<bool> verifyOtp(String username, String mobile, String otp) async {
    if (_verificationId == null) throw Exception('OTP session not found');

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user != null) {
      final idToken = await user.getIdToken();
      if (idToken == null) throw Exception("Could not get Firebase token");

      final response = await _apiClient.post('/api/v1/auth/login-firebase', {
        'username': username,
        'mobile': mobile,
        'firebase_id_token': idToken,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'];
        final role = data['role'];
        if (role != 'field_executive') {
          await _auth.signOut();
          throw Exception("Unauthorized role. Access denied.");
        }
        await LocalStorage.saveToken(accessToken);
        return true;
      } else {
        await _auth.signOut();
        throw Exception("Backend authentication failed.");
      }
    }
    return false;
  }

  Future<void> logout() async {
    await _auth.signOut();
    await LocalStorage.clearToken();
  }

  Future<bool> isAuthenticated() async {
    return _auth.currentUser != null;
  }
}
