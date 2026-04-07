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
      final result = await _apiService.getAttendanceHistory();

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
    const months = [
      '',
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
    return months[month];
  }

  String formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '-';

    try {
      final date = DateTime.parse(rawDate);
      return '${date.day.toString().padLeft(2, '0')} ${monthName(date.month)} ${date.year}';
    } catch (_) {
      return rawDate;
    }
  }

  DateTime? parseAttendanceDate(dynamic item) {
    final raw = item['attendance_date'];
    if (raw == null) return null;

    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  int? parseMinutes(String? time) {
    if (time == null || time.isEmpty) return null;

    try {
      final parts = time.split(':');
      if (parts.length < 2) return null;

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return (hour * 60) + minute;
    } catch (_) {
      return null;
    }
  }

  String formatTime(dynamic value) {
    if (value == null) return '-';

    final str = value.toString();
    if (str.isEmpty) return '-';

    try {
      if (str.contains('T')) {
        final dt = DateTime.parse(str).toLocal();
        final hh = dt.hour.toString().padLeft(2, '0');
        final mm = dt.minute.toString().padLeft(2, '0');
        return '$hh:$mm';
      }

      if (str.length >= 5 && str.contains(':')) {
        return str.substring(0, 5);
      }

      return str;
    } catch (_) {
      return str;
    }
  }

  int getTargetCheckInMinutes(DateTime date) {
    // Aturan reguler:
    // Senin setelah apel pagi: 08:15
    // Selasa-Kamis: 07:30
    // Jumat: 07:30
    if (date.weekday == DateTime.monday) {
      return 8 * 60 + 15;
    }
    return 7 * 60 + 30;
  }

  int getTargetCheckOutMinutes(DateTime date) {
    // Senin-Kamis: 15:30
    // Jumat: 15:00
    if (date.weekday == DateTime.friday) {
      return 15 * 60;
    }
    return 15 * 60 + 30;
  }

  int getLateMinutes(dynamic item) {
    final date = parseAttendanceDate(item);
    if (date == null) return 0;

    final checkIn = parseMinutes(item['check_in_at']?.toString());
    if (checkIn == null) return 0;

    final target = getTargetCheckInMinutes(date);
    final diff = checkIn - target;

    return diff > 0 ? diff : 0;
  }

  int getEarlyLeaveMinutes(dynamic item) {
    final date = parseAttendanceDate(item);
    if (date == null) return 0;

    final checkOut = parseMinutes(item['check_out_at']?.toString());
    if (checkOut == null) return 0;

    final target = getTargetCheckOutMinutes(date);
    final diff = target - checkOut;

    return diff > 0 ? diff : 0;
  }

  int countByLateRange(int min, int max) {
    return filteredAttendance.where((e) {
      final late = getLateMinutes(e);
      return late >= min && late <= max;
    }).length;
  }

  int countByLateAbove(int min) {
    return filteredAttendance.where((e) {
      final late = getLateMinutes(e);
      return late > min;
    }).length;
  }

  int countByEarlyLeaveRange(int min, int max) {
    return filteredAttendance.where((e) {
      final early = getEarlyLeaveMinutes(e);
      return early >= min && early <= max;
    }).length;
  }

  int countByEarlyLeaveAbove(int min) {
    return filteredAttendance.where((e) {
      final early = getEarlyLeaveMinutes(e);
      return early > min;
    }).length;
  }

  int get hariKerja => filteredAttendance.length;

  int get tidakHadir {
    return filteredAttendance.where((e) {
      final checkIn = e['check_in_at'];
      return checkIn == null || checkIn.toString().isEmpty;
    }).length;
  }

  int get tl1 => countByLateRange(1, 30);
  int get tl2 => countByLateRange(31, 60);
  int get tl3 => countByLateRange(61, 90);
  int get tl4 => countByLateAbove(90);

  int get psw1 => countByEarlyLeaveRange(1, 30);
  int get psw2 => countByEarlyLeaveRange(31, 60);
  int get psw3 => countByEarlyLeaveRange(61, 90);
  int get psw4 => countByEarlyLeaveAbove(90);

  Widget buildFilterSection() {
    final years = List.generate(5, (index) => DateTime.now().year - index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih Bulan',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: selectedMonth,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: UnderlineInputBorder(),
                ),
                items: List.generate(
                  12,
                  (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text(monthName(index + 1)),
                  ),
                ),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedMonth = value;
                    _applyFilter();
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<int>(
                value: selectedYear,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: UnderlineInputBorder(),
                ),
                items: years
                    .map(
                      (year) => DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedYear = value;
                    _applyFilter();
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(height: 2, color: Colors.black87),
      ],
    );
  }

  Widget buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<String> lines,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              child: Icon(
                icon,
                color: iconColor,
                size: 44,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...lines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          line,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: Colors.black38, height: 1),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: loadMonthlyReport,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 120),
            const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadMonthlyReport,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        children: [
          buildFilterSection(),
          const SizedBox(height: 26),
          buildSection(
            title: 'Kehadiran',
            icon: Icons.work,
            iconColor: Colors.blue,
            lines: [
              '-Hari Kerja : $hariKerja',
            ],
          ),
          buildSection(
            title: 'Ketidakhadiran',
            icon: Icons.block,
            iconColor: Colors.grey,
            lines: [
              '-Kendala Mesin : 0',
              '-Tugas Dinas : 0',
              '-Tugas Belajar : 0',
              '-Sakit : 0',
              '-Ijin : 0',
              '-Cuti : 0',
              '-Alpha : $tidakHadir',
              '-Tidak Apel : 0',
            ],
          ),
          buildSection(
            title: 'Terlambat',
            icon: Icons.arrow_downward,
            iconColor: Colors.green,
            lines: [
              '-TL1 : $tl1',
              '-TL2 : $tl2',
              '-TL3 : $tl3',
              '-TL4 : $tl4',
            ],
          ),
          buildSection(
            title: 'Pulang Sebelum Waktu',
            icon: Icons.arrow_upward,
            iconColor: Colors.red,
            lines: [
              '-PSW1 : $psw1',
              '-PSW2 : $psw2',
              '-PSW3 : $psw3',
              '-PSW4 : $psw4',
            ],
          ),
          if (filteredAttendance.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Belum ada data kehadiran untuk ${monthName(selectedMonth)} $selectedYear',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F6FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Laporan Bulanan',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: buildBody(),
    );
  }
}