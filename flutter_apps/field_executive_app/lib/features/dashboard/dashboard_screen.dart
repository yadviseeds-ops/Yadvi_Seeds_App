import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../plan/todays_plan_screen.dart';
import '../visits/visits_screen.dart';
import '../location/my_location_screen.dart';
import '../lr_tracking/lr_tracking_screen.dart';
import '../eod/eod_report_screen.dart';
import '../profile/profile_screen.dart';
import '../support/help_support_screen.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../services/fe_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _startForegroundLocationSync();
  }

  void _startForegroundLocationSync() {
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return;
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
        
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15))
        );
        
        final profile = await FeService().getMyProfile();
        await FeService().updateLocation(profile.id, position.latitude, position.longitude);
        debugPrint("Background GPS synced: ${position.latitude}, ${position.longitude}");
      } catch (e) {
        debugPrint("Foreground GPS sync error: $e");
      }
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const TodaysPlanScreen(),
    const VisitsScreen(),
    const MyLocationScreen(),
    const LrTrackingScreen(),
    const EodReportScreen(),
    const ProfileScreen(),
    const HelpSupportScreen(),
  ];

  final List<BottomNavigationBarItem> _navItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Plan'),
    BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Visits'),
    BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Location'),
    BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'LR Track'),
    BottomNavigationBarItem(icon: Icon(Icons.summarize), label: 'EOD'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: 'Support'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0D4A32),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 10,
        unselectedFontSize: 9,
        items: _navItems,
      ),
    );
  }
}