import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../network/api_client.dart';
import '../storage/local_storage.dart';

/// Represents the state of a phone-change verification request.
/// Distinguishes automatic verification (autoVerifiedToken) from manual verification (verificationId).
class PhoneChangeVerificationSession {
  final String? verificationId;
  final String? autoVerifiedToken;
  final int? resendToken;

  const PhoneChangeVerificationSession({
    this.verificationId,
    this.autoVerifiedToken,
    this.resendToken,
  });

  bool get isAutoVerified => autoVerifiedToken != null && autoVerifiedToken!.isNotEmpty;
}

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
      final code = error.code;
      switch (code) {
        case 'network-request-failed':
          return 'Network error: Unable to connect to authentication server. Check internet connectivity.';
        case 'invalid-phone-number':
          return 'Invalid phone number. Please check the entered 10-digit number.';
        case 'too-many-requests':
          return 'Too many OTP requests for this number. Please wait before trying again.';
        case 'quota-exceeded':
          return 'Daily SMS verification quota has been reached. Please contact support or try again later.';
        case 'app-not-authorized':
          return 'App verification failed. Please contact support.';
        case 'invalid-verification-code':
          return 'Invalid verification code. Please check and re-enter the 6-digit OTP.';
        case 'session-expired':
          return 'Verification session expired. Please request a new OTP.';
        default:
          return error.message != null && error.message!.isNotEmpty
              ? 'Authentication error: ${error.message}'
              : 'Authentication error. Please try again.';
      }
    }
    final errStr = error.toString().replaceFirst('Exception: ', '');
    if (errStr.contains('429') || errStr.toLowerCase().contains('too many')) {
      return 'Too many verification requests from this network. Please try again later.';
    }
    return errStr;
  }


  /// Phase 1 of Phone Login: Verify credentials with FastAPI, then trigger Firebase Phone Auth
  Future<String> requestOtp(String username, String mobile, {String? expectedRole}) async {
    if (_isRequestingOtp) {
      throw Exception('An OTP request is already in progress. Please wait.');
    }
    _isRequestingOtp = true;

    try {
      // 1. Validate user, active status, and expected role with backend
      final verifyPayload = <String, dynamic>{
        'username': username.trim(),
        'mobile': mobile.trim(),
      };
      if (expectedRole != null && expectedRole.isNotEmpty) {
        verifyPayload['expected_role'] = expectedRole;
      }
      final verifyResponse = await _apiClient.post('/api/v1/auth/verify-user', verifyPayload);

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

  /// Fetch current authenticated user's profile
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _apiClient.get('/api/v1/auth/me');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      String err = 'Failed to load profile (${response.statusCode}).';
      try {
        final data = jsonDecode(response.body);
        if (data['detail'] != null) err = data['detail'].toString();
      } catch (_) {}
      throw Exception(err);
    }
  }

  /// Update administrator profile details
  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? username,
    String? email,
    String? newPhone,
    String? firebaseIdToken,
  }) async {
    final payload = <String, dynamic>{};
    if (fullName != null) payload['full_name'] = fullName.trim();
    if (username != null) payload['username'] = username.trim();
    if (email != null) payload['email'] = email.trim();
    if (newPhone != null) payload['new_phone'] = newPhone.trim();
    if (firebaseIdToken != null) payload['firebase_id_token'] = firebaseIdToken;

    final response = await _apiClient.put('/api/v1/auth/me', payload);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['full_name'] != null) {
        final userId = data['id'] ?? 0;
        await LocalStorage.saveUserData(
          userId: userId,
          fullName: data['full_name'],
        );
      }
      return data;
    } else {
      String err = 'Failed to update profile (${response.statusCode}).';
      try {
        final data = jsonDecode(response.body);
        if (data['detail'] != null) err = data['detail'].toString();
      } catch (_) {}
      throw Exception(err);
    }
  }

  /// Triggers Firebase Phone Auth to send OTP for changing phone number.
  /// Returns a PhoneChangeVerificationSession which clearly distinguishes between
  /// automatic verification (instant token) and manual SMS verification (verificationId).
  Future<PhoneChangeVerificationSession> requestPhoneChangeOtp(String newMobile) async {
    final completer = Completer<PhoneChangeVerificationSession>();
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '+91${newMobile.trim()}',
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('[AuthService] Firebase auto-verification completed for phone change.');
          try {
            final userCred = await _auth.signInWithCredential(credential);
            final token = await userCred.user?.getIdToken();
            if (token != null && !completer.isCompleted) {
              completer.complete(PhoneChangeVerificationSession(autoVerifiedToken: token));
            }
          } catch (e, st) {
            debugPrint('[AuthService] Auto-verification sign-in failed: $e\n$st');
            if (!completer.isCompleted) completer.completeError(e);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('[AuthService] Firebase phone change verificationFailed: code=${e.code}, msg=${e.message}');
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('[AuthService] Firebase phone change codeSent: verificationId=$verificationId');
          if (!completer.isCompleted) {
            completer.complete(PhoneChangeVerificationSession(
              verificationId: verificationId,
              resendToken: resendToken,
            ));
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('[AuthService] Firebase phone change codeAutoRetrievalTimeout: $verificationId');
        },
      );
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }
    return completer.future;
  }

  /// Verifies OTP for phone change and returns the Firebase ID token
  Future<String> verifyPhoneChangeOtp(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final token = await userCredential.user?.getIdToken();
    if (token == null) {
      throw Exception('Failed to obtain verified Firebase token for phone change.');
    }
    return token;
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
