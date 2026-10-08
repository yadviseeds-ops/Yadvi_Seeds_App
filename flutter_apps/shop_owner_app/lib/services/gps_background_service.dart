import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'fe_service.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'gps_tracking_channel', // id
    'Daily FE GPS Tracking', // title
    description: 'This channel is used for FE GPS background tracking.', // description
    importance: Importance.low, // low importance prevents sound/vibration
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'gps_tracking_channel',
      initialNotificationTitle: 'Daily GPS Tracking',
      initialNotificationContent: 'Tracking active...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final feService = FeService();

  // Handle stop event
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Execute once immediately
  _fetchAndSendLocation(feService);

  // Then periodically
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    await _fetchAndSendLocation(feService);
  });
}

Future<void> _fetchAndSendLocation(FeService feService) async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    
    await feService.updateLocation(
      position.latitude,
      position.longitude,
      accuracy: position.accuracy,
      speed: position.speed,
    );
  } catch (e) {
    print('Background GPS Error: $e');
  }
}
