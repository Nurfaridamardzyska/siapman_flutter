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
  Map<String, dynamic>? attendance;

  @override
  void initState() {
    super.initState();
    fetchTodayAttendance();
  }

  Future<void> fetchTodayAttendance() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final result = await _apiService.getTodayAttendance();

      if (!mounted) return;
      setState(() {
        attendance = result['data'];
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

  String getStatusText() {
    if (attendance == null) return 'Belum Absen';
    if (attendance!['check_in_at'] != null && attendance!['check_out_at'] == null) {
      return 'Sudah Check-in';
    }
    if (attendance!['check_in_at'] != null && attendance!['check_out_at'] != null) {
      return 'Absensi Selesai';
    }
    return 'Belum Absen';
  }

  Color getStatusColor() {
    if (attendance == null) return Colors.orange;
    if (attendance!['check_in_at'] != null && attendance!['check_out_at'] == null) {
      return Colors.blue;
    }
    if (attendance!['check_in_at'] != null && attendance!['check_out_at'] != null) {
      return Colors.green;
    }
    return Colors.orange;
  }

  IconData getStatusIcon() {
    if (attendance == null) return Icons.hourglass_empty_rounded;
    if (attendance!['check_in_at'] != null && attendance!['check_out_at'] == null) {
      return Icons.login_rounded;
    }
    if (attendance!['check_in_at'] != null && attendance!['check_out_at'] != null) {
      return Icons.verified_rounded;
    }
    return Icons.hourglass_empty_rounded;
  }

  Widget infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
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
        onRefresh: fetchTodayAttendance,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage.isNotEmpty
                ? ListView(
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
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: getStatusColor().withOpacity(0.12),
                              child: Icon(
                                getStatusIcon(),
                                size: 34,
                                color: getStatusColor(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              getStatusText(),
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                color: getStatusColor(),
                              ),
                            ),
                            const SizedBox(height: 22),
                            infoRow('Tanggal', attendance?['attendance_date'] ?? '-'),
                            infoRow('Check-in', attendance?['check_in_at'] ?? '-'),
                            infoRow('Check-out', attendance?['check_out_at'] ?? '-'),
                            infoRow(
                              'Status',
                              attendance?['status']?['name']?.toString() ?? '-',
                            ),
                            infoRow('Catatan', attendance?['note']?.toString() ?? '-'),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}