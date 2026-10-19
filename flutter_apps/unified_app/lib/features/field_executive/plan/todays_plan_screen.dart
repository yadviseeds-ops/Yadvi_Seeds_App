import 'package:flutter/material.dart';
import '../../../services/fe_service.dart';
import '../../../models/visit_model.dart';
import '../visits/visit_details_screen.dart';

class TodaysPlanScreen extends StatefulWidget {
  const TodaysPlanScreen({super.key});

  @override
  State<TodaysPlanScreen> createState() => _TodaysPlanScreenState();
}

class _TodaysPlanScreenState extends State<TodaysPlanScreen> {
  final _feService = FeService();
  List<VisitModel> _todayVisits = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final allVisits = await _feService.getVisits();
      setState(() {
        _todayVisits = allVisits.where((v) => v.isToday).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      appBar: AppBar(
        title: const Text("Today's Plan", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0D4A32),
        actions: [
          IconButton(onPressed: () { setState(() => _isLoading = true); _loadData(); }, icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Summary row
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D4A32), Color(0xFF1A7A55)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildCountItem('Total', _todayVisits.length, Colors.white),
                            _buildCountItem('Done', _todayVisits.where((v) => v.status == 'Visited').length, Colors.green[200]!),
                            _buildCountItem('Pending', _todayVisits.where((v) => v.status == 'Pending').length, Colors.orange[200]!),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (_todayVisits.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.event_busy, size: 56, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('No visits planned for today.', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        const Text('Visit Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D4A32))),
                        const SizedBox(height: 12),
                        ..._todayVisits.asMap().entries.map((e) => _buildPlanItem(e.key + 1, e.value)),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildCountItem(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 26)),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
      ],
    );
  }

  Widget _buildPlanItem(int seq, VisitModel v) {
    final Color statusColor = v.status == 'Visited' ? Colors.green : Colors.orange;
    final IconData statusIcon = v.status == 'Visited' ? Icons.check_circle : Icons.radio_button_unchecked;

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VisitDetailsScreen(visit: v),
          ),
        );
        if (result == true) {
          setState(() => _isLoading = true);
          _loadData();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: const Color(0xFF0D4A32), borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text('$seq', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(v.shopLocation, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(v.purpose, style: const TextStyle(color: Colors.teal, fontSize: 11)),
                ],
              ),
            ),
            Icon(statusIcon, color: statusColor, size: 24),
          ],
        ),
      ),
    );
  }
}
