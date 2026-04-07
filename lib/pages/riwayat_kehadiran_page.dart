import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RiwayatKehadiranPage extends StatefulWidget {
  const RiwayatKehadiranPage({super.key});

  @override
  State<RiwayatKehadiranPage> createState() => _RiwayatKehadiranPageState();
}

class _RiwayatKehadiranPageState extends State<RiwayatKehadiranPage> {
  final ApiService _apiService = ApiService();

  bool isLoading = true;
  String errorMessage = '';
  List<dynamic> attendanceList = [];

  @override
  void initState() {
    super.initState();
    loadAttendanceHistory();
  }

  Future<void> loadAttendanceHistory() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final result = await _apiService.getAttendanceHistory();

      if (result['success'] == true || result['data'] != null) {
        setState(() {
          attendanceList = result['data'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = result['message'] ?? 'Gagal memuat riwayat kehadiran';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Terjadi kesalahan: $e';
        isLoading = false;
      });
    }
  }

  String formatHariIndonesia(DateTime date) {
    const hari = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return hari[date.weekday - 1];
  }

  String formatBulanIndonesia(int month) {
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
    return bulan[month - 1];
  }

  String formatTanggal(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '-';

    try {
      final date = DateTime.parse(rawDate);
      return '${date.day.toString().padLeft(2, '0')} ${formatBulanIndonesia(date.month)} ${date.year}';
    } catch (_) {
      return rawDate;
    }
  }

  String formatHari(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '-';

    try {
      final date = DateTime.parse(rawDate);
      return formatHariIndonesia(date);
    } catch (_) {
      return '-';
    }
  }

  String formatJam(dynamic item) {
    final checkIn = item['check_in_at'];
    final checkOut = item['check_out_at'];

    String extractTime(dynamic value) {
      if (value == null) return '-';
      final str = value.toString();

      if (str.contains('T')) {
        try {
          final dt = DateTime.parse(str).toLocal();
          final hh = dt.hour.toString().padLeft(2, '0');
          final mm = dt.minute.toString().padLeft(2, '0');
          return '$hh:$mm';
        } catch (_) {}
      }

      if (str.length >= 5 && str.contains(':')) {
        return str.substring(0, 5);
      }

      return str;
    }

    if (checkIn != null && checkOut == null) {
      return extractTime(checkIn);
    }

    if (checkOut != null) {
      return extractTime(checkOut);
    }

    if (checkIn != null) {
      return extractTime(checkIn);
    }

    return '-';
  }

  Color getJamColor(dynamic item) {
    final checkOut = item['check_out_at'];
    if (checkOut != null && checkOut.toString().isNotEmpty) {
      return const Color(0xFFE85D2A);
    }
    return const Color(0xFFE85D2A);
  }

  String ambilTanggalItem(dynamic item) {
    return (item['attendance_date'] ??
            item['date'] ??
            item['tanggal'] ??
            item['created_at'] ??
            '')
        .toString();
  }

  Widget buildHistoryItem(dynamic item) {
    final rawDate = ambilTanggalItem(item);
    final hari = formatHari(rawDate);
    final tanggal = formatTanggal(rawDate);
    final jam = formatJam(item);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFD9D9D9),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: Color(0xFF3DA5F4),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hari,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tanggal,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Text(
            jam,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: getJamColor(item),
            ),
          ),
        ],
      ),
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
        onRefresh: loadAttendanceHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 120),
            Icon(
              Icons.info_outline,
              size: 64,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: loadAttendanceHistory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3DA5F4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Coba Lagi'),
              ),
            ),
          ],
        ),
      );
    }

    if (attendanceList.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadAttendanceHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 120),
            Icon(
              Icons.history_toggle_off,
              size: 64,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada riwayat kehadiran',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadAttendanceHistory,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: attendanceList.length,
        itemBuilder: (context, index) {
          final item = attendanceList[index];
          return buildHistoryItem(item);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F7FB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Riwayat Kehadiran',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 19,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: buildBody(),
    );
  }
}