import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Failed to set bg handler: $e");
  }
  runApp(const FieldExecutiveApp());
}

class FieldExecutiveApp extends StatefulWidget {
  const FieldExecutiveApp({super.key});

  @override
  State<FieldExecutiveApp> createState() => _FieldExecutiveAppState();
}

class _FieldExecutiveAppState extends State<FieldExecutiveApp> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    FcmService().initialize();
  }

  Future<void> _checkAuth() async {
    final authenticated = await _authService.isAuthenticated();
    setState(() {
      _isAuthenticated = authenticated;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yadvi Field Executive',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.teal)))
          : (_isAuthenticated ? const DashboardScreen() : const LoginScreen()),
      debugShowCheckedModeBanner: false,
    );
  }
}