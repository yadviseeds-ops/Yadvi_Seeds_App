import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/exit_dialog.dart';
import '../home/home_screen.dart';
import '../plan/todays_plan_screen.dart';
import '../visits/visits_screen.dart';
import '../orders/orders_screen.dart';
import '../eod/eod_report_screen.dart';
import '../profile/profile_screen.dart';
import '../../../services/fe_service.dart';

class DashboardScreen extends StatefulWidget {
  final FeService? feService;

  const DashboardScreen({super.key, this.feService});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final List<int> _tabHistory = [0];
  final _homeKey = GlobalKey<HomeScreenState>();
  final _planKey = GlobalKey<TodaysPlanScreenState>();
  final _visitsKey = GlobalKey<VisitsScreenState>();
  final _eodKey = GlobalKey<EodReportScreenState>();
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
    _screens = [
      HomeScreen(key: _homeKey, feService: widget.feService, onBack: _handleBack),
      TodaysPlanScreen(key: _planKey, feService: widget.feService, onBack: _handleBack),
      VisitsScreen(key: _visitsKey, feService: widget.feService, onBack: _handleBack),
      OrdersScreen(feService: widget.feService, onBack: _handleBack),
      EodReportScreen(key: _eodKey, feService: widget.feService, onBack: _handleBack),
      ProfileScreen(feService: widget.feService, onBack: _handleBack),
    ];
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
    if (index == 0) {
      _homeKey.currentState?.loadData();
    } else if (index == 1) {
      _planKey.currentState?.loadData();
    } else if (index == 2) {
      _visitsKey.currentState?.loadVisits();
    } else if (index == 4) {
      _eodKey.currentState?.loadData();
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
  void dispose() {
    _gpsTimer?.cancel();
    (widget.feService ?? FeService()).stopDailyGps();
    super.dispose();
  }

  final List<BottomNavigationBarItem> _navItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Plan'),
    BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Visits'),
    BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Orders'),
    BottomNavigationBarItem(icon: Icon(Icons.summarize), label: 'EOD'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF0D4A32),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 11,
          unselectedFontSize: 10,
          items: _navItems,
        ),
      ),
    );
  }

  Timer? _gpsTimer;

  void _startLocationUpdates() {
    _sendLiveLocation();
    _gpsTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _sendLiveLocation();
    });
  }

  Future<void> _sendLiveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final fe = widget.feService ?? FeService();
      await fe.updateLocation(
        position.latitude,
        position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
      );
    } catch (_) {}
  }



}
