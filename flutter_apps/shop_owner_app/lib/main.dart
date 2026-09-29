import 'package:flutter/material.dart';
import 'core/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';

import 'package:provider/provider.dart';
import 'features/cart/cart_provider.dart';

void main() {
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

  @override
  void initState() {
    super.initState();
    _checkAuth();
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
      title: 'Yadvi Shop Owner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        fontFamily: 'Roboto', // Professional typography fallback
      ),
      home: _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)))
          : (_isAuthenticated ? const DashboardScreen() : const LoginScreen()),
      debugShowCheckedModeBanner: false,
    );
  }
}
