import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

class _RiwayatKehadiranPageState extends State<RiwayatKehadiranPage>
    with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();

  Timer? _realtimeTimer;
  bool _isRefreshing = false;

  bool isLoading = true;
  String errorMessage = '';
  List<Map<String, dynamic>> _historyItems = [];

  static const List<String> _hariList = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  static const List<String> _bulanList = [
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadAttendanceHistory();
    _startRealtimePolling();

    if (widget.fromAbsensi &&
        widget.lastAbsensiMessage != null &&
        widget.lastAbsensiMessage!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lastAbsensiMessage!)),
        );
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtimeTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadAttendanceHistory(showLoading: false);
    }
  }

  void _startRealtimePolling() {
    _realtimeTimer?.cancel();
    _realtimeTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      loadAttendanceHistory(showLoading: false);
    });
  }

  Future<void> loadAttendanceHistory({bool showLoading = true}) async {
    if (_isRefreshing) return;

    _isRefreshing = true;

    if (showLoading && mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    try {
      Map<String, dynamic>? attendanceResult;
      List<dynamic> absenceDocs = [];
      
      try {
        attendanceResult = await _apiService.getAttendanceHistory();
      } catch (e) {
        rethrow;
      }
      
      try {
        absenceDocs = await _apiService.getAbsenceDocuments();
      } catch (e) {
        debugPrint('Gagal mengambil data cuti: $e');
      }

      final latest = (attendanceResult['data'] as List?) ?? [];

      List<Map<String, dynamic>> flatList = [];
      Set<String> cutiDates = {};
      
      DateTime? parseTimestamp(String dateStr, String timeStr) {
        try {
          if (timeStr == '-' || timeStr.isEmpty) return DateTime.parse(dateStr);
          final dt = DateTime.parse(dateStr);
          final parts = timeStr.split(':');
          if (parts.isNotEmpty) {
            return DateTime(dt.year, dt.month, dt.day, int.parse(parts[0]), parts.length > 1 ? int.parse(parts[1]) : 0, parts.length > 2 ? int.parse(parts[2]) : 0);
          }
          return dt;
        } catch (_) {
          return null;
        }
      }

      // 1. Ekstrak semua tanggal cuti terlebih dahulu
      for (var doc in absenceDocs) {
        if (doc is! Map<String, dynamic>) continue;
        final status = (doc['status'] as String?)?.toLowerCase();
        if (status != 'approved') continue;

        final startDateStr = doc['start_date'] as String?;
        final endDateStr = doc['end_date'] as String?;
        final docType = doc['document_type'] as String? ?? 'Cuti';
        
        if (startDateStr == null || endDateStr == null) continue;
        
        final startDt = DateTime.tryParse(startDateStr);
        final endDt = DateTime.tryParse(endDateStr);
        if (startDt == null || endDt == null) continue;
        
        final days = endDt.difference(startDt).inDays;
        for (var i = 0; i <= days; i++) {
          final currentDt = startDt.add(Duration(days: i));
          final currentDtStr = '${currentDt.year}-${currentDt.month.toString().padLeft(2, '0')}-${currentDt.day.toString().padLeft(2, '0')}';
          
          cutiDates.add(currentDtStr);
          
          flatList.add({
            'date_str': currentDtStr,
            'time_str': '-',
            'type': 'CUTI',
            'doc_type': docType,
            'timestamp': currentDt, // For sorting
          });
        }
      }

      // 2. Tambahkan presensi, TAPI lewati jika tanggal tersebut adalah hari cuti
      for (var log in latest) {
        final dateStr = log['attendance_date'];
        if (dateStr == null) continue;
        
        // Jika hari tersebut orangnya sedang cuti, override/abaikan presensi masuk/pulang
        if (cutiDates.contains(dateStr)) continue;
        
        if (log['check_out_at'] != null) {
          flatList.add({
            'date_str': dateStr,
            'time_str': log['check_out_at'],
            'type': 'PULANG',
            'timestamp': parseTimestamp(dateStr, log['check_out_at']),
          });
        }
        if (log['check_in_at'] != null) {
          flatList.add({
            'date_str': dateStr,
            'time_str': log['check_in_at'],
            'type': 'MASUK',
            'timestamp': parseTimestamp(dateStr, log['check_in_at']),
          });
        }
      }

      // Sort descending by timestamp
      flatList.sort((a, b) {
        final ta = a['timestamp'] as DateTime?;
        final tb = b['timestamp'] as DateTime?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      if (!mounted) return;

      setState(() {
        _historyItems = flatList;
        errorMessage = '';
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (showLoading) {
        setState(() {
          errorMessage = e.toString().replaceFirst('Exception: ', '');
          isLoading = false;
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

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
          'Riwayat Absensi',
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
            RefreshIndicator(
              color: isDark ? Colors.cyanAccent : const Color(0xFF2563EB),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              onRefresh: () => loadAttendanceHistory(showLoading: false),
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: isDark ? Colors.cyanAccent : const Color(0xFF2563EB)))
                  : errorMessage.isNotEmpty
                      ? _buildError(isDark)
                      : _buildBody(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_historyItems.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 150),
            child: Column(
              children: [
                Icon(Icons.history_rounded, size: 80, color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
                const SizedBox(height: 24),
                Text(
                  'Belum ada riwayat aktivitas.',
                  style: TextStyle(
                    color: isDark ? Colors.white.withOpacity(0.4) : Colors.black38, 
                    fontSize: 16, 
                    fontWeight: FontWeight.w500
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      itemCount: _historyItems.length,
      itemBuilder: (context, index) {
        final item = _historyItems[index];
        final dateStr = item['date_str'] as String;
        final timeStr = item['time_str'] as String;

        final dt = DateTime.tryParse(dateStr);
        String hari = '-';
        String tgl = dateStr;
        if (dt != null) {
          hari = _hariList[dt.weekday - 1];
          tgl = '${dt.day.toString().padLeft(2, '0')} ${_bulanList[dt.month]} ${dt.year}';
        }

        final displayTime = timeStr.length >= 5 && timeStr != '-' ? timeStr.substring(0, 5) : timeStr;
        final isMasuk = item['type'] == 'MASUK';
        final isCuti = item['type'] == 'CUTI';
        
        Color statusColor;
        IconData statusIcon;
        if (isCuti) {
          statusColor = const Color(0xFF8B5CF6);
          statusIcon = Icons.description_rounded;
        } else if (isMasuk) {
          statusColor = const Color(0xFF10B981);
          statusIcon = Icons.login_rounded;
        } else {
          statusColor = const Color(0xFFF59E0B);
          statusIcon = Icons.logout_rounded;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.1 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            hari.toUpperCase(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isCuti ? 'IZIN' : (isMasuk ? 'MASUK' : 'PULANG'),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: statusColor,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tgl,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white.withOpacity(0.4) : Colors.black45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (displayTime != '-')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.cyanAccent : const Color(0xFF2563EB)).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    displayTime,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.cyanAccent : const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
        Text(
          errorMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15, 
            color: isDark ? Colors.white.withOpacity(0.6) : Colors.black54, 
            fontWeight: FontWeight.w500
          ),
        ),
      ],
    );
  }
}
