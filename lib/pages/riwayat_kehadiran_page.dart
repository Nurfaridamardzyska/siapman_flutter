import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RiwayatKehadiranPage extends StatefulWidget {
  final bool fromAbsensi;
  final String? lastAbsensiMessage;

  const RiwayatKehadiranPage({
    super.key,
    this.fromAbsensi = false,
    this.lastAbsensiMessage,
  });

  @override
  State<RiwayatKehadiranPage> createState() => _RiwayatKehadiranPageState();
}

class _RiwayatKehadiranPageState extends State<RiwayatKehadiranPage> {
  final ApiService _apiService = ApiService();

  bool isLoading = true;
  String errorMessage = '';
  List<dynamic> attendanceList = [];

  static const List<String> _hariList = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];
  static const List<String> _bulanList = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

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
      if (!mounted) return;
      setState(() {
        attendanceList = result['data'] ?? [];
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

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _rawDate(dynamic item) =>
      (item['attendance_date'] ??
              item['date'] ??
              item['tanggal'] ??
              item['created_at'] ??
              '')
          .toString();

  String _hari(String raw) {
    try {
      final d = DateTime.parse(raw);
      return _hariList[d.weekday - 1];
    } catch (_) {
      return '-';
    }
  }

  String _tanggal(String raw) {
    try {
      final d = DateTime.parse(raw);
      return '${d.day.toString().padLeft(2, '0')} ${_bulanList[d.month]} ${d.year}';
    } catch (_) {
      return raw;
    }
  }

  /// Returns HH:MM (no seconds)
  String _extractTime(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    if (str.isEmpty) return '';
    if (str.contains('T')) {
      try {
        final dt = DateTime.parse(str).toLocal();
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    if (str.length >= 5 && str.contains(':')) return str.substring(0, 5);
    return str;
  }

  /// Builds the flat list of rows.
  /// Each attendance record → up to 2 rows: check-in first, check-out second.
  List<Map<String, dynamic>> get _rows {
    final rows = <Map<String, dynamic>>[];

    // Sort newest first
    final sorted = List<dynamic>.from(attendanceList)
      ..sort((a, b) {
        final aD = DateTime.tryParse(_rawDate(a));
        final bD = DateTime.tryParse(_rawDate(b));
        if (aD == null || bD == null) return 0;
        return bD.compareTo(aD);
      });

    for (final item in sorted) {
      final raw = _rawDate(item);
      final hari = _hari(raw);
      final tanggal = _tanggal(raw);

      final checkIn = _extractTime(item['check_in_at']);
      final checkOut = _extractTime(item['check_out_at']);

      // Check-out row first (larger time shown first like screenshot)
      if (checkOut.isNotEmpty) {
        rows.add({'hari': hari, 'tanggal': tanggal, 'waktu': checkOut});
      }
      // Check-in row
      if (checkIn.isNotEmpty) {
        rows.add({'hari': hari, 'tanggal': tanggal, 'waktu': checkIn});
      }
    }

    return rows;
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F6FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          'Riwayat Kehadiran',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: loadAttendanceHistory,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage.isNotEmpty
                ? _buildError()
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final rows = _rows;

    if (rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(
            child: Text(
              'Belum ada riwayat kehadiran',
              style: TextStyle(fontSize: 15, color: Colors.black45),
            ),
          ),
        ],
      );
    }

    return Container(
      color: Colors.white,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: rows.length,
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          indent: 20,
          endIndent: 20,
          color: Color(0xFFE5E7EB),
        ),
        itemBuilder: (context, index) => _buildRow(rows[index]),
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> row) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Ikon bulat biru
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sync_rounded,
              color: Color(0xFF2563EB),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),

          // Hari + tanggal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['hari'] as String,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row['tanggal'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),

          // Waktu (merah)
          Text(
            row['waktu'] as String,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return ListView(
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
    );
  }
}