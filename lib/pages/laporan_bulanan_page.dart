import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LaporanBulananPage extends StatefulWidget {
  const LaporanBulananPage({super.key});

  @override
  State<LaporanBulananPage> createState() => _LaporanBulananPageState();
}

class _LaporanBulananPageState extends State<LaporanBulananPage> {
  final ApiService _apiService = ApiService();

  bool isLoading = true;
  String errorMessage = '';
  List<dynamic> allAttendance = [];
  List<dynamic> filteredAttendance = [];

  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    loadMonthlyReport();
  }

  Future<void> loadMonthlyReport() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final result = await _apiService.getMonthlyAttendanceReport(
        month: selectedMonth,
        year: selectedYear,
      );

      if (!mounted) return;

      allAttendance = result['data'] ?? [];
      _applyFilter();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  void _applyFilter() {
    filteredAttendance = allAttendance.where((item) {
      final rawDate = item['attendance_date'];
      if (rawDate == null) return false;
      try {
        final date = DateTime.parse(rawDate.toString());
        return date.month == selectedMonth && date.year == selectedYear;
      } catch (_) {
        return false;
      }
    }).toList();

    filteredAttendance.sort((a, b) {
      final aDate = DateTime.tryParse(a['attendance_date'].toString());
      final bDate = DateTime.tryParse(b['attendance_date'].toString());
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });
  }

  String monthName(int month) {
    const months = ['', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return months[month];
  }

  int getLateMinutes(dynamic item) {
    final rawDate = item['attendance_date'];
    if (rawDate == null) return 0;
    final date = DateTime.tryParse(rawDate.toString());
    if (date == null) return 0;
    
    final checkIn = item['check_in_at']?.toString();
    if (checkIn == null || checkIn.isEmpty) return 0;
    
    final parts = checkIn.split(':');
    if (parts.length < 2) return 0;
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final checkInMins = (hour * 60) + minute;
    
    final targetMins = (date.weekday == DateTime.monday) ? (8 * 60 + 15) : (7 * 60 + 30);
    return (checkInMins > targetMins) ? (checkInMins - targetMins) : 0;
  }

  int getEarlyLeaveMinutes(dynamic item) {
    final rawDate = item['attendance_date'];
    if (rawDate == null) return 0;
    final date = DateTime.tryParse(rawDate.toString());
    if (date == null) return 0;
    
    final checkOut = item['check_out_at']?.toString();
    if (checkOut == null || checkOut.isEmpty) return 0;
    
    final parts = checkOut.split(':');
    if (parts.length < 2) return 0;
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final checkOutMins = (hour * 60) + minute;
    
    final targetMins = (date.weekday == DateTime.friday) ? (15 * 60) : (15 * 60 + 30);
    return (targetMins > checkOutMins) ? (targetMins - checkOutMins) : 0;
  }

  int countByLateRange(int min, int max) => filteredAttendance.where((e) {
    final late = getLateMinutes(e);
    return late >= min && late <= max;
  }).length;

  int countByLateAbove(int min) => filteredAttendance.where((e) {
    final late = getLateMinutes(e);
    return late > min;
  }).length;

  int countByEarlyLeaveRange(int min, int max) => filteredAttendance.where((e) {
    final early = getEarlyLeaveMinutes(e);
    return early >= min && early <= max;
  }).length;

  int countByEarlyLeaveAbove(int min) => filteredAttendance.where((e) {
    final early = getEarlyLeaveMinutes(e);
    return early > min;
  }).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Laporan Bulanan',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
          ),
        ),
        child: Stack(
          children: [
            // Batik Watermark Background
            Positioned.fill(
              child: Opacity(
                opacity: isDark ? 0.04 : 0.15,
                child: Image.asset(
                  'assets/images/batik_pattern.png', 
                  fit: BoxFit.cover,
                  color: isDark ? null : Colors.blueGrey.withOpacity(0.12),
                ),
              ),
            ),
            Column(
              children: [
                _buildSelectionPanel(isDark),
                Expanded(
                  child: RefreshIndicator(
                    color: isDark ? Colors.cyanAccent : const Color(0xFF2563EB),
                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    onRefresh: loadMonthlyReport,
                    child: isLoading
                        ? Center(child: CircularProgressIndicator(color: isDark ? Colors.cyanAccent : const Color(0xFF2563EB)))
                        : errorMessage.isNotEmpty
                            ? _buildError(isDark)
                            : _buildBody(isDark),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionPanel(bool isDark) {
    final years = List.generate(5, (index) => DateTime.now().year - index);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedMonth,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                items: List.generate(12, (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text(monthName(index + 1), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700, fontSize: 14)),
                )),
                onChanged: (val) {
                  if (val != null) { setState(() => selectedMonth = val); loadMonthlyReport(); }
                },
              ),
            ),
          ),
          Container(width: 1, height: 24, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 12)),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedYear,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                items: years.map((y) => DropdownMenuItem(
                  value: y,
                  child: Text(y.toString(), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700, fontSize: 14)),
                )).toList(),
                onChanged: (val) {
                  if (val != null) { setState(() => selectedYear = val); loadMonthlyReport(); }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (filteredAttendance.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 100),
            child: Column(
              children: [
                Icon(Icons.event_busy_rounded, size: 80, color: isDark ? Colors.white12 : Colors.black12),
                const SizedBox(height: 24),
                Text('Tidak ada data bulan ini.', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      );
    }

    final tidakHadir = filteredAttendance.where((e) => e['check_in_at'] == null).length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      children: [
        _buildSectionCard(
          title: 'KEHADIRAN',
          icon: Icons.work_rounded,
          color: const Color(0xFF3B82F6),
          isDark: isDark,
          items: [
            _StatItem('Hari Kerja', '${filteredAttendance.length}', Icons.calendar_today_rounded),
          ],
        ),
        _buildSectionCard(
          title: 'KETIDAKHADIRAN',
          icon: Icons.block_rounded,
          color: const Color(0xFFF43F5E),
          isDark: isDark,
          items: [
            _StatItem('Alpha', '$tidakHadir', Icons.cancel_rounded),
            _StatItem('Izin/Sakit', '0', Icons.assignment_late_rounded),
            _StatItem('Cuti', '0', Icons.beach_access_rounded),
            _StatItem('Tugas Dinas', '0', Icons.business_center_rounded),
          ],
        ),
        _buildSectionCard(
          title: 'TERLAMBAT (TL)',
          icon: Icons.access_time_filled_rounded,
          color: const Color(0xFFF59E0B),
          isDark: isDark,
          items: [
            _StatItem('TL 1', '${countByLateRange(1, 30)}', Icons.timer_outlined),
            _StatItem('TL 2', '${countByLateRange(31, 60)}', Icons.timer_outlined),
            _StatItem('TL 3', '${countByLateRange(61, 90)}', Icons.timer_outlined),
            _StatItem('TL 4', '${countByLateAbove(90)}', Icons.timer_outlined),
          ],
        ),
        _buildSectionCard(
          title: 'PULANG AWAL (PSW)',
          icon: Icons.logout_rounded,
          color: const Color(0xFF8B5CF6),
          isDark: isDark,
          items: [
            _StatItem('PSW 1', '${countByEarlyLeaveRange(1, 30)}', Icons.login_rounded),
            _StatItem('PSW 2', '${countByEarlyLeaveRange(31, 60)}', Icons.login_rounded),
            _StatItem('PSW 3', '${countByEarlyLeaveRange(61, 90)}', Icons.login_rounded),
            _StatItem('PSW 4', '${countByEarlyLeaveAbove(90)}', Icons.login_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Color color, required bool isDark, required List<_StatItem> items}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.05), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 12),
                Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2.2,
              children: items.map((s) => Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03), shape: BoxShape.circle),
                    child: Icon(s.icon, color: isDark ? Colors.white38 : Colors.black38, size: 14),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(s.label, style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 10, fontWeight: FontWeight.w700)),
                        Text(s.value, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.error_outline_rounded, size: 64, color: Color(0xFFF43F5E)),
        const SizedBox(height: 20),
        Text(errorMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  _StatItem(this.label, this.value, this.icon);
}