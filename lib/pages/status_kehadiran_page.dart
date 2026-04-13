import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StatusKehadiranPage extends StatefulWidget {
  const StatusKehadiranPage({super.key});

  @override
  State<StatusKehadiranPage> createState() => _StatusKehadiranPageState();
}

class _StatusKehadiranPageState extends State<StatusKehadiranPage> {
  final ApiService _apiService = ApiService();

  bool isLoading = true;
  String errorMessage = '';
  List<dynamic> allAttendance = [];

  DateTime selectedDate = DateTime.now();

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
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final result = await _apiService.getAttendanceHistory();
      if (!mounted) return;
      setState(() {
        allAttendance = result;
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

  // ─── Data for selected date ─────────────────────────────────────────────────

  Map<String, dynamic>? get _selectedRecord {
    for (final item in allAttendance) {
      final raw = (item['attendance_date'] ??
              item['date'] ??
              item['tanggal'] ??
              item['created_at'] ??
              '')
          .toString();
      try {
        final d = DateTime.parse(raw);
        if (d.year == selectedDate.year &&
            d.month == selectedDate.month &&
            d.day == selectedDate.day) {
          return Map<String, dynamic>.from(item as Map);
        }
      } catch (_) {}
    }
    return null;
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _formatTanggal(DateTime d) =>
      '${_hariList[d.weekday - 1]}, ${d.day} ${_bulanList[d.month]} ${d.year}';

  String _extractTime(dynamic value) {
    if (value == null) return '-';
    final str = value.toString();
    if (str.isEmpty) return '-';
    if (str.contains('T')) {
      try {
        final dt = DateTime.parse(str).toLocal();
        return '${dt.hour.toString().padLeft(2, '0')}:'
            '${dt.minute.toString().padLeft(2, '0')}:'
            '${dt.second.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    if (str.length >= 5 && str.contains(':')) return str;
    return str;
  }

  String _getJamKerja() {
    if (selectedDate.weekday == DateTime.monday) return '08:15:00 - 15:30:00';
    if (selectedDate.weekday == DateTime.friday) return '07:30:00 - 15:00:00';
    return '07:30:00 - 15:30:00';
  }

  bool _isTerlambat(String checkInTime) {
    if (checkInTime == '-') return false;
    final parts = checkInTime.split(':');
    if (parts.length < 2) return false;
    final mins =
        (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    final limit = selectedDate.weekday == DateTime.monday
        ? (8 * 60 + 15)
        : (7 * 60 + 30);
    return mins > limit;
  }

  // ─── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime.now(),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
    }
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
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Status Kehadiran',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage.isNotEmpty
                ? _buildError()
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final record = _selectedRecord;
    final checkIn = _extractTime(record?['check_in_at']);
    final checkOut = _extractTime(record?['check_out_at']);
    final terlambat = _isTerlambat(checkIn);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        // ── Date picker ──────────────────────────────────────────────────
        const Text(
          'Pilih Tanggal',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _pickDate,
          child: Text(
            _formatTanggal(selectedDate),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(height: 2, color: Colors.black87),
        const SizedBox(height: 20),

        // ── Attendance rows (white container) ────────────────────────────
        Container(
          color: Colors.white,
          child: Column(
            children: [
              // Jadwal
              _buildRow(
                icon: _calendarIcon(),
                mainText: _formatTanggal(selectedDate),
                subText: _getJamKerja(),
              ),
              _divider(),

              // Check-in
              _buildRow(
                icon: _arrowIcon(isIn: true),
                mainText: checkIn,
                subText: checkIn == '-'
                    ? '-'
                    : (terlambat ? 'Terlambat' : 'Tepat Waktu'),
                subColor: terlambat
                    ? Colors.black54
                    : (checkIn == '-' ? Colors.black54 : Colors.black54),
                subStyle: terlambat
                    ? const TextStyle(fontSize: 13, color: Colors.black54)
                    : const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              _divider(),

              // Check-out
              _buildRow(
                icon: _arrowIcon(isIn: false),
                mainText: checkOut,
                subText: '-',
              ),
              _divider(),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Row widget ────────────────────────────────────────────────────────────

  Widget _buildRow({
    required Widget icon,
    required String mainText,
    required String subText,
    Color subColor = Colors.black54,
    TextStyle? subStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mainText,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subText,
                style: subStyle ??
                    TextStyle(
                      fontSize: 13,
                      color: subColor,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Icon widgets ──────────────────────────────────────────────────────────

  /// Ikon kalender biru seperti di screenshot
  Widget _calendarIcon() {
    return SizedBox(
      width: 44,
      height: 44,
      child: Icon(
        Icons.calendar_month_outlined,
        color: const Color(0xFF4DA6FF),
        size: 40,
      ),
    );
  }

  /// Ikon panah dengan garis bawah — hijau (masuk) / merah (pulang)
  Widget _arrowIcon({required bool isIn}) {
    final color = isIn ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final arrowIcon = isIn ? Icons.arrow_downward : Icons.arrow_upward;

    return SizedBox(
      width: 44,
      height: 44,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(arrowIcon, color: color, size: 28),
          Container(
            height: 3,
            width: 32,
            color: color,
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, color: Color(0xFFE5E7EB));

  // ─── Error ─────────────────────────────────────────────────────────────────

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