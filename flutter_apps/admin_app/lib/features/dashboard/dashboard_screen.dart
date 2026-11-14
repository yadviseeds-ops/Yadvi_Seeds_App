import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';
import '../reports/eod_reports_screen.dart';
import '../shipments/shipments_screen.dart';
import '../visits/visits_screen.dart';

class DashboardScreen extends StatelessWidget {
  final void Function(int tabIndex, {String? orderFilter}) onNavigateTab;

  const DashboardScreen({super.key, required this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final data = adminProvider.dashboardData;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: RefreshIndicator(
        onRefresh: () => adminProvider.fetchDashboard(),
        color: AppTheme.primaryGreen,
        child: _buildBody(context, adminProvider, data),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AdminProvider adminProvider,
    dynamic data,
  ) {
    if (adminProvider.isLoadingDashboard && data == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      );
    }

    if (data == null && adminProvider.error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_outlined,
                    size: 52, color: Colors.red.shade300),
                const SizedBox(height: 14),
                const Text(
                  'Failed to load dashboard metrics',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  adminProvider.error ??
                      'Please verify your connection and try again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () => adminProvider.fetchDashboard(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with refresh action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Executive Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primaryGreen),
                tooltip: 'Refresh Metrics',
                onPressed: () => adminProvider.fetchDashboard(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 8 Real-Data Functional KPI Cards
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.22,
            children: [
              // 1. Total Orders -> Orders tab (All)
              _buildKpiCard(
                title: 'Total Orders',
                value: '${data?.totalOrders ?? 0}',
                subtitle: '${data?.deliveredOrders ?? 0} Delivered',
                icon: Icons.shopping_bag_outlined,
                color: Colors.blue.shade700,
                onTap: () => onNavigateTab(1, orderFilter: 'All'),
              ),

              // 2. Pending Orders -> Orders tab (Pending filter)
              _buildKpiCard(
                title: 'Pending Orders',
                value: '${data?.pendingOrders ?? 0}',
                subtitle: 'Awaiting Action',
                icon: Icons.pending_actions_outlined,
                color: Colors.amber.shade900,
                onTap: () => onNavigateTab(1, orderFilter: 'Pending'),
              ),

              // 3. In-Transit Shipments -> Shipments screen
              _buildKpiCard(
                title: 'In-Transit',
                value: '${data?.dispatchedOrders ?? 0}',
                subtitle: 'Active Dispatches',
                icon: Icons.local_shipping_outlined,
                color: Colors.purple.shade700,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ShipmentsScreen(),
                    ),
                  );
                },
              ),

              // 4. Field Force -> Employees tab (Tab 3)
              _buildKpiCard(
                title: 'Field Force',
                value: '${data?.totalExecutives ?? 0}',
                subtitle: '${data?.presentToday ?? 0} Active Today',
                icon: Icons.badge_outlined,
                color: Colors.teal.shade700,
                onTap: () => onNavigateTab(3),
              ),

              // 5. Shop Owners -> Shops tab (Tab 4)
              _buildKpiCard(
                title: 'Shop Owners',
                value: '${data?.totalShops ?? 0}',
                subtitle: 'Authorized Network',
                icon: Icons.storefront_outlined,
                color: Colors.indigo.shade700,
                onTap: () => onNavigateTab(4),
              ),

              // 6. Seed Varieties (Catalog) -> Products tab (Tab 2)
              _buildKpiCard(
                title: 'Seed Varieties',
                value: '${data?.totalProducts ?? 0}',
                subtitle: 'Active Catalog',
                icon: Icons.inventory_2_outlined,
                color: AppTheme.primaryGreen,
                onTap: () => onNavigateTab(2),
              ),

              // 7. Visits Today -> Visits screen
              _buildKpiCard(
                title: 'Visits Today',
                value: '${data?.totalVisitsToday ?? 0}',
                subtitle: '${data?.completedVisitsToday ?? 0} Completed',
                icon: Icons.location_on_outlined,
                color: Colors.deepOrange.shade700,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VisitsScreen(),
                    ),
                  );
                },
              ),

              // 8. Daily EOD Reports -> Admin EOD Reports screen
              _buildKpiCard(
                title: 'Daily EOD Reports',
                value: '${data?.totalEodReports ?? 0}',
                subtitle: '${data?.eodReportsToday ?? 0} Filed Today',
                icon: Icons.assignment_outlined,
                color: Colors.cyan.shade800,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EodReportsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text(
            'Operational Shortcuts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),

          // Quick Action Shortcuts
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.add_shopping_cart,
                        color: AppTheme.primaryGreen),
                  ),
                  title: const Text('Manage Orders',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                      'Review shop owner orders and approve dispatches'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onNavigateTab(1, orderFilter: 'All'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2F1),
                    child:
                        Icon(Icons.add_box_outlined, color: Colors.teal),
                  ),
                  title: const Text('Inventory & Products',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                      'Update seed varieties, stock quantity (kg) and details'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onNavigateTab(2),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF3E0),
                    child: Icon(Icons.person_add_alt_1_outlined,
                        color: Colors.orange),
                  ),
                  title: const Text('Field Sales Force',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                      'Monitor sales officers, territories and live activity'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onNavigateTab(3),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEDE7F6),
                    child: Icon(Icons.store_mall_directory_outlined,
                        color: Colors.purple),
                  ),
                  title: const Text('Shop Owner Network',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                      'Assign officers and manage retail shops'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onNavigateTab(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                ],
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
