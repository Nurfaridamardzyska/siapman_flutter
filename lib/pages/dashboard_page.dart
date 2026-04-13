import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'camera_presensi_page.dart';
import 'login_page.dart';
import 'riwayat_kehadiran_page.dart';
import 'prosentase_page.dart';
import 'status_kehadiran_page.dart';
import 'laporan_bulanan_page.dart';
import 'dokumen_ketidakhadiran_page.dart';
import 'laporan_kendala_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _timer;
  DateTime now = DateTime.now();

  String userName = 'Pengguna';
  String userNip = '-';

  @override
  void initState() {
    super.initState();
    _loadUser();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        now = DateTime.now();
      });
    });
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;
    setState(() {
      userName = prefs.getString('name') ??
          prefs.getString('user_name') ??
          'Pengguna';
      userNip = prefs.getString('nip') ??
          prefs.getString('user_nip') ??
          '-';
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  String twoDigits(int n) => n.toString().padLeft(2, '0');

  String get formattedDate {
    const hari = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];

    const bulan = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    return '${hari[now.weekday - 1]}, ${twoDigits(now.day)} ${bulan[now.month - 1]} ${now.year}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menus = [
      DashboardMenuItem(
        title: 'Lapor\nKehadiran',
        icon: Icons.camera_alt_outlined,
        color: const Color(0xFFFF6B3D),
        onTap: () async {
          final nav = Navigator.of(context);

          final result = await nav.push(
            MaterialPageRoute(
              builder: (_) => const CameraPresensiPage(),
            ),
          );

          if (!mounted) return;

          if (result != null && result is Map && result['success'] == true) {
            // Langsung buka Riwayat Kehadiran dengan banner sukses
            nav.push(
              MaterialPageRoute(
                builder: (_) => RiwayatKehadiranPage(
                  fromAbsensi: true,
                  lastAbsensiMessage: result['message']?.toString(),
                ),
              ),
            );
          }
        },
      ),
      DashboardMenuItem(
        title: 'Riwayat\nKehadiran',
        icon: Icons.compare_arrows_rounded,
        color: const Color(0xFF66CC44),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RiwayatKehadiranPage()),
          );
        },
      ),
      DashboardMenuItem(
        title: 'Status\nKehadiran',
        icon: Icons.work_outline_rounded,
        color: const Color(0xFFFF3F93),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StatusKehadiranPage(),
            ),
          );
        },
      ),
      DashboardMenuItem(
        title: 'Laporan\nBulanan',
        icon: Icons.calendar_month_outlined,
        color: const Color(0xFFE1D84A),
        onTap: () {Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LaporanBulananPage(),
      ),
    );
  },
      ),
      DashboardMenuItem(
        title: 'Dokumen\nKetidak\nhadiran',
        icon: Icons.mail_outline_rounded,
        color: const Color(0xFF3B82F6),
        onTap: () {Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DokumenKetidakhadiranPage(),
      ),
    );
  },
      ),
      DashboardMenuItem(
        title: 'Laporan\nKendala',
        icon: Icons.volume_up_outlined,
        color: const Color(0xFFFF8DA1),
        onTap: () {Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LaporanKendalaPage(),
      ),
    );
  },
),
      DashboardMenuItem(
        title: 'Prosentase',
        icon: Icons.insert_chart_outlined_rounded,
        color: const Color(0xFF8E24AA),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProsentasePage()),
          );
        },
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF2F2F31),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopSection(),
              const SizedBox(height: 18),
              _buildClockCard(),
              const SizedBox(height: 22),
              GridView.builder(
                itemCount: menus.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.60,
                ),
                itemBuilder: (context, index) {
                  final item = menus[index];
                  return _buildMenuItem(item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userNip,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        PopupMenuButton<String>(
          color: const Color(0xFF3A3A3C),
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            if (value == 'logout') {
              _logout();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem<String>(
              value: 'logout',
              child: Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClockCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF5FA6EA),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${twoDigits(now.hour)}:${twoDigits(now.minute)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 46,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: ':${twoDigits(now.second)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(DashboardMenuItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF333336),
          borderRadius: BorderRadius.circular(22),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: 36,
              color: item.color,
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                item.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardMenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  DashboardMenuItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}