import 'dart:async';
import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ProsentasePage extends StatefulWidget {
  const ProsentasePage({super.key});

  @override
  State<ProsentasePage> createState() => _ProsentasePageState();
}

class _ProsentasePageState extends State<ProsentasePage> {
  final ApiService _apiService = ApiService();

  Timer? _timer;
  bool _loading = true;
  String _error = '';

  List<dynamic> _allLogs = [];
  int _selectedRange = 30; // 7, 30, 0 = semua

  double hadirPercent = 0;
  double terlambatPercent = 0;
  double tidakHadirPercent = 0;
  double penguranganPercent = 0;
  int totalPotongan = 0;

  int totalHari = 0;
  int totalHadir = 0;
  int totalTerlambat = 0;
  int totalTidakHadir = 0;

  @override
  void initState() {
    super.initState();
    _loadData();

    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadData(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }

    try {
      final result = await _apiService.getAttendanceHistory();
      final logs = (result['data'] as List?) ?? [];

      _allLogs = logs;
      _calculateStats();

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _calculateStats() {
    final now = DateTime.now();

    final filteredLogs = _allLogs.where((log) {
      final rawDate = log['attendance_date'];
      if (rawDate == null) return false;

      DateTime? logDate;
      try {
        logDate = DateTime.parse(rawDate.toString());
      } catch (_) {
        return false;
      }

      if (_selectedRange == 0) return true;

      final diff = now.difference(logDate).inDays;
      return diff < _selectedRange;
    }).toList();

    totalHari = filteredLogs.length;
    totalHadir = 0;
    totalTerlambat = 0;
    totalTidakHadir = 0;

    for (final log in filteredLogs) {
      final rawStatus = log['status'];
      Map<String, dynamic> status = {};

      if (rawStatus is Map<String, dynamic>) {
        status = rawStatus;
      }

      final statusCode = (status['code'] ?? '').toString().toUpperCase();
      final checkIn = log['check_in_at'];

      if (checkIn != null && checkIn.toString().isNotEmpty) {
        totalHadir++;
      }

      if (statusCode == 'LATE' || statusCode == 'TERLAMBAT') {
        totalTerlambat++;
      }

      if (statusCode == 'ABSENT' ||
          statusCode == 'ALPHA' ||
          statusCode == 'TIDAK_HADIR') {
        totalTidakHadir++;
      }
    }

    if (totalHari == 0) {
      hadirPercent = 0;
      terlambatPercent = 0;
      tidakHadirPercent = 0;
      penguranganPercent = 0;
      totalPotongan = 0;
      return;
    }

    hadirPercent = (totalHadir / totalHari) * 100;
    terlambatPercent = (totalTerlambat / totalHari) * 100;
    tidakHadirPercent = (totalTidakHadir / totalHari) * 100;

    penguranganPercent = (totalTerlambat * 0.5) + (totalTidakHadir * 2.0);
    totalPotongan = ((penguranganPercent / 100) * 5000000).round();
  }

  String _formatRupiah(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    int count = 0;

    for (int i = text.length - 1; i >= 0; i--) {
      buffer.write(text[i]);
      count++;
      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }

    return buffer.toString().split('').reversed.join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE5E5E5),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Laporan Prosentase',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            onPressed: () => _loadData(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    children: [
                      _buildRangeSelector(),
                      const SizedBox(height: 20),
                      _buildPotonganCard(),
                      const SizedBox(height: 24),
                      _buildStatistikCard(),
                      const SizedBox(height: 24),
                      _buildSummaryCard(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildRangeSelector() {
    return Row(
      children: [
        _rangeChip('7 Hari', 7),
        const SizedBox(width: 8),
        _rangeChip('30 Hari', 30),
        const SizedBox(width: 8),
        _rangeChip('Semua', 0),
      ],
    );
  }

  Widget _rangeChip(String label, int value) {
    final selected = _selectedRange == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRange = value;
          _calculateStats();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPotonganCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: penguranganPercent.clamp(0, 100)),
            duration: const Duration(milliseconds: 700),
            builder: (context, value, _) {
              return SizedBox(
                width: 170,
                height: 170,
                child: CustomPaint(
                  painter: PieChartPainter(
                    percentage: value / 100,
                    color: const Color(0xFFE5921B),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Pengurangan : ${penguranganPercent.toStringAsFixed(1)}%\n'
            'Total Potongan : Rp.${_formatRupiah(totalPotongan)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: Color(0xFF444444),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tap refresh atau pull down untuk update data secara realtime',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistikCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (_) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Detail Statistik',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Terlambat: ${terlambatPercent.toStringAsFixed(1)}%'),
                  const SizedBox(height: 8),
                  Text('Tidak Hadir: ${tidakHadirPercent.toStringAsFixed(1)}%'),
                  const SizedBox(height: 8),
                  Text('Hadir: ${hadirPercent.toStringAsFixed(1)}%'),
                ],
              ),
            );
          },
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 170,
              height: 170,
              child: CustomPaint(
                painter: BarChartPainter(
                  terlambat: terlambatPercent,
                  alpha: tidakHadirPercent,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Terlambat : ${terlambatPercent.toStringAsFixed(1)}%\n'
              'Tidak Hadir : ${tidakHadirPercent.toStringAsFixed(1)}%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: Color(0xFF444444),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ringkasan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _summaryRow('Total Hari', totalHari.toString()),
          _summaryRow('Total Hadir', totalHadir.toString()),
          _summaryRow('Total Terlambat', totalTerlambat.toString()),
          _summaryRow('Total Tidak Hadir', totalTidakHadir.toString()),
          _summaryRow('Persentase Hadir', '${hadirPercent.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _summaryRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class PieChartPainter extends CustomPainter {
  final double percentage;
  final Color color;

  PieChartPainter({
    required this.percentage,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = Colors.black12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final basePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2.4,
    );

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2 + 3),
      size.width / 2.4,
      shadowPaint,
    );

    canvas.drawArc(rect, 0, 6.28318, true, basePaint);
    canvas.drawArc(rect, -1.5708, 6.28318 * percentage, true, fillPaint);
    canvas.drawArc(rect, 0, 6.28318, true, borderPaint);
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) {
    return oldDelegate.percentage != percentage;
  }
}

class BarChartPainter extends CustomPainter {
  final double terlambat;
  final double alpha;

  BarChartPainter({
    required this.terlambat,
    required this.alpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = Colors.black12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final barPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final axisPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(26, 24),
      Offset(26, size.height - 30),
      axisPaint,
    );
    canvas.drawLine(
      Offset(26, size.height - 30),
      Offset(size.width - 18, size.height - 30),
      axisPaint,
    );

    final double bar1Height = (terlambat * 2).clamp(25, 90).toDouble();
    final double bar2Height = (alpha * 2).clamp(30, 110).toDouble();
    final double bar3Height = ((terlambat + alpha) * 1.5).clamp(40, 125).toDouble();

    const radius = Radius.circular(12);

    final bar1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(48, 150 - bar1Height, 28, bar1Height),
      radius,
    );
    final bar2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(88, 150 - bar2Height, 28, bar2Height),
      radius,
    );
    final bar3 = RRect.fromRectAndRadius(
      Rect.fromLTWH(128, 150 - bar3Height, 28, bar3Height),
      radius,
    );

    canvas.drawRRect(bar1, shadowPaint);
    canvas.drawRRect(bar2, shadowPaint);
    canvas.drawRRect(bar3, shadowPaint);

    canvas.drawRRect(bar1, barPaint);
    canvas.drawRRect(bar2, barPaint);
    canvas.drawRRect(bar3, barPaint);
  }

  @override
  bool shouldRepaint(covariant BarChartPainter oldDelegate) {
    return oldDelegate.terlambat != terlambat || oldDelegate.alpha != alpha;
  }
}