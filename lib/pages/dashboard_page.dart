import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'camera_presensi_page.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/attendance_rules.dart';
import '../services/attendance_service.dart';
import 'login_page.dart';
import 'riwayat_kehadiran_page.dart';
import 'prosentase_page.dart';
import 'status_kehadiran_page.dart';
import 'laporan_bulanan_page.dart';
import 'dokumen_ketidakhadiran_page.dart';
import 'laporan_kendala_page.dart';
import 'package:provider/provider.dart';
import '../services/theme_manager.dart';

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

  int hariKerja = 0;
  int hadir = 0;
  int izinAlpha = 0;
  bool isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadStats();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        now = DateTime.now();
      });
    });
  }

  Future<void> _loadStats() async {
    final stats = await AttendanceService.getDashboardStats();
    if (!mounted) return;
    if (stats != null) {
      setState(() {
        hariKerja = stats['total_hari_kerja'] ?? 0;
        hadir = stats['total_hadir'] ?? 0;
        izinAlpha = (stats['total_izin'] ?? 0) + (stats['total_alpha'] ?? 0);
        isLoadingStats = false;
      });
    } else {
      setState(() {
        isLoadingStats = false;
      });
    }
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;
    setState(() {
      userName =
          prefs.getString('name') ?? prefs.getString('user_name') ?? 'Pengguna';
      userNip = prefs.getString('nip') ?? prefs.getString('user_nip') ?? '-';
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

  String get dayName {
    const hari = ['SENIN', 'SELASA', 'RABU', 'KAMIS', 'JUMAT', 'SABTU', 'MINGGU'];
    return hari[now.weekday - 1];
  }

  String get monthName {
    const bulan = ['MEI', 'FEBRUARI', 'MARET', 'APRIL', 'MEI', 'JUNI', 'JULI', 'AGUSTUS', 'SEPTEMBER', 'OKTOBER', 'NOVEMBER', 'DESEMBER'];
    return bulan[now.month - 1]; // Fallback if somehow not exactly mapped
  }

  String get greeting {
    final hour = now.hour;
    if (hour >= 0 && hour < 11) return 'Selamat Pagi,';
    if (hour >= 11 && hour < 15) return 'Selamat Siang,';
    if (hour >= 15 && hour < 19) return 'Selamat Sore,';
    return 'Selamat Malam,';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final menus = [
      DashboardMenuItem(
        title: 'Lapor Kehadiran',
        subtitle: 'Absen hari ini',
        icon: Icons.face_retouching_natural_rounded,
        color: const Color(0xFF3B82F6), // Blue
        onTap: () async {
          final nav = Navigator.of(context);
          final api = ApiService();

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => Center(child: CircularProgressIndicator(color: isDark ? Colors.cyanAccent : theme.primaryColor)),
          );

          try {
            final now = DateTime.now();
            
            if (!kDebugMode && (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday)) {
              nav.pop();
              if (!mounted) return;
              _showWarning(context, 'Hari Libur', 'Absensi tidak tersedia pada hari Sabtu dan Minggu.');
              return;
            }

            final statusRes = await api.getTodayAttendance();
            nav.pop();

            final data = statusRes['data'];
            
            if (data?['is_on_leave'] == true || data?['status'] == 'CUTI' || data?['status'] == 'IZIN') {
              if (!mounted) return;
              _showWarning(
                context, 
                'Status Cuti/Izin', 
                'Anda sedang dalam status ${data?['status'] ?? 'Cuti/Izin'}. Absensi tidak diperlukan.'
              );
              return;
            }

            final checkInAt = data?['check_in_at'];
            final apelAt = data?['apel_at'];
            final checkOutAt = data?['check_out_at'];
            final mode = AttendanceRules.getAttendanceMode(now);

            if (mode == AttendanceMode.checkOut && checkInAt == null) {
              if (!mounted) return;
              _showWarning(context, 'Peringatan Absensi', 'Anda belum melakukan absensi MASUK hari ini.');
              return;
            }

            if (mode == AttendanceMode.checkIn && checkInAt != null) {
              if (!mounted) return;
              _showWarning(context, 'Sudah Absen', 'Anda sudah melakukan absensi MASUK pada pukul $checkInAt.');
              return;
            }

            if (mode == AttendanceMode.apel && apelAt != null) {
              if (!mounted) return;
              _showWarning(context, 'Sudah Absen Apel', 'Anda sudah melakukan absensi APEL pada pukul $apelAt.');
              return;
            }

            if (mode == AttendanceMode.checkOut && checkOutAt != null) {
              if (!mounted) return;
              _showWarning(context, 'Sudah Absen', 'Anda sudah melakukan absensi PULANG pada pukul $checkOutAt.');
              return;
            }

            final result = await nav.push(
              MaterialPageRoute(builder: (_) => const CameraPresensiPage()),
            );

            if (!mounted) return;

            if (result != null && result is Map && result['success'] == true) {
              nav.push(
                MaterialPageRoute(
                  builder: (_) => RiwayatKehadiranPage(
                    fromAbsensi: true,
                    lastAbsensiMessage: result['message']?.toString(),
                  ),
                ),
              );
            }
          } catch (e) {
            nav.pop();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal mengecek status: $e')),
            );
          }
        },
        onLongPress: () {
          if (kReleaseMode) return;
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraPresensiPage(isBypass: true)));
        },
      ),
      DashboardMenuItem(
        title: 'Riwayat Absensi',
        subtitle: 'Lihat histori',
        icon: Icons.history_rounded,
        color: const Color(0xFF14B8A6), // Teal
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiwayatKehadiranPage())),
      ),
      DashboardMenuItem(
        title: 'Status Kerja',
        subtitle: 'Aktif / Nonaktif',
        icon: Icons.work_rounded,
        color: const Color(0xFF8B5CF6), // Purple
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatusKehadiranPage())),
      ),
      DashboardMenuItem(
        title: 'Laporan Bulanan',
        subtitle: 'Rekap per bulan',
        icon: Icons.assignment_rounded,
        color: const Color(0xFFF59E0B), // Orange
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LaporanBulananPage())),
      ),
      DashboardMenuItem(
        title: 'Dokumen',
        subtitle: 'Upload / unduh',
        icon: Icons.description_rounded,
        color: const Color(0xFFEF4444), // Red
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DokumenKetidakhadiranPage())),
      ),
      DashboardMenuItem(
        title: 'Laporan Kendala',
        subtitle: 'Laporkan masalah',
        icon: Icons.warning_rounded,
        color: const Color(0xFF4F46E5), // Indigo
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LaporanKendalaPage())),
      ),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Stack(
          children: [
            // Premium Background Header
            Container(
              height: 330, // Taller to cover SafeArea
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(80),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark 
                        ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                        : [const Color(0xFF075985), const Color(0xFF1E3A8A), const Color(0xFF172554)], // sky-800 -> blue-900 -> blue-950
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Decorative glowing aurora effect top right
                      Positioned(
                        right: -50,
                        top: -50,
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withOpacity(0.15),
                                Colors.white.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Decorative glow bottom left
                      Positioned(
                        left: -80,
                        bottom: -40,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.cyanAccent.withOpacity(0.1),
                                Colors.blue.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildHeaderContent(isDark),
                    const SizedBox(height: 32),
                    _buildStatsRow(isDark),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Layanan Utama', isDark),
                    const SizedBox(height: 16),
                    _buildMenuGrid(menus, isDark),
                    const SizedBox(height: 16),
                    _buildTppButton(isDark),
                    const SizedBox(height: 32),
                    _buildFooter(isDark),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderContent(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side: User info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    greeting,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withOpacity(0.9), 
                      fontSize: 14, 
                      fontWeight: FontWeight.w600
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Provider.of<ThemeManager>(context, listen: false).toggleTheme();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, 
                        color: isDark ? Colors.amberAccent : Colors.white70, 
                        size: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Keluar Aplikasi'),
                          content: const Text('Apakah Anda yakin ingin keluar?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _logout();
                              },
                              child: const Text('Keluar', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.logout_rounded, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: Colors.white, 
                  fontSize: 24, 
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.badge_rounded, color: Colors.white54, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'NIP. $userNip',
                    style: GoogleFonts.outfit(
                      color: Colors.white70, 
                      fontSize: 13, 
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Right side: Date and Time
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              dayName,
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  twoDigits(now.day),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  monthName,
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded, color: Colors.white, size: 12),
                  const SizedBox(width: 6),
                  Text(
                    '${twoDigits(now.hour)}:${twoDigits(now.minute)} • ${now.year}',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(bool isDark) {
    return Row(
      children: [
        Expanded(child: _buildStatCard(isLoadingStats ? '-' : hariKerja.toString(), 'HARI KERJA', isDark)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(isLoadingStats ? '-' : hadir.toString(), 'HADIR', isDark)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(isLoadingStats ? '-' : izinAlpha.toString(), 'IZIN/ALPHA', isDark)),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.08),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white : const Color(0xFF1E3A8A),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Icon(Icons.grid_view_rounded, color: isDark ? Colors.cyanAccent : const Color(0xFF3B82F6), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white : const Color(0xFF1E293B), 
            fontSize: 16, 
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuGrid(List<DashboardMenuItem> menus, bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85, // Dikurangi agar tinggi card bertambah dan tidak overflow
      ),
      itemCount: menus.length,
      itemBuilder: (context, index) {
        return _buildMenuCard(menus[index], isDark);
      },
    );
  }

  Widget _buildMenuCard(DashboardMenuItem item, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: item.onTap,
          onLongPress: item.onLongPress,
          borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(item.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildTppButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProsentasePage())),
          borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981), // Emerald Green
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.pie_chart_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analisis TPP',
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Evaluasi kinerja & tunjangan',
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 12,
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
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF64748B),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'v2.4.1',
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 4, height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Sistem Online',
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showWarning(BuildContext context, String title, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent),
            const SizedBox(width: 12),
            Text(
              title, 
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.w800)
            ),
          ],
        ),
        content: Text(
          message, 
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'MENGERTI', 
              style: TextStyle(color: isDark ? Colors.cyanAccent : const Color(0xFF2563EB), fontWeight: FontWeight.w900)
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  DashboardMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.onLongPress,
  });
}
