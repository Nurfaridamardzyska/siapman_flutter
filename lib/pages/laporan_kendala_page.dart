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
      return '${date.day.toString().padLeft(2, '0')} ${months[date.month]} ${date.year}';
    } catch (_) {
      return rawDate;
    }
  }

  String formatStatus(FaultReportModel item) {
    if (item.status.toLowerCase() == 'approved') {
      return 'Disetujui oleh ${item.handledBy ?? 'KOMINFO'}';
    }
    if (item.status.toLowerCase() == 'rejected') {
      return 'Ditolak oleh ${item.handledBy ?? 'KOMINFO'}';
    }
    if (item.status.toLowerCase() == 'pending') {
      return 'Diproses oleh ${item.handledBy ?? 'KOMINFO'}';
    }
    return item.status;
  }

  Color statusColor(FaultReportModel item) {
    switch (item.status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return const Color(0xFF3498F0);
      case 'pending':
        return Colors.orange;
      default:
        return Colors.black54;
    }
  }

  Widget buildItem(FaultReportModel item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFBDBDBD),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.access_time_outlined,
            color: Color(0xFFF28C28),
            size: 40,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDate(item.reportDate),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                formatStatus(item),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: statusColor(item),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: loadReports,
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

    if (reports.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadReports,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 150),
            Center(
              child: Text(
                'Belum ada laporan kendala',
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadReports,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          return buildItem(reports[index]);
        },
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
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Laporan kendala',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        children: [
          buildBody(),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fitur hubungi admin OPD belum dihubungkan'),
                    ),
                  );
                },
                icon: const Icon(Icons.phone_outlined, color: Colors.white),
                label: const Text(
                  'Hubungi admin OPD',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498F0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}