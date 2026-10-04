import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/fe_service.dart';
import '../../../models/fe_profile.dart';

class MyLocationScreen extends StatefulWidget {
  const MyLocationScreen({super.key});

  @override
  State<MyLocationScreen> createState() => _MyLocationScreenState();
}

class _MyLocationScreenState extends State<MyLocationScreen> {
  final _feService = FeService();
  FeProfile? _profile;
  Position? _currentPosition;
  String _locationStatus = 'Not determined';
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await _feService.getMyProfile();
      setState(() => _profile = p);
    } catch (_) {}
  }

  Future<void> _determinePosition() async {
    setState(() {
      _isLoadingLocation = true;
      _locationStatus = 'Checking permissions...';
    });

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationStatus = 'Location services are disabled. Please enable GPS.';
        _isLoadingLocation = false;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationStatus = 'Location permission denied.';
          _isLoadingLocation = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationStatus = 'Location permission permanently denied. Please enable it in Settings.';
        _isLoadingLocation = false;
      });
      return;
    }

    try {
      setState(() => _locationStatus = 'Getting location...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      setState(() {
        _currentPosition = position;
        _locationStatus = 'Location obtained';
        _isLoadingLocation = false;
      });

      // Send to backend if we have a profile
      if (_profile != null) {
        try {
          await _feService.updateLocation(_profile!.id, position.latitude, position.longitude);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location sent to server.'), backgroundColor: Colors.green));
        } catch (_) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send location to server.'), backgroundColor: Colors.orange));
        }
      }
    } catch (e) {
      setState(() {
        _locationStatus = 'Failed to get location: ${e.toString()}';
        _isLoadingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      appBar: AppBar(
        title: const Text('My Location', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0D4A32),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // GPS status card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0D4A32), Color(0xFF1A7A55)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(
                    _currentPosition != null ? Icons.gps_fixed : Icons.gps_not_fixed,
                    color: Colors.white,
                    size: 56,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _currentPosition != null ? 'GPS Active' : 'GPS Inactive',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _locationStatus,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Current coordinates
            if (_currentPosition != null) ...[
              _buildCoordCard('Current Location', [
                _buildCoordRow('Latitude', _currentPosition!.latitude.toStringAsFixed(6)),
                _buildCoordRow('Longitude', _currentPosition!.longitude.toStringAsFixed(6)),
                _buildCoordRow('Accuracy', '${_currentPosition!.accuracy.toStringAsFixed(1)} m'),
                _buildCoordRow('Altitude', '${_currentPosition!.altitude.toStringAsFixed(1)} m'),
                _buildCoordRow('Updated', DateTime.now().toString().substring(0, 19)),
              ]),
              const SizedBox(height: 16),
            ],

            // Last known from profile
            if (_profile?.currentLat != null) ...[
              _buildCoordCard('Last Saved Location', [
                _buildCoordRow('Latitude', _profile!.currentLat!.toStringAsFixed(6)),
                _buildCoordRow('Longitude', _profile!.currentLng!.toStringAsFixed(6)),
              ]),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoadingLocation ? null : _determinePosition,
                icon: _isLoadingLocation
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: Text(_isLoadingLocation ? 'Getting Location...' : 'Update My Location', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D4A32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Location is sent to the server only when you tap "Update My Location". It is not tracked automatically.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordCard(String title, List<Widget> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D4A32), fontSize: 14)),
          const Divider(height: 16),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildCoordRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
