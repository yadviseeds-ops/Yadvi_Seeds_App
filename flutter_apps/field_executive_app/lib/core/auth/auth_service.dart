import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../network/api_client.dart';
import '../storage/local_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ApiClient _apiClient = ApiClient();

  String? _verificationId;
  int? _resendToken;
  bool _isRequestingOtp = false;

  Future<String> requestOtp(String username, String mobile) async {
    if (_isRequestingOtp) {
      throw Exception('An OTP request is already in progress. Please wait.');
    }
    _isRequestingOtp = true;

    try {
      // 1. Verify user exists and is active in backend database
      final verifyResponse = await _apiClient.post('/api/v1/auth/verify-user', {
        'username': username,
        'mobile': mobile,
      });

      if (verifyResponse.statusCode != 200) {
        throw Exception('Invalid username or registered mobile number.');
      }

      final completer = Completer<String>();

      await _auth.verifyPhoneNumber(
        phoneNumber: '+91$mobile',
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('FE Firebase verificationCompleted');
          try {
            await _auth.signInWithCredential(credential);
          } catch (e) {
            debugPrint('Auto verification sign-in failed: $e');
          }
          if (!completer.isCompleted) {
            _verificationId = 'auto_verified';
            completer.complete('auto_verified');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('FE Firebase verificationFailed: ${e.code} - ${e.message}');
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('FE Firebase codeSent: verificationId received');
          _verificationId = verificationId;
          _resendToken = resendToken;
          if (!completer.isCompleted) {
            completer.complete(verificationId);
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('FE Firebase codeAutoRetrievalTimeout');
          _verificationId = verificationId;
          if (!completer.isCompleted) {
            completer.complete(verificationId);
          }
        },
      );

      final verificationId = await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('OTP request timed out. Please check your connection and try again.');
        },
      );

      return verificationId;
    } finally {
      _isRequestingOtp = false;
    }
  }

  Future<bool> verifyOtp(String username, String mobile, String otp) async {
    if (_verificationId == null) {
      throw Exception('OTP verification session not found. Please request an OTP first.');
    }

    User? user = _auth.currentUser;

    // If not already auto-verified, sign in with SMS credential
    if (user == null || _verificationId != 'auto_verified') {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      user = userCredential.user;
    }

    if (user != null) {
      final idToken = await user.getIdToken();
      if (idToken == null) throw Exception('Could not retrieve Firebase authentication token.');

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
          await logout();
          throw Exception('Unauthorized role ($role). This app is for Field Executives only.');
        }

        if (accessToken == null || (accessToken as String).isEmpty) {
          await logout();
          throw Exception('Backend returned invalid session token.');
        }

        await LocalStorage.saveToken(accessToken);
        await LocalStorage.saveRole(role);
        return true;
      } else {
        await logout();
        String errorMsg = 'Backend authentication failed.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['detail'] != null) {
            errorMsg = errorData['detail'].toString();
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    }
    return false;
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out of Firebase: $e');
    }
    await LocalStorage.clearToken();
  }

  Future<bool> isAuthenticated() async {
    final hasFirebaseUser = _auth.currentUser != null;
    final hasBackendSession = await LocalStorage.hasSession();
    final role = await LocalStorage.getRole();

    if (hasFirebaseUser && hasBackendSession && role == 'field_executive') {
      return true;
    }

    // Clean up inconsistent state if present
    if (hasFirebaseUser || hasBackendSession) {
      await logout();
    }
    return false;
  }
}
