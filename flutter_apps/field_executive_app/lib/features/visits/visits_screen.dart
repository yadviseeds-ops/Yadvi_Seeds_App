import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/fe_service.dart';
import '../../models/visit_model.dart';

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> with SingleTickerProviderStateMixin {
  final _feService = FeService();
  List<VisitModel> _visits = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadVisits();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVisits() async {
    try {
      final visits = await _feService.getVisits();
      setState(() {
        _visits = visits;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _performUploadPhoto(VisitModel visit) async {
    final ImagePicker picker = ImagePicker();
    
    // Step 1: Ask for source
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

    // Step 2: Pick image
    final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
    if (image == null) return;

    // Step 3: Show preview
    final notesController = TextEditingController();
    bool isUploading = false;
    
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Visit Proof: ${visit.shopName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.file(File(image.path), height: 200, fit: BoxFit.cover),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                    if (isUploading) ...[
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 10),
                      const Text('Capturing GPS & uploading...'),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel / Retake'),
                ),
                ElevatedButton(
                  onPressed: isUploading ? null : () async {
                    setState(() => isUploading = true);
                    try {
                      // Get Location
                      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                      if (!serviceEnabled) throw Exception('Location services are disabled.');

                      LocationPermission permission = await Geolocator.checkPermission();
                      if (permission == LocationPermission.denied) {
                        permission = await Geolocator.requestPermission();
                        if (permission == LocationPermission.denied) {
                          throw Exception('Location permissions are denied.');
                        }
                      }
                      
                      if (permission == LocationPermission.deniedForever) {
                        throw Exception('Location permissions are permanently denied.');
                      }

                      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

                      // Upload
                      await _feService.uploadVisitPhoto(
                        visit.id,
                        lat: position.latitude,
                        lng: position.longitude,
                        photoPath: image.path,
                        notes: notesController.text,
                      );
                      
                      if (mounted) {
                        Navigator.pop(dialogContext); // Close dialog
                        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Visit proof uploaded successfully!')));
                      }
                      _loadVisits();
                    } catch (e) {
                      setState(() => isUploading = false);
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D4A32), foregroundColor: Colors.white),
                  child: const Text('Submit Visit Proof'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayVisits = _visits.where((v) => v.isToday).toList();
    final previousVisits = _visits.where((v) => !v.isToday).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      appBar: AppBar(
        title: const Text('Visits', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0D4A32),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: "Today (${todayVisits.length})"),
            Tab(text: "History (${previousVisits.length})"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: () { setState(() { _isLoading = true; _error = null; }); _loadVisits(); }, child: const Text('Retry')),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _loadVisits,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildVisitList(todayVisits, showActions: true),
                      _buildVisitList(previousVisits, showActions: false),
                    ],
                  ),
                ),
    );
  }

  Widget _buildVisitList(List<VisitModel> visits, {required bool showActions}) {
    if (visits.isEmpty) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 56, color: Colors.grey),
          SizedBox(height: 12),
          Text('No visits found.', style: TextStyle(color: Colors.grey)),
        ],
      ));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visits.length,
      itemBuilder: (_, i) => _buildVisitCard(visits[i], showActions: showActions),
    );
  }

  Widget _buildVisitCard(VisitModel v, {required bool showActions}) {
    final Color statusColor = v.status == 'Visited' ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D4A32).withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.store, color: Color(0xFF0D4A32), size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(v.shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D4A32)))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(v.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.location_on, v.shopLocation),
                _buildInfoRow(Icons.calendar_today, v.scheduledDate.toLocal().toString().substring(0, 16)),
                if (v.visitedAt != null) _buildInfoRow(Icons.check_circle, 'Visited at: ${v.visitedAt!.toLocal().toString().substring(11, 16)}'),
                if (v.photoUrl != null) _buildInfoRow(Icons.image, 'Photo Uploaded'),
                if (v.notes != null && v.notes!.isNotEmpty) _buildInfoRow(Icons.notes, v.notes!),
                if (v.bagsOrdered > 0) _buildInfoRow(Icons.inventory, '${v.bagsOrdered} Bags Ordered'),
                if (showActions) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (v.status == 'Pending')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _performUploadPhoto(v),
                            icon: const Icon(Icons.camera_alt, size: 16),
                            label: const Text('Upload Photo'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D4A32), foregroundColor: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.grey))),
        ],
      ),
    );
  }
}
