import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/storage/local_storage.dart';
import '../../core/widgets/exit_dialog.dart';
import '../catalogue/catalogue_screen.dart';
import '../cart/cart_provider.dart';
import '../cart/cart_screen.dart';
import '../orders/my_orders_screen.dart';
import 'home_tab.dart';
import 'profile_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final List<int> _tabHistory = [0];

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeTab(onTabSelected: _onTabTapped, onBack: _handleBack),
      CatalogueScreen(onBack: _handleBack),
      CartScreen(onBack: _handleBack, onBrowseCatalogue: () => _onTabTapped(1)),
      MyOrdersScreen(onBack: _handleBack),
      ProfileTab(onBack: _handleBack),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final userData = await LocalStorage.getUserData();
        final userId = userData['id'] ?? 'shop_owner_default';
        if (mounted) {
          Provider.of<CartProvider>(context, listen: false).initForAccount(userId);
        }
      } catch (e) {
        debugPrint('[DashboardScreen] Error initializing cart: $e');
      }
    });
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
        if (_tabHistory.isEmpty || _tabHistory.last != index) {
          _tabHistory.add(index);
        }
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: Consumer<CartProvider>(
          builder: (context, cart, _) {
            return BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.green[800],
              unselectedItemColor: Colors.grey,
              items: [
                const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                const BottomNavigationBarItem(
                    icon: Icon(Icons.shopping_bag), label: 'Products'),
                BottomNavigationBarItem(
                  icon: Badge(
                    isLabelVisible: cart.distinctProductCount > 0,
                    label: Text('${cart.distinctProductCount}'),
                    child: const Icon(Icons.shopping_cart),
                  ),
                  label: 'Cart',
                ),
                const BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Orders'),
                const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
              ],
            );
          },
        ),
      ),
    );
  }
}
