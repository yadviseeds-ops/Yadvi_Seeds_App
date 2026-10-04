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

  Future<String> requestOtp(String username, String mobile) async {
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
      verificationCompleted: (PhoneAuthCredential credential) async {
        debugPrint('Firebase verificationCompleted');
        try {
          await _auth.signInWithCredential(credential);
        } catch (e) {
          debugPrint('Auto verification failed: $e');
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

    final verificationId = await completer.future;

    debugPrint('requestOtp completed');
    debugPrint(
      'Final verification ID available: ${_verificationId != null}',
    );

    return verificationId;
  }

  Future<bool> verifyOtp(String username, String mobile, String otp, String expectedRole) async {
    debugPrint(
        'Verification ID available before verifyOtp: ${_verificationId != null}');
    if (_verificationId == null) {
      throw Exception('OTP verification session not found');
    }

    debugPrint('Using verificationId: true');
    debugPrint('OTP length: ${otp.length}');

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    );

    UserCredential userCredential;
    try {
      userCredential = await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase OTP verification failed: ${e.code}');
      debugPrint('Firebase OTP error message: ${e.message}');
      rethrow;
    }

    final user = userCredential.user;

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
          await _auth.signOut();
          throw Exception("Unauthorized role. Access denied.");
        }
        await LocalStorage.saveToken(accessToken);
        await LocalStorage.saveRole(role);
        return true;
      } else {
        debugPrint('Backend authentication failed');
        debugPrint('Status: ${response.statusCode}');
        debugPrint('Response: ${response.body}');

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
