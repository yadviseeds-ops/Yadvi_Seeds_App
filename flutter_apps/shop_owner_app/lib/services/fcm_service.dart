import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../core/network/api_client.dart';
import '../core/storage/local_storage.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  final ApiClient _apiClient = ApiClient();
  static final FcmService _instance = FcmService._internal();

  factory FcmService() => _instance;

  FcmService._internal();

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notification permission');
        String? token = await messaging.getToken();
        if (token != null) {
          await registerTokenWithBackend(token);
        }

        // Listen for token refresh
        messaging.onTokenRefresh.listen((newToken) {
          registerTokenWithBackend(newToken);
        });

        // Foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Got a message whilst in the foreground!');
          debugPrint('Message data: ${message.data}');
          if (message.notification != null) {
            debugPrint('Message also contained a notification: ${message.notification!.title}');
          }
        });
      } else {
        debugPrint('User declined or has not accepted notification permission');
      }
    } catch (e) {
      debugPrint('FCM Pending Configuration or Init failed: $e');
    }
  }

  Future<void> registerTokenWithBackend(String token) async {
    try {
      if (await LocalStorage.hasSession()) {
        final body = {
          "token": token,
          "platform": "android"
        };
        await _apiClient.post('/auth/fcm-token', body);
        debugPrint('FCM Token registered with backend');
      }
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint("Handling a background message: ${message.messageId}");
  } catch(e) {}
}
