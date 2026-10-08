import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class GpsTestScreen extends StatefulWidget {
  const GpsTestScreen({super.key});

  @override
  State<GpsTestScreen> createState() => _GpsTestScreenState();
}

class _GpsTestScreenState extends State<GpsTestScreen> {
  bool _isLoading = false;
  String? _latitude;
  String? _longitude;
  String? _accuracy;
  String? _speed;

  Future<void> _getLocation() async {
    setState(() {
      _isLoading = true;
      _latitude = null;
      _longitude = null;
      _accuracy = null;
      _speed = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled. Please enable GPS.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      debugPrint('GPS TEST: lat=${position.latitude}');
      debugPrint('GPS TEST: lng=${position.longitude}');
      debugPrint('GPS TEST: accuracy=${position.accuracy}');
      debugPrint('GPS TEST: speed=${position.speed}');

      setState(() {
        _latitude = position.latitude.toString();
        _longitude = position.longitude.toString();
        _accuracy = position.accuracy.toString();
        _speed = position.speed.toString();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GPS Hardware Test'), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const CircularProgressIndicator(color: Colors.green)
              else if (_latitude != null) ...[
                Text('Latitude: $_latitude', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Longitude: $_longitude', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Accuracy: $_accuracy m', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Speed: $_speed m/s', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ] else
                const Text('Press button to fetch GPS data', style: TextStyle(fontSize: 16)),
              
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _getLocation,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                child: const Text('GET CURRENT LOCATION', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
