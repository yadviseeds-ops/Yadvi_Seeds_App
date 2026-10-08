import 'package:flutter/material.dart';
import '../../../services/fe_service.dart';
import '../../../models/fe_profile.dart';
import '../../../models/visit_model.dart';
import '../../../models/order_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _feService = FeService();
  FeProfile? _profile;
  List<VisitModel> _visits = [];
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _feService.getMyProfile(),
        _feService.getVisits(),
        _feService.getMyOrders(),
      ]);
      setState(() {
        _profile = results[0] as FeProfile;
        _visits = results[1] as List<VisitModel>;
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

  @override
  Widget build(BuildContext context) {
    final todayVisits = _visits.where((v) => v.isToday).toList();
    final completed = todayVisits.where((v) => v.status == 'Visited').length;
    final pending = todayVisits.where((v) => v.status == 'Pending').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              backgroundColor: const Color(0xFF0D4A32),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0D4A32), Color(0xFF1A7A55)],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFF2EA86A),
                                radius: 22,
                                child: Icon(Icons.person, color: Colors.white, size: 26),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isLoading ? 'Loading...' : 'Good Day, ${_profile?.fullName.split(' ').first ?? 'Executive'}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _profile?.designation ?? '',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off, size: 56, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Summary cards
                    _buildSectionTitle("Today's Summary"),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildStatCard('Total Visits', '${todayVisits.length}', Icons.store, const Color(0xFF0D4A32)),
                        const SizedBox(width: 10),
                        _buildStatCard('Completed', '$completed', Icons.check_circle, Colors.green[700]!),
                      ],
                    ),
                    const SizedBox(height: 10),
                        _buildStatCard('Pending', '$pending', Icons.access_time, Colors.orange[700]!),
                    Row(
                      children: [
                        _buildStatCard('Assigned Orders', '${_orders.length}', Icons.shopping_bag, Colors.teal[700]!),
                        const SizedBox(width: 10),
                        _buildStatCard('Territory', _profile?.assignedTerritory ?? '-', Icons.map, const Color(0xFF0D4A32)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Today's visits list
                    _buildSectionTitle("Today's Visits"),
                    const SizedBox(height: 10),
                    if (todayVisits.isEmpty)
                      _buildEmptyCard("No visits scheduled for today.")
                    else
                      ...todayVisits.map((v) => _buildVisitCard(v)),

                    const SizedBox(height: 20),
                    // Orders preview
                    _buildSectionTitle("Assigned Orders"),
                    const SizedBox(height: 10),
                    if (_orders.isEmpty)
                      _buildEmptyCard("No orders currently assigned to you.")
                    else
                      ..._orders.take(3).map((o) => _buildOrderCard(o)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D4A32)));
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitCard(VisitModel v) {
    final Color statusColor = v.status == 'Visited'
        ? Colors.green
        : Colors.orange;
    final IconData statusIcon = v.status == 'Visited'
        ? Icons.check_circle
        : Icons.access_time;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(v.shopLocation, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(v.status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel o) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_bag, color: Color(0xFF0D4A32), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace')),
                Text(o.shopName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text('${o.totalQuantityBags} Bags', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D4A32))),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(child: Text(msg, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center)),
    );
  }
}
