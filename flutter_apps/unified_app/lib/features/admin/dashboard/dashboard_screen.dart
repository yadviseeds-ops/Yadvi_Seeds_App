import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/core/theme/app_theme.dart';
import 'package:unified_app/providers/admin_provider.dart';

class DashboardScreen extends StatelessWidget {
  final Function(int) onNavigateTab;

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
        child: adminProvider.isLoadingDashboard && data == null
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Title
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

                    // Top KPI Grid
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.35,
                      children: [
                        _buildKpiCard(
                          title: 'Total Orders',
                          value: '${data?.totalOrders ?? 0}',
                          subtitle: '${data?.pendingOrders ?? 0} Pending Confirmation',
                          icon: Icons.shopping_bag_outlined,
                          color: Colors.blue.shade700,
                          onTap: () => onNavigateTab(1),
                        ),
                        _buildKpiCard(
                          title: 'In-Transit',
                          value: '${data?.dispatchedOrders ?? 0}',
                          subtitle: '${data?.deliveredOrders ?? 0} Delivered',
                          icon: Icons.local_shipping_outlined,
                          color: Colors.purple.shade700,
                          onTap: () => onNavigateTab(1),
                        ),
                        _buildKpiCard(
                          title: 'Dealers / Shops',
                          value: '${data?.totalShops ?? 0}',
                          subtitle: 'Verified Network',
                          icon: Icons.storefront_outlined,
                          color: Colors.teal.shade700,
                          onTap: () => onNavigateTab(4),
                        ),
                        _buildKpiCard(
                          title: 'Field Team',
                          value: '${data?.totalExecutives ?? 0}',
                          subtitle: '${data?.presentToday ?? 0} Active Today',
                          icon: Icons.badge_outlined,
                          color: Colors.orange.shade800,
                          onTap: () => onNavigateTab(3),
                        ),
                        _buildKpiCard(
                          title: 'Catalog',
                          value: '${data?.totalProducts ?? 0}',
                          subtitle: 'Active Seed Varieties',
                          icon: Icons.inventory_2_outlined,
                          color: AppTheme.primaryGreen,
                          onTap: () => onNavigateTab(2),
                        ),
                        _buildKpiCard(
                          title: 'Visits Today',
                          value: '${data?.totalVisitsToday ?? 0}',
                          subtitle: '${data?.completedVisitsToday ?? 0} Completed',
                          icon: Icons.location_on_outlined,
                          color: Colors.indigo.shade700,
                          onTap: () {},
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

                    // Quick Action List
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE8F5E9),
                              child: Icon(Icons.add_shopping_cart, color: AppTheme.primaryGreen),
                            ),
                            title: const Text('Manage Orders', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Review dealer orders and approve dispatches'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => onNavigateTab(1),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE0F2F1),
                              child: Icon(Icons.add_box_outlined, color: Colors.teal),
                            ),
                            title: const Text('Inventory & Products', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Update seed varieties, stock quantity (kg) and details'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => onNavigateTab(2),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFFFF3E0),
                              child: Icon(Icons.person_add_alt_1_outlined, color: Colors.orange),
                            ),
                            title: const Text('Field Sales Force', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Monitor sales officers, territories and live activity'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => onNavigateTab(3),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFEDE7F6),
                              child: Icon(Icons.store_mall_directory_outlined, color: Colors.purple),
                            ),
                            title: const Text('Dealers Network', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Assign officers and manage retail shops'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => onNavigateTab(4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
                Icon(icon, size: 20, color: color),
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
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
