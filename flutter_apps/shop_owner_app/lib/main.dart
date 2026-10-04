import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'core/auth/auth_service.dart';
import 'core/storage/local_storage.dart';
import 'features/auth/role_selection_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/field_executive/dashboard/dashboard_screen.dart' as fe;

import 'package:provider/provider.dart';
import 'features/cart/cart_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const ShopOwnerApp(),
    ),
  );
}

class ShopOwnerApp extends StatefulWidget {
  const ShopOwnerApp({super.key});

  @override
  State<ShopOwnerApp> createState() => _ShopOwnerAppState();
}

class _ShopOwnerAppState extends State<ShopOwnerApp> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authenticated = await _authService.isAuthenticated();
    String? role;
    if (authenticated) {
      role = await LocalStorage.getRole();
    }
    setState(() {
      _isAuthenticated = authenticated;
      _userRole = role;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yadvi Shop Owner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        fontFamily: 'Roboto', // Professional typography fallback
      ),
      home: _isLoading
          ? const Scaffold(
              body:
                  Center(child: CircularProgressIndicator(color: Colors.green)))
          : (!_isAuthenticated 
              ? const RoleSelectionScreen() 
              : (_userRole == 'shop_owner' 
                  ? const DashboardScreen() 
                  : _userRole == 'field_executive'
                      ? const fe.DashboardScreen()
                      : Scaffold(
                          appBar: AppBar(title: const Text('Module Not Integrated')),
                          body: const Center(child: Text('This module will be integrated shortly.')),
                        ))),
      debugShowCheckedModeBanner: false,
    );
  }
}
