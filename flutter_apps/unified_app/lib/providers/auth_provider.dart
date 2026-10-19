import 'package:flutter/material.dart';
import '../core/auth/auth_service.dart';
import '../core/storage/local_storage.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUser;
  bool _isAuthenticated = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  AuthService get authService => _authService;

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      _isAuthenticated = await _authService.isAuthenticated();
      if (_isAuthenticated) {
        final userData = await LocalStorage.getUserData();
        _currentUser = userData['name'] ?? 'Admin';
      }
    } catch (_) {
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> requestOtp(String username, String mobile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final verificationId = await _authService.requestOtp(username, mobile);
      _isLoading = false;
      notifyListeners();
      return verificationId;
    } catch (e, stackTrace) {
      _isLoading = false;
      _errorMessage = AuthService.formatAuthError(e);
      debugPrint('[AuthProvider] requestOtp failure: $_errorMessage\n$stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> verifyOtp(String username, String mobile, String otp, {String? expectedRole}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _authService.verifyOtp(username, mobile, otp, expectedRole: expectedRole);
      if (success) {
        _isAuthenticated = true;
        final userData = await LocalStorage.getUserData();
        _currentUser = userData['name'] ?? username;
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> loginWithPassword(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _authService.loginWithPassword(username, password);
      if (success) {
        _isAuthenticated = true;
        final userData = await LocalStorage.getUserData();
        _currentUser = userData['name'] ?? username;
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _currentUser = null;
    notifyListeners();
  }
}
