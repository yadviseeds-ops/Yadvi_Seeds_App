import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _defaultUrl = 'http://10.0.2.2:8000';
  static String? _customUrl;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _customUrl = prefs.getString('custom_api_url');
  }

  static String get apiBaseUrl {
    if (_customUrl != null && _customUrl!.isNotEmpty) {
      return _customUrl!;
    }
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return _defaultUrl;
  }

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
