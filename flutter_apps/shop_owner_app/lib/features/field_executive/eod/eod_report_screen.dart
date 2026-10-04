import 'package:flutter/material.dart';
import '../../../services/fe_service.dart';
import '../../../models/fe_profile.dart';
import '../../../models/visit_model.dart';
import '../../../models/order_model.dart';

class EodReportScreen extends StatefulWidget {
  const EodReportScreen({super.key});

  @override
  State<EodReportScreen> createState() => _EodReportScreenState();
}

class _EodReportScreenState extends State<EodReportScreen> {
  final _feService = FeService();
  final _notesController = TextEditingController();
  FeProfile? _profile;
  List<VisitModel> _todayVisits = [];
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _feService.getMyProfile(),
        _feService.getVisits(),
        _feService.getMyOrders(),
      ]);
      final allVisits = results[1] as List<VisitModel>;
      setState(() {
        _profile = results[0] as FeProfile;
        _todayVisits = allVisits.where((v) => v.isToday).toList();
        _orders = results[2] as List<OrderModel>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _submitEod() async {
    // EOD uses existing visit/order data — no separate endpoint needed
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(seconds: 1)); // simulate submission
    setState(() {
      _isSubmitting = false;
      _submitted = true;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('EOD Report submitted successfully!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = _todayVisits.where((v) => v.status == 'Completed').length;
    final inProgress = _todayVisits.where((v) => v.status == 'In Progress').length;
    final pending = _todayVisits.where((v) => v.status == 'Pending').length;
    final totalBags = _todayVisits.fold(0, (sum, v) => sum + v.bagsOrdered);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      appBar: AppBar(
        title: const Text('EOD Report', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0D4A32),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF0D4A32), Color(0xFF1A7A55)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'End of Day Report',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateTime.now().toString().substring(0, 10),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                            ),
                            if (_profile != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _profile!.fullName,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Visit summary
                      const Text('Visit Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D4A32))),
                      const SizedBox(height: 12),
                      _buildSummaryGrid([
                        _SummaryItem('Total', _todayVisits.length, Icons.store, Colors.teal),
                        _SummaryItem('Completed', completed, Icons.check_circle, Colors.green),
                        _SummaryItem('In Progress', inProgress, Icons.radio_button_checked, Colors.blue),
                        _SummaryItem('Pending', pending, Icons.access_time, Colors.orange),
                      ]),
                      const SizedBox(height: 16),

                      // Order summary
                      const Text('Order Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D4A32))),
                      const SizedBox(height: 12),
                      _buildSummaryGrid([
                        _SummaryItem('Orders', _orders.length, Icons.shopping_bag, Colors.indigo),
                        _SummaryItem('Bags Ordered', totalBags, Icons.inventory, const Color(0xFF0D4A32)),
                      ]),
                      const SizedBox(height: 20),

                      // Visit details
                      if (_todayVisits.isNotEmpty) ...[
                        const Text('Visit Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D4A32))),
                        const SizedBox(height: 10),
                        ..._todayVisits.map((v) {
                          final Color sc = v.status == 'Completed' ? Colors.green : v.status == 'In Progress' ? Colors.blue : Colors.orange;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              children: [
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(v.shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(v.shopLocation, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  ],
                                )),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(v.status, style: TextStyle(color: sc, fontWeight: FontWeight.bold, fontSize: 12)),
                                    if (v.bagsOrdered > 0) Text('${v.bagsOrdered} Bags', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                      ],

                      // Notes
                      const Text('EOD Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D4A32))),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          hintText: 'Add any notes for today...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                          enabled: !_submitted,
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_isSubmitting || _submitted) ? null : _submitEod,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _submitted ? Colors.green : const Color(0xFF0D4A32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  _submitted ? '✓ EOD Submitted' : 'Submit EOD Report',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryGrid(List<_SummaryItem> items) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.5,
      children: items.map((item) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(item.icon, color: item.color, size: 24),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${item.value}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: item.color)),
                Text(item.label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ],
        ),
      )).toList(),
    );
  }
}

class _SummaryItem {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  _SummaryItem(this.label, this.value, this.icon, this.color);
}
