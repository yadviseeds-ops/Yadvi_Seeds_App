import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/exit_dialog.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../auth/unified_role_selection_screen.dart';
import 'attendance/attendance_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'employees/employees_screen.dart';
import 'invoices/admin_invoices_screen.dart';
import 'orders/orders_screen.dart';
import 'products/products_screen.dart';
import 'profile/admin_profile_screen.dart';
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
  final List<int> _tabHistory = [0];
  String? _selectedOrderFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).refreshAll();
    });
  }

  void _onNavigateTab(int index, {String? orderFilter}) {
    setState(() {
      _selectedOrderFilter = orderFilter;
      _currentIndex = index;
      if (_tabHistory.isEmpty || _tabHistory.last != index) {
        _tabHistory.add(index);
      }
    });
  }

  Future<void> _handleBack() async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    if (_tabHistory.length > 1) {
      setState(() {
        _tabHistory.removeLast();
        _currentIndex = _tabHistory.last;
      });
    } else {
      final exit = await showExitConfirmationDialog(context);
      if (exit) {
        SystemNavigator.pop();
      }
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
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
                  MaterialPageRoute(builder: (_) => const UnifiedRoleSelectionScreen()),
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
      OrdersScreen(
        key: ValueKey(_selectedOrderFilter),
        initialStatus: _selectedOrderFilter,
      ),
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 96,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: _tabHistory.length > 1 ? 'Back to Previous Tab' : 'Exit Application',
                onPressed: _handleBack,
              ),
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Open Navigation Drawer',
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
            ],
          ),
          title: Text(titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh All Data',
            onPressed: () => adminProvider.refreshAll(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Admin Settings & Profile',
            onPressed: _navigateToProfile,
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Expanded(
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
                  Text(
                    auth.currentUser ?? 'Administrator',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
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
              title: const Text('Field Executives'),
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
              leading: const Icon(Icons.receipt_long_outlined, color: Colors.indigo),
              title: const Text('Invoices & Receipts'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminInvoicesScreen()));
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
          ],
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.settings_outlined, color: AppTheme.primaryGreen),
                      title: const Text('Profile & Settings'),
                      onTap: () {
                        Navigator.pop(context);
                        _navigateToProfile();
                      },
                    ),
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
            label: 'Shop Owners',
          ),
        ],
      ),
    ),
    );
  }
}
