import 'package:flutter/material.dart';
import 'camera_presensi_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'BASKARA',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// JAM & TANGGAL
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade400,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: const [
                  Text(
                    'Kamis, 11 November 2025',
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '07:30:20',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// MENU GRID
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _menuItem(
                    context,
                    icon: Icons.location_on,
                    label: 'Lapor\nKehadiran',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CameraPresensiPage(),
                        ),
                      );
                    },
                  ),
                  _menuItem(
                    context,
                    icon: Icons.history,
                    label: 'Riwayat\nKehadiran',
                    color: Colors.green,
                  ),
                  _menuItem(
                    context,
                    icon: Icons.work,
                    label: 'Status\nKehadiran',
                    color: Colors.purple,
                  ),
                  _menuItem(
                    context,
                    icon: Icons.calendar_month,
                    label: 'Laporan\nBulanan',
                    color: Colors.amber,
                  ),
                  _menuItem(
                    context,
                    icon: Icons.mail,
                    label: 'Dokumen\nKetidakhadiran',
                    color: Colors.blue,
                  ),
                  _menuItem(
                    context,
                    icon: Icons.warning,
                    label: 'Laporan\nKendala',
                    color: Colors.redAccent,
                  ),
                  _menuItem(
                    context,
                    icon: Icons.bar_chart,
                    label: 'Prosentase',
                    color: Colors.deepPurple,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
