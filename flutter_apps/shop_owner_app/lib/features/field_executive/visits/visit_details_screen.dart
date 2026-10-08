import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/visit_model.dart';
import '../../../services/fe_service.dart';

class VisitDetailsScreen extends StatefulWidget {
  final VisitModel visit;

  const VisitDetailsScreen({super.key, required this.visit});

  @override
  State<VisitDetailsScreen> createState() => _VisitDetailsScreenState();
}

class _VisitDetailsScreenState extends State<VisitDetailsScreen> {
  final _feService = FeService();
  final _notesController = TextEditingController();
  late VisitModel _visit;
  bool _isUploading = false;
  XFile? _selectedImage;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _visit = widget.visit;
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text('Choose Photo Source', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Browse Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
    if (image != null) {
      // Get GPS eagerly for preview
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied.')));
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied.')));
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _selectedImage = image;
        _currentPosition = position;
      });
    }
  }

  Future<void> _submitVisit() async {
    if (_selectedImage == null || _currentPosition == null) return;
    
    setState(() => _isUploading = true);
    try {
      final updatedVisit = await _feService.uploadVisitPhoto(
        _visit.id,
        lat: _currentPosition!.latitude,
        lng: _currentPosition!.longitude,
        photoPath: _selectedImage!.path,
        notes: _notesController.text,
      );

      setState(() {
        _visit = updatedVisit;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visit submitted successfully')));
        Navigator.pop(context, true); // return true to indicate refresh needed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visit Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D4A32),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_visit.shopName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D4A32))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(_visit.shopLocation, style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _visit.status == 'Visited' ? Colors.green[100] : Colors.orange[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _visit.status,
                            style: TextStyle(
                              color: _visit.status == 'Visited' ? Colors.green[800] : Colors.orange[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            if (_visit.status == 'Pending') ...[
              const Text('Visit Proof', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D4A32))),
              const SizedBox(height: 12),
              
              if (_selectedImage != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_selectedImage!.path), height: 250, fit: BoxFit.cover),
                ),
                const SizedBox(height: 16),
                if (_currentPosition != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.gps_fixed, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Lat: ${_currentPosition!.latitude.toStringAsFixed(6)} Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Time: ${DateTime.now().toIso8601String()}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isUploading ? null : _pickImage,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFF0D4A32)),
                        ),
                        child: const Text('Retake / Choose Another', style: TextStyle(color: Color(0xFF0D4A32))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _submitVisit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D4A32),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isUploading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Visit', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.add_a_photo, color: Colors.white),
                    label: const Text('Upload Visit Photo', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D4A32),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]
            ] else ...[
              const Text('This shop has already been visited today.', style: TextStyle(color: Colors.grey, fontSize: 16, fontStyle: FontStyle.italic)),
            ]
          ],
        ),
      ),
    );
  }
}
