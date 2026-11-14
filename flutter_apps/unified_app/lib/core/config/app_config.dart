import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  /// Production Cloud Run HTTPS backend URL
  static const String productionUrl =
      'https://yadvi-day1-test-f5upp75xna-el.a.run.app';

  /// Local Android emulator proxy URL (via gcloud run services proxy yadvi-day1-test --region=asia-south1 --port=8080)
  static const String localProxyUrl = 'http://10.0.2.2:8080';

  /// Default API URL for both debug and release
  static const String _defaultUrl = productionUrl;

  static String? _customUrl;

  /// Checks if a given URL points to a local or loopback address.
  static bool isLoopbackUrl(String url) {
    final lower = url.trim().toLowerCase();
    return lower.contains('localhost') ||
        lower.contains('127.0.0.1') ||
        lower.contains('10.0.2.2') ||
        lower.contains('0.0.0.0') ||
        lower.contains('::1');
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('custom_api_url');
    // In release mode, or if pointing to legacy/loopback URLs, purge it so production takes effect
    if (saved != null &&
        (isLoopbackUrl(saved) ||
            saved == 'http://10.0.2.2:8080' ||
            saved == 'http://localhost:8080' ||
            saved == 'http://10.0.2.2:8000' ||
            saved == 'http://localhost:8000' ||
            saved == 'http://127.0.0.1:8000')) {
      await prefs.remove('custom_api_url');
      _customUrl = null;
    } else {
      _customUrl = saved;
    }
  }

  /// Resolves the effective API base URL with release-mode loopback safeguards.
  static String resolveApiBaseUrl({
    bool isRelease = kReleaseMode,
    String? customUrl,
    String? envOverride,
  }) {
    final activeCustom = customUrl ?? _customUrl;
    if (activeCustom != null && activeCustom.isNotEmpty) {
      // In release mode, never allow loopback or local development URLs
      if (!isRelease || !isLoopbackUrl(activeCustom)) {
        return activeCustom;
      }
    }

    final activeEnv =
        envOverride ?? const String.fromEnvironment('API_BASE_URL');
    if (activeEnv.isNotEmpty) {
      // In release mode, reject loopback URL overrides
      if (!isRelease || !isLoopbackUrl(activeEnv)) {
        return activeEnv;
      }
    }

    return isRelease ? productionUrl : _defaultUrl;
  }

  static String get apiBaseUrl => resolveApiBaseUrl();

  static Future<void> setCustomBaseUrl(String url) async {
    _customUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_api_url', _customUrl!);
  }

  static Future<void> resetBaseUrl() async {
    _customUrl = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('custom_api_url');
  }

  static String get wsBaseUrl {
    if (apiBaseUrl.startsWith('https://')) {
      return apiBaseUrl.replaceFirst('https://', 'wss://');
    } else {
      return apiBaseUrl.replaceFirst('http://', 'ws://');
    }
  }
}
