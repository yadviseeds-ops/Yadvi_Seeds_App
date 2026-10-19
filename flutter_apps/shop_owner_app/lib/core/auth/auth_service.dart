import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert';
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
      // 1. Verify user exists and is valid first
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
          debugPrint('Firebase verificationCompleted');
          try {
            await _auth.signInWithCredential(credential);
          } catch (e) {
            debugPrint('Auto verification failed: $e');
          }
          if (!completer.isCompleted) {
            _verificationId = 'auto_verified';
            completer.complete('auto_verified');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('Firebase verificationFailed: ${e.code}');
          debugPrint('Firebase verificationFailed message: ${e.message}');

          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('Firebase codeSent: verificationId received');
          _verificationId = verificationId;
          _resendToken = resendToken;
          debugPrint(
            'Verification ID available after codeSent: ${_verificationId != null}',
          );

          if (!completer.isCompleted) {
            completer.complete(verificationId);
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('Firebase codeAutoRetrievalTimeout');
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

      debugPrint('requestOtp completed');
      debugPrint(
        'Final verification ID available: ${_verificationId != null}',
      );

      return verificationId;
    } finally {
      _isRequestingOtp = false;
    }
  }

  Future<bool> verifyOtp(String username, String mobile, String otp, String expectedRole) async {
    debugPrint(
        'Verification ID available before verifyOtp: ${_verificationId != null}');
    if (_verificationId == null) {
      throw Exception('OTP verification session not found. Please request an OTP first.');
    }

    debugPrint('Using verificationId: true');
    debugPrint('OTP length: ${otp.length}');

    User? user = _auth.currentUser;

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
      if (idToken == null) throw Exception("Could not get Firebase token");

      final response = await _apiClient.post('/api/v1/auth/login-firebase', {
        'username': username,
        'mobile': mobile,
        'firebase_id_token': idToken,
      });

      debugPrint('Backend login response status: ${response.statusCode}');
      debugPrint('Backend login response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'];
        final role = data['role'];
        if (role != expectedRole) {
          await logout();
          throw Exception("Unauthorized role ($role). Access denied.");
        }
        await LocalStorage.saveToken(accessToken);
        await LocalStorage.saveRole(role);
        return true;
      } else {
        await logout();
        String errorMsg = "Backend authentication failed.";
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
      debugPrint('Error during Firebase signOut: $e');
    }
    await LocalStorage.clearToken();
  }

  Future<bool> isAuthenticated() async {
    final hasFirebase = _auth.currentUser != null;
    final hasBackendSession = await LocalStorage.hasSession();
    final role = await LocalStorage.getRole();

    if (hasFirebase && hasBackendSession && role != null) {
      return true;
    }

    // Clean up inconsistent session
    if (hasFirebase || hasBackendSession) {
      await logout();
    }
    return false;
  }
}
