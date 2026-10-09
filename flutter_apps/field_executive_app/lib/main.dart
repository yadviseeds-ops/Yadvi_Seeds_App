import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'core/auth/auth_service.dart';
import 'core/storage/local_storage.dart';
import 'features/auth/role_selection_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'services/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase FIRST
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register Firebase Messaging AFTER Firebase initialization
  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

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
  String? _userRole;

  @override
  void initState() {
    super.initState();

    _checkAuth();
    FcmService().initialize();
  }

  Future<void> _checkAuth() async {
    final authenticated = await _authService.isAuthenticated();
    String? role;
    if (authenticated) {
      role = await LocalStorage.getRole();
    }

    if (!mounted) return;

    setState(() {
      _isAuthenticated = authenticated;
      _userRole = role;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yadvi Field Executive',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: _isLoading
          ? const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.teal,
          ),
        ),
      )
          : (!_isAuthenticated
          ? const RoleSelectionScreen()
          : (_userRole == 'field_executive'
              ? const DashboardScreen()
              : Scaffold(
                  appBar: AppBar(title: const Text('Module Not Integrated')),
                  body: const Center(child: Text('This module will be integrated shortly.')),
                ))),
      debugShowCheckedModeBanner: false,
    );
  }
}