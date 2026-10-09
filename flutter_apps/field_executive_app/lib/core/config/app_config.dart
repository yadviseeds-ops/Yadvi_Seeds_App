class AppConfig {
  static const String environment = String.fromEnvironment('ENV', defaultValue: 'dev');
  
  static String get apiBaseUrl {
    // Allows overriding via --dart-define=API_BASE_URL=http://192.168.137.1:8000
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    
    // Default to a common LAN IP placeholder or 10.0.2.2 for Android emulator
    // Physical device needs actual IP of the dev machine running FastAPI
   return 'http://192.168.137.1:8000';
  }
}
