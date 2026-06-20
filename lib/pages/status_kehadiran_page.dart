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
  List<dynamic> allSchedules = [];
  List<dynamic> allAbsence = [];

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
      final responses = await Future.wait([
        _apiService.getAttendanceHistory(),
        _apiService.getAttendanceSchedules(),
        _apiService.getAbsenceDocuments().catchError((_) => []),
      ]);

      final historyResult = responses[0] as Map<String, dynamic>;
      final scheduleResult = responses[1] as Map<String, dynamic>;
      final absenceResult = responses[2];

      if (!mounted) return;
      setState(() {
        allAttendance = historyResult['data'] ?? [];
        allSchedules = scheduleResult['schedules'] ?? [];
        allAbsence = absenceResult is List ? absenceResult : [];
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

  Map<String, dynamic>? _getAbsenceForDate(DateTime date) {
    for (var doc in allAbsence) {
      if (doc is! Map<String, dynamic>) continue;
      final status = (doc['status'] as String?)?.toLowerCase();
      if (status != 'approved') continue;

      final startDateStr = doc['start_date'] as String?;
      final endDateStr = doc['end_date'] as String?;
      if (startDateStr == null || endDateStr == null) continue;

      final startDt = DateTime.tryParse(startDateStr);
      final endDt = DateTime.tryParse(endDateStr);
      if (startDt == null || endDt == null) continue;

      final dateOnly = DateTime(date.year, date.month, date.day);
      final startOnly = DateTime(startDt.year, startDt.month, startDt.day);
      final endOnly = DateTime(endDt.year, endDt.month, endDt.day);

      if (dateOnly.isAfter(startOnly.subtract(const Duration(days: 1))) &&
          dateOnly.isBefore(endOnly.add(const Duration(days: 1)))) {
        return doc;
      }
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
    final schedule = _findScheduleForDate(selectedDate);
    if (schedule == null) {
      if (selectedDate.weekday == DateTime.monday) return '08:15:00 - 15:30:00';
      if (selectedDate.weekday == DateTime.friday) return '07:30:00 - 15:00:00';
      return '07:30:00 - 15:30:00';
    }

    final start = schedule['start_time']?.toString() ?? '-';
    final end = schedule['end_time']?.toString() ?? '-';
    return '$start - $end';
  }

  bool _isTerlambat(String checkInTime) {
    if (checkInTime == '-') return false;
    final parts = checkInTime.split(':');
    if (parts.length < 2) return false;
    final mins =
        (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);

    final schedule = _findScheduleForDate(selectedDate);
    final limit = _scheduleCheckInLimit(schedule, selectedDate.weekday);
    return mins > limit;
  }

  bool _isPulangCepat(String checkOutTime) {
    if (checkOutTime == '-') return false;
    final parts = checkOutTime.split(':');
    if (parts.length < 2) return false;
    final mins =
        (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);

    final schedule = _findScheduleForDate(selectedDate);
    if (schedule == null) return false;

    final endMinutes = _timeToMinutes(schedule['end_time']?.toString());
    return mins < endMinutes;
  }

  Map<String, dynamic>? _findScheduleForDate(DateTime date) {
    final weekday = date.weekday;
    final candidates = allSchedules
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) {
          final day = int.tryParse(item['day_of_week']?.toString() ?? '');
          final active = _asBool(item['is_active']);
          return day == weekday && active;
        })
        .toList();

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      final categoryA = a['category'];
      final categoryB = b['category'];

      final priorityA = categoryA is Map
          ? int.tryParse(categoryA['priority']?.toString() ?? '') ?? 9999
          : 9999;
      final priorityB = categoryB is Map
          ? int.tryParse(categoryB['priority']?.toString() ?? '') ?? 9999
          : 9999;

      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }

      final startA = _timeToMinutes(a['start_time']?.toString());
      final startB = _timeToMinutes(b['start_time']?.toString());
      return startA.compareTo(startB);
    });

    return candidates.first;
  }

  int _scheduleCheckInLimit(Map<String, dynamic>? schedule, int weekday) {
    if (schedule != null) {
      final startMinutes = _timeToMinutes(schedule['start_time']?.toString());
      final tolerance =
          int.tryParse(schedule['tolerance_minutes']?.toString() ?? '') ?? 0;
      return startMinutes + tolerance;
    }

    return weekday == DateTime.monday ? (8 * 60 + 15) : (7 * 60 + 30);
  }

  int _timeToMinutes(String? value) {
    if (value == null || value.isEmpty) return 0;
    final parts = value.split(':');
    if (parts.length < 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final parsed = value?.toString().toLowerCase();
    return parsed == '1' || parsed == 'true';
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Status Kehadiran',
          style: TextStyle(
            color: colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;
    final record = _selectedRecord;
    final absence = _getAbsenceForDate(selectedDate);
    final checkIn = _extractTime(record?['check_in_at']);
    final checkOut = _extractTime(record?['check_out_at']);
    final terlambat = _isTerlambat(checkIn);

    final isWeekend = selectedDate.weekday == DateTime.saturday || selectedDate.weekday == DateTime.sunday;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    
    String mainStatus = '';
    Color statusColor = colorScheme.primary;
    IconData statusIcon = Icons.info_outline;
    
    bool isAlpha = false;
    bool isBelumAbsen = false;
    
    if (absence != null) {
      mainStatus = absence['document_type']?.toString().toUpperCase() ?? 'CUTI';
      statusColor = const Color(0xFF8B5CF6); // Purple
      statusIcon = Icons.description_rounded;
    } else if (record != null) {
      mainStatus = 'HADIR';
      statusColor = const Color(0xFF10B981); // Emerald
      statusIcon = Icons.how_to_reg_rounded;
    } else {
      if (isWeekend) {
        mainStatus = 'LIBUR';
        statusColor = Colors.grey;
        statusIcon = Icons.weekend_rounded;
      } else if (dateOnly.isAfter(today)) {
        mainStatus = 'BELUM WAKTUNYA';
        statusColor = Colors.grey;
        statusIcon = Icons.schedule_rounded;
      } else if (dateOnly.isAtSameMomentAs(today)) {
        mainStatus = 'BELUM ABSEN';
        statusColor = const Color(0xFFF59E0B); // Amber
        statusIcon = Icons.access_time_filled_rounded;
        isBelumAbsen = true;
      } else {
        mainStatus = 'ALPHA';
        statusColor = const Color(0xFFEF4444); // Red
        statusIcon = Icons.cancel_rounded;
        isAlpha = true;
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        // ── Date picker ──────────────────────────────────────────────────
        Text(
          'Pilih Tanggal',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _pickDate,
          child: Text(
            _formatTanggal(selectedDate),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(height: 2, color: colorScheme.onSurface),
        const SizedBox(height: 20),

        // ── Status Badge ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Hari Ini',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor.withOpacity(0.8),
                      ),
                    ),
                    Text(
                      mainStatus,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Attendance rows (white container) ────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              // Jadwal
              _buildRow(
                icon: _calendarIcon(),
                mainText: _formatTanggal(selectedDate),
                subText: isWeekend ? 'Libur Akhir Pekan' : _getJamKerja(),
              ),

              if (absence != null) ...[
                _divider(),
                _buildRow(
                  icon: _customIcon(Icons.edit_document, const Color(0xFF8B5CF6)),
                  mainText: absence['title']?.toString() ?? 'Dokumen Terkirim',
                  subText: absence['notes']?.toString().isNotEmpty == true 
                      ? absence['notes'] 
                      : 'Disetujui',
                  subStyle: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else if (record != null) ...[
                _divider(),
                // Check-in
                _buildRow(
                  icon: _arrowIcon(isIn: true),
                  mainText: checkIn,
                  subText: checkIn == '-'
                      ? '-'
                      : (terlambat ? 'Terlambat' : 'Tepat Waktu'),
                  subStyle: TextStyle(
                    fontSize: 13, 
                    color: terlambat ? colorScheme.error : colorScheme.onSurfaceVariant,
                    fontWeight: terlambat ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                _divider(),
                // Check-out
                _buildRow(
                  icon: _arrowIcon(isIn: false),
                  mainText: checkOut,
                  subText: checkOut == '-'
                      ? '-'
                      : (_isPulangCepat(checkOut)
                          ? 'Pulang Mendahului'
                          : 'Tepat Waktu'),
                  subStyle: TextStyle(
                    fontSize: 13,
                    color: _isPulangCepat(checkOut) ? const Color(0xFFF59E0B) : colorScheme.onSurfaceVariant,
                    fontWeight: _isPulangCepat(checkOut) ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ] else if (isAlpha) ...[
                _divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Center(
                    child: Text(
                      'Tidak ada rekam jejak presensi maupun dokumen cuti/izin untuk hari ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ] else if (isBelumAbsen && !isWeekend) ...[
                _divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Center(
                    child: Text(
                      'Silakan lakukan absensi MASUK melalui halaman Lapor Kehadiran.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
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
    TextStyle? subStyle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subText,
                style: subStyle ??
                    TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 44,
      height: 44,
      child: Icon(
        Icons.calendar_month_outlined,
        color: colorScheme.primary,
        size: 40,
      ),
    );
  }

  /// Ikon panah dengan garis bawah — hijau (masuk) / merah (pulang)
  Widget _arrowIcon({required bool isIn}) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isIn ? const Color(0xFF22C55E) : colorScheme.error;
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

  Widget _customIcon(IconData iconData, Color color) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Icon(
          iconData,
          color: color,
          size: 32,
        ),
      ),
    );
  }

  Widget _divider() {
    final colorScheme = Theme.of(context).colorScheme;
    return Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.5));
  }

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