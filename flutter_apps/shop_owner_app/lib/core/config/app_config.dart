class AppConfig {
  static const String environment =
      String.fromEnvironment('ENV', defaultValue: 'dev');

  static String get apiBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // Emulator needs 10.0.2.2
    return 'http://10.0.2.2:8000';
  }

  static String get wsBaseUrl {
    if (apiBaseUrl.startsWith('https://')) {
      return apiBaseUrl.replaceFirst('https://', 'wss://');
    } else {
      return apiBaseUrl.replaceFirst('http://', 'ws://');
    }
  }
}
