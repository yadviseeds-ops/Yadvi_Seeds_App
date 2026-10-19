import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../network/api_client.dart';
import '../storage/local_storage.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final ApiClient _apiClient = ApiClient();

  String? _verificationId;
  int? _resendToken;
  bool _isRequestingOtp = false;

  String? get verificationId => _verificationId;

  /// Formats Firebase and network authentication errors into clear, actionable UI messages
  static String formatAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'network-request-failed':
          return 'Network error: Unable to connect to Firebase. Check internet connectivity, DNS, and Google Play Services.';
        case 'invalid-phone-number':
          return 'Invalid phone number: Please check the entered 10-digit number.';
        case 'too-many-requests':
          return 'Too many requests: SMS quota reached or device blocked temporarily. Please try again later.';
        case 'quota-exceeded':
          return 'Daily SMS quota exceeded in Firebase project. Please try again tomorrow or contact admin.';
        case 'app-not-authorized':
          return 'App not authorized: App SHA-1 fingerprint or package name is not registered in Firebase Console.';
        case 'invalid-verification-code':
          return 'Invalid verification code. Please check the OTP and try again.';
        case 'session-expired':
          return 'Verification session expired. Please request a new OTP.';
        default:
          return '[${error.code}] ${error.message ?? 'Authentication failed.'}';
      }
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  /// Phase 1 of Phone Login: Verify credentials with FastAPI, then trigger Firebase Phone Auth
  Future<String> requestOtp(String username, String mobile) async {
    if (_isRequestingOtp) {
      throw Exception('An OTP request is already in progress. Please wait.');
    }
    _isRequestingOtp = true;

    try {
      // 1. Validate user and active status with backend
      final verifyResponse = await _apiClient.post('/api/v1/auth/verify-user', {
        'username': username.trim(),
        'mobile': mobile.trim(),
      });

      if (verifyResponse.statusCode != 200) {
        String err = 'Invalid username or registered mobile number.';
        try {
          final data = jsonDecode(verifyResponse.body);
          if (data['detail'] != null) err = data['detail'].toString();
        } catch (_) {}
        throw Exception(err);
      }

      final completer = Completer<String>();

      try {
        await _auth.verifyPhoneNumber(
          phoneNumber: '+91${mobile.trim()}',
          forceResendingToken: _resendToken,
          verificationCompleted: (PhoneAuthCredential credential) async {
            debugPrint('[AuthService] Firebase auto-verification completed.');
            try {
              await _auth.signInWithCredential(credential);
            } catch (e, st) {
              debugPrint('[AuthService] Auto sign-in exception: $e\n$st');
            }
            if (!completer.isCompleted) {
              _verificationId = 'auto_verified';
              completer.complete('auto_verified');
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            debugPrint('[AuthService] Firebase verificationFailed: code=${e.code}, plugin=${e.plugin}, message=${e.message}');
            if (e.stackTrace != null) {
              debugPrint('[AuthService] StackTrace: ${e.stackTrace}');
            }
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          },
          codeSent: (String verificationId, int? resendToken) {
            debugPrint('[AuthService] Firebase verification code sent successfully.');
            _verificationId = verificationId;
            _resendToken = resendToken;
            if (!completer.isCompleted) {
              completer.complete(verificationId);
            }
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            debugPrint('[AuthService] Firebase code auto-retrieval timeout.');
            _verificationId = verificationId;
            if (!completer.isCompleted) {
              completer.complete(verificationId);
            }
          },
        );
      } catch (e, st) {
        debugPrint('[AuthService] Direct verifyPhoneNumber exception: $e\n$st');
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }

      final resultVerificationId = await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('OTP request timed out. Please check your network and try again.');
        },
      );

      return resultVerificationId;
    } finally {
      _isRequestingOtp = false;
    }
  }

  /// Phase 2 of Phone Login: Verify SMS OTP via Firebase, exchange for JWT, enforce verified role
  Future<bool> verifyOtp(String username, String mobile, String otp, {String? expectedRole}) async {
    if (_verificationId == null) {
      throw Exception('OTP session not found. Please request an OTP first.');
    }

    User? user = _auth.currentUser;

    if (user == null || _verificationId != 'auto_verified') {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp.trim(),
      );
      final userCredential = await _auth.signInWithCredential(credential);
      user = userCredential.user;
    }

    if (user == null) {
      throw Exception('Firebase authentication failed. No user found.');
    }

    final idToken = await user.getIdToken();
    if (idToken == null) {
      throw Exception('Failed to obtain Firebase ID token.');
    }

    final response = await _apiClient.post('/api/v1/auth/login-firebase', {
      'username': username.trim(),
      'mobile': mobile.trim(),
      'firebase_id_token': idToken,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final role = data['role'];

      // Strict Role Enforcement
      if (expectedRole != null && role != expectedRole) {
        await logout();
        throw Exception(
            'Unauthorized role ($role). Access denied for ${expectedRole.replaceAll('_', ' ')} module.');
      }

      await LocalStorage.saveToken(data['access_token']);
      await LocalStorage.saveRole(role);
      await LocalStorage.saveUserData(
        userId: data['user_id'] ?? 0,
        fullName: data['full_name'] ?? username,
      );
      return true;
    } else {
      await logout();
      String err = 'Authentication failed.';
      try {
        final data = jsonDecode(response.body);
        if (data['detail'] != null) err = data['detail'].toString();
      } catch (_) {}
      throw Exception(err);
    }
  }

  /// Administrator Password Fallback Flow
  Future<bool> loginWithPassword(String username, String password) async {
    final response = await _apiClient.post('/api/v1/auth/login', {
      'username': username.trim(),
      'password': password.trim(),
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final role = data['role'];

      // Strict Administrator Role Enforcement
      if (role != 'administrator') {
        await LocalStorage.clearSession();
        throw Exception('Access denied. Administrator privileges required.');
      }

      await LocalStorage.saveToken(data['access_token']);
      await LocalStorage.saveRole(role);
      await LocalStorage.saveUserData(
        userId: data['user_id'] ?? 0,
        fullName: data['full_name'] ?? username,
      );
      return true;
    } else {
      String err = 'Invalid administrator credentials.';
      try {
        final data = jsonDecode(response.body);
        if (data['detail'] != null) err = data['detail'].toString();
      } catch (_) {}
      throw Exception(err);
    }
  }

  /// Check active user session
  Future<bool> isAuthenticated() async {
    final hasSession = await LocalStorage.hasSession();
    final role = await LocalStorage.getRole();
    return hasSession &&
        role != null &&
        (role == 'administrator' || role == 'field_executive' || role == 'shop_owner');
  }

  /// Terminate session
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('[AuthService] Firebase signOut notice: $e');
    }
    await LocalStorage.clearSession();
  }
}
