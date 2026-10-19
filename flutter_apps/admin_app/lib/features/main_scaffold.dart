import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../providers/admin_provider.dart';
import '../providers/auth_provider.dart';
import 'attendance/attendance_screen.dart';
import 'auth/unified_login_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'employees/employees_screen.dart';
import 'orders/orders_screen.dart';
import 'products/products_screen.dart';
import 'reports/eod_reports_screen.dart';
import 'shops/shops_screen.dart';
import 'shipments/shipments_screen.dart';
import 'tracking/live_tracking_screen.dart';
import 'visits/visits_screen.dart';

class AdminMainScaffold extends StatefulWidget {
  const AdminMainScaffold({super.key});

  @override
  State<AdminMainScaffold> createState() => _AdminMainScaffoldState();
}

class _AdminMainScaffoldState extends State<AdminMainScaffold> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).refreshAll();
    });
  }

  void _onNavigateTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _showServerSettingsDialog() {
    final serverController = TextEditingController(text: AppConfig.apiBaseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend Server Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active backend base URL:',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: serverController,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'http://10.0.2.2:8000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final adminProvider = Provider.of<AdminProvider>(context, listen: false);
              await AppConfig.resetBaseUrl();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                adminProvider.refreshAll();
              }
            },
            child: const Text('Reset Default'),
          ),
          ElevatedButton(
            onPressed: () async {
              final adminProvider = Provider.of<AdminProvider>(context, listen: false);
              if (serverController.text.trim().isNotEmpty) {
                await AppConfig.setCustomBaseUrl(serverController.text.trim());
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
                adminProvider.refreshAll();
              }
            },
            child: const Text('Save & Reconnect'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of the Administrator Console?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              await auth.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const UnifiedLoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final adminProvider = Provider.of<AdminProvider>(context);

    final List<Widget> screens = [
      DashboardScreen(onNavigateTab: _onNavigateTab),
      const OrdersScreen(),
      const ProductsScreen(),
      const EmployeesScreen(),
      const ShopsScreen(),
    ];

    final List<String> titles = [
      'Admin Dashboard',
      'Manage Orders',
      'Products & Seeds',
      'Field Force',
      'Dealer Network',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh All Data',
            onPressed: () => adminProvider.refreshAll(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Server Settings',
            onPressed: _showServerSettingsDialog,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: AppTheme.primaryGreen,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.admin_panel_settings, size: 36, color: AppTheme.primaryGreen),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    auth.currentUser ?? 'Administrator',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Role: System Administrator',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined, color: AppTheme.primaryGreen),
              title: const Text('Dashboard'),
              selected: _currentIndex == 0,
              onTap: () {
                Navigator.pop(context);
                _onNavigateTab(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_bag_outlined, color: AppTheme.primaryGreen),
              title: const Text('Orders Management'),
              selected: _currentIndex == 1,
              onTap: () {
                Navigator.pop(context);
                _onNavigateTab(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined, color: AppTheme.primaryGreen),
              title: const Text('Products & Catalog'),
              selected: _currentIndex == 2,
              onTap: () {
                Navigator.pop(context);
                _onNavigateTab(2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_outlined, color: AppTheme.primaryGreen),
              title: const Text('Field Sales Officers'),
              selected: _currentIndex == 3,
              onTap: () {
                Navigator.pop(context);
                _onNavigateTab(3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined, color: AppTheme.primaryGreen),
              title: const Text('Dealer Network'),
              selected: _currentIndex == 4,
              onTap: () {
                Navigator.pop(context);
                _onNavigateTab(4);
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'OPERATIONS & AUDITING',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.how_to_reg_outlined, color: Colors.blue),
              title: const Text('Daily Attendance'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.place_outlined, color: Colors.orange),
              title: const Text('Field Visits Log'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const VisitsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping_outlined, color: Colors.purple),
              title: const Text('Logistics & Shipments'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ShipmentsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_outlined, color: Colors.teal),
              title: const Text('Daily EOD Reports'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const EodReportsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.gps_fixed, color: Colors.red),
              title: const Text('Live Force Tracking'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveTrackingScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout Session', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _confirmLogout();
              },
            ),
          ],
        ),
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onNavigateTab,
        indicatorColor: AppTheme.primaryGreen.withValues(alpha: 0.18),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppTheme.primaryGreen),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag, color: AppTheme.primaryGreen),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: AppTheme.primaryGreen),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: AppTheme.primaryGreen),
            label: 'Team',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront, color: AppTheme.primaryGreen),
            label: 'Dealers',
          ),
        ],
      ),
    );
  }
}
