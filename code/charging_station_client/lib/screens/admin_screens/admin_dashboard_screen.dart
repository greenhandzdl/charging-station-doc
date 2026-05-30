import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../user_screens/login_screen.dart';
import 'station_management_screen.dart';
import 'charger_management_screen.dart';
import 'user_management_screen.dart';
import 'repair_management_screen.dart';
import 'statistics_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isSuperAdmin = auth.currentUser?.role == 'SUPER_ADMIN';

    return Scaffold(
      appBar: AppBar(
        title: const Text('管理后台'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              auth.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2,
        children: [
          _buildMenuItem(
            context,
            icon: Icons.ev_station,
            label: '充电站管理',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const StationManagementScreen()),
            ),
          ),
          _buildMenuItem(
            context,
            icon: Icons.battery_charging_full,
            label: '充电桩管理',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ChargerManagementScreen()),
            ),
          ),
          _buildMenuItem(
            context,
            icon: Icons.people,
            label: '用户管理',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const UserManagementScreen()),
            ),
          ),
          _buildMenuItem(
            context,
            icon: Icons.build,
            label: '报修管理',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const RepairManagementScreen()),
            ),
          ),
          if (isSuperAdmin)
            _buildMenuItem(
              context,
              icon: Icons.bar_chart,
              label: '统计报表',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const StatisticsScreen()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}