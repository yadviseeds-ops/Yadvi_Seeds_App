import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/config/app_config.dart';
import 'core/storage/local_storage.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/admin_provider.dart';
import 'providers/auth_provider.dart';
import 'features/cart/cart_provider.dart';
import 'features/auth/unified_role_selection_screen.dart';
import 'features/admin/main_scaffold.dart';
import 'features/field_executive/dashboard/dashboard_screen.dart' as fe;
import 'features/dashboard/dashboard_screen.dart' as so;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Config & Custom Server URLs
  await AppConfig.init();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[main] Firebase initialization error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const YadviUnifiedApp(),
    ),
  );
}

class YadviUnifiedApp extends StatefulWidget {
  const YadviUnifiedApp({super.key});

  @override
  State<YadviUnifiedApp> createState() => _YadviUnifiedAppState();
}

class _YadviUnifiedAppState extends State<YadviUnifiedApp> {
  bool _isCheckingAuth = true;
  bool _isAuthenticated = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.checkAuthStatus();
      final hasSession = await LocalStorage.hasSession();
      final role = await LocalStorage.getRole();

      if (mounted) {
        setState(() {
          _isAuthenticated = hasSession && role != null;
          _userRole = role;
          _isCheckingAuth = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isCheckingAuth = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yadvi Seeds',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _isCheckingAuth
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              ),
            )
          : (!_isAuthenticated
              ? const UnifiedRoleSelectionScreen()
              : _buildRoleHome(_userRole)),
    );
  }

  Widget _buildRoleHome(String? role) {
    switch (role) {
      case 'administrator':
        return const AdminMainScaffold();
      case 'field_executive':
        return const fe.DashboardScreen();
      case 'shop_owner':
        return const so.DashboardScreen();
      default:
        return const UnifiedRoleSelectionScreen();
    }
  }
}
