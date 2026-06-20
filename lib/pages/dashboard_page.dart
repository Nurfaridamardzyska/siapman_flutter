import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'camera_presensi_page.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/attendance_rules.dart';
import 'login_page.dart';
import 'riwayat_kehadiran_page.dart';
import 'prosentase_page.dart';
import 'status_kehadiran_page.dart';
import 'laporan_bulanan_page.dart';
import 'dokumen_ketidakhadiran_page.dart';
import 'laporan_kendala_page.dart';
import 'laporan_kegiatan_page.dart';
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
        title: 'Lapor\nKehadiran',
        icon: Icons.qr_code_scanner_rounded,
        color: const Color(0xFF0EA5E9),
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
            
            // Check Weekend (Dilewati jika sedang dalam mode Dev/Debug)
            if (!kDebugMode && (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday)) {
              nav.pop();
              if (!mounted) return;
              _showWarning(context, 'Hari Libur', 'Absensi tidak tersedia pada hari Sabtu dan Minggu.');
              return;
            }

            final statusRes = await api.getTodayAttendance();
            nav.pop();

            final data = statusRes['data'];
            
            // Check Leave Status (assuming the API returns is_on_leave or similar)
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
        title: 'Riwayat\nAbsensi',
        icon: Icons.history_toggle_off_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiwayatKehadiranPage())),
      ),
      DashboardMenuItem(
        title: 'Status\nKerja',
        icon: Icons.assignment_turned_in_rounded,
        color: const Color(0xFF10B981),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatusKehadiranPage())),
      ),
      DashboardMenuItem(
        title: 'Laporan\nBulanan',
        icon: Icons.analytics_outlined,
        color: const Color(0xFFF59E0B),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LaporanBulananPage())),
      ),
      DashboardMenuItem(
        title: 'Dokumen\nKetidakhadiran',
        icon: Icons.description_outlined,
        color: const Color(0xFF3B82F6),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DokumenKetidakhadiranPage())),
      ),
      DashboardMenuItem(
        title: 'Laporan\nKendala',
        icon: Icons.report_problem_outlined,
        color: const Color(0xFFEF4444),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LaporanKendalaPage())),
      ),

      DashboardMenuItem(
        title: 'Analisis\nTPP',
        icon: Icons.insights_rounded,
        color: const Color(0xFFEC4899),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProsentasePage())),
      ),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Dynamic Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark 
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A), const Color(0xFF1E1B4B)]
                    : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
                ),
              ),
            ),
          ),
          // Subtle Animated-like background elements
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? Colors.blue[900] : Colors.blue[100])?.withOpacity(0.3),
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.03 : 0.08,
              child: Image.asset(
                'assets/images/batik_pattern.png', 
                fit: BoxFit.cover,
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),
          
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Premium App Bar / Header
              SliverAppBar(
                expandedHeight: 120,
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: _buildHeaderSection(theme, isDark),
                    ),
                  ),
                ),
              ),

              // Main Content
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          _buildPremiumClockCard(isDark),
                          const SizedBox(height: 32),
                          _buildSectionTitle('Layanan Utama', isDark),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                    SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.7,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildModernMenuCard(menus[index], isDark),
                        childCount: menus.length,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: const SizedBox(height: 80),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Colors.cyanAccent, Color(0xFF2563EB)]),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(isDark ? 0.1 : 0.3), width: 2),
            boxShadow: [
              if (!isDark) BoxShadow(color: theme.primaryColor.withOpacity(0.1), blurRadius: 10)
            ],
          ),
          child: Center(
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54, 
                  fontSize: 13, 
                  fontWeight: FontWeight.w600
                ),
              ),
              Text(
                userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87, 
                  fontSize: 20, 
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'NIP. $userNip',
                style: TextStyle(
                  color: isDark ? Colors.cyanAccent.withOpacity(0.5) : Colors.blueAccent.withOpacity(0.6), 
                  fontSize: 11, 
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        _buildActionButtons(isDark),
      ],
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        Consumer<ThemeManager>(
          builder: (context, themeManager, _) {
            IconData icon;
            if (themeManager.themeMode == ThemeMode.light) icon = Icons.wb_sunny_rounded;
            else if (themeManager.themeMode == ThemeMode.dark) icon = Icons.nightlight_round;
            else icon = Icons.brightness_auto_rounded;

            return IconButton(
              icon: Icon(icon, color: isDark ? Colors.cyanAccent.withOpacity(0.6) : Colors.blueGrey, size: 22),
              onPressed: () => themeManager.toggleTheme(),
            );
          },
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white.withOpacity(0.4) : Colors.black26),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (v) => v == 'logout' ? _logout() : null,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  const Icon(Icons.logout_rounded, color: Color(0xFFF43F5E), size: 18),
                  const SizedBox(width: 12),
                  Text(
                    'Keluar', 
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPremiumClockCard(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.blue.withOpacity(0.1)),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark 
                ? [const Color(0xFF312E81), const Color(0xFF1E1B4B)]
                : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  Icons.access_time_rounded,
                  size: 100,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      formattedDate.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 10, 
                        fontWeight: FontWeight.w800, 
                        letterSpacing: 1.2
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${twoDigits(now.hour)}:${twoDigits(now.minute)}',
                        style: GoogleFonts.outfit(
                          color: Colors.white, 
                          fontSize: 52, 
                          fontWeight: FontWeight.w900, 
                          letterSpacing: -1
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        twoDigits(now.second),
                        style: GoogleFonts.outfit(
                          color: Colors.white.withOpacity(0.4), 
                          fontSize: 22, 
                          fontWeight: FontWeight.w700
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4, 
          height: 16, 
          decoration: BoxDecoration(
            color: isDark ? Colors.cyanAccent : const Color(0xFF2563EB), 
            borderRadius: BorderRadius.circular(2)
          )
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87, 
            fontSize: 16, 
            fontWeight: FontWeight.w800, 
            letterSpacing: 0.5
          ),
        ),
      ],
    );
  }

  Widget _buildModernMenuCard(DashboardMenuItem item, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        onLongPress: item.onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark 
                  ? Colors.white.withOpacity(0.04) 
                  : Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark 
                    ? Colors.white.withOpacity(0.08) 
                    : Colors.white.withOpacity(0.5)
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(item.icon, color: item.color, size: 24),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecorativeFooter(bool isDark) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  (isDark ? Colors.cyanAccent : Colors.blueAccent).withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          Text(
            'SIAPMAN v2.0',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
        ],
      ),
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
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress; // Tambahkan field ini

  DashboardMenuItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.onLongPress,
  });
}
