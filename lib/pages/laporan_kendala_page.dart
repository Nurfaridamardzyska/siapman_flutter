import 'package:flutter/material.dart';
import '../models/fault_report_model.dart';
import '../services/fault_report_service.dart';

class LaporanKendalaPage extends StatefulWidget {
  const LaporanKendalaPage({super.key});

  @override
  State<LaporanKendalaPage> createState() => _LaporanKendalaPageState();
}

class _LaporanKendalaPageState extends State<LaporanKendalaPage> {
  final FaultReportService _service = FaultReportService();

  bool isLoading = true;
  String errorMessage = '';
  List<FaultReportModel> reports = [];

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  Future<void> loadReports() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final result = await _service.getReports();
      if (!mounted) return;
      setState(() {
        reports = result;
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

  String formatDate(String rawDate) {
    if (rawDate.isEmpty) return '-';
    try {
      final date = DateTime.parse(rawDate);
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      return '${date.day.toString().padLeft(2, '0')} ${months[date.month]} ${date.year}';
    } catch (_) {
      return rawDate;
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
          'Laporan Kendala',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
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
              onRefresh: loadReports,
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: isDark ? Colors.cyanAccent : const Color(0xFF2563EB)))
                  : errorMessage.isNotEmpty
                      ? _buildError(isDark)
                      : _buildBody(isDark),
            ),
            _buildBottomButton(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (reports.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 150),
            child: Column(
              children: [
                Icon(Icons.campaign_outlined, size: 80, color: isDark ? Colors.white12 : Colors.black12),
                const SizedBox(height: 24),
                Text(
                  'Belum ada laporan kendala.',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38, 
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        return _buildReportItem(reports[index], isDark);
      },
    );
  }

  Widget _buildReportItem(FaultReportModel item, bool isDark) {
    Color statusColor;
    String statusText;
    
    switch (item.status.toLowerCase()) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        statusText = 'SELESAI';
        break;
      case 'pending':
        statusColor = const Color(0xFF3B82F6);
        statusText = 'PROSES';
        break;
      case 'rejected':
        statusColor = const Color(0xFFF43F5E);
        statusText = 'DITOLAK';
        break;
      default:
        statusColor = Colors.grey;
        statusText = item.status.toUpperCase();
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
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: (item.type == 'admin_report' ? const Color(0xFF2563EB) : const Color(0xFFF59E0B)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                item.type == 'admin_report' ? Icons.campaign_rounded : Icons.report_problem_rounded,
                color: item.type == 'admin_report' ? const Color(0xFF2563EB) : const Color(0xFFF59E0B),
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatDate(item.reportDate),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white38 : Colors.black38,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kendala pada sistem atau alat presensi.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton(bool isDark) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: 32,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFF075985), const Color(0xFF1E3A8A), const Color(0xFF172554)], // sky-800 -> blue-900 -> blue-950
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.5) : const Color(0xFF2563EB).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Menghubungkan ke Admin OPD...')),
            );
          },
          icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 20),
          label: const Text(
            'HUBUNGI ADMIN OPD',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
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
        Text(
          errorMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15, 
            color: isDark ? Colors.white70 : Colors.black54, 
            fontWeight: FontWeight.w500
          ),
        ),
      ],
    );
  }
}