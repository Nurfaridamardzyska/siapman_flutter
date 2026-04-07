import 'package:flutter/material.dart';
import '../models/absence_document_model.dart';
import '../services/absence_document_service.dart';

class DokumenKetidakhadiranPage extends StatefulWidget {
  const DokumenKetidakhadiranPage({super.key});

  @override
  State<DokumenKetidakhadiranPage> createState() =>
      _DokumenKetidakhadiranPageState();
}

class _DokumenKetidakhadiranPageState
    extends State<DokumenKetidakhadiranPage> {
  final AbsenceDocumentService _service = AbsenceDocumentService();

  bool isLoading = true;
  String errorMessage = '';
  List<AbsenceDocumentModel> documents = [];

  @override
  void initState() {
    super.initState();
    loadDocuments();
  }

  Future<void> loadDocuments() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final result = await _service.getDocuments();

      if (!mounted) return;
      setState(() {
        documents = result;
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

  String formatDateRange(String startDate, String endDate) {
    return '$startDate - $endDate';
  }

  String formatStatus(AbsenceDocumentModel item) {
    if (item.status.toLowerCase() == 'approved') {
      return item.approvedBy != null && item.approvedBy!.isNotEmpty
          ? 'Disetujui Oleh ${item.approvedBy}'
          : 'Disetujui';
    }

    if (item.status.toLowerCase() == 'pending') {
      return 'Menunggu Persetujuan';
    }

    if (item.status.toLowerCase() == 'rejected') {
      return 'Ditolak';
    }

    return item.status;
  }

  Color statusColor(AbsenceDocumentModel item) {
    switch (item.status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF3498F0);
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.black54;
    }
  }

  Widget buildDocumentItem(AbsenceDocumentModel item) {
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
          const SizedBox(width: 2),
          const Icon(
            Icons.insert_drive_file,
            color: Color(0xFF3498F0),
            size: 40,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.documentType,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black38,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDateRange(item.startDate, item.endDate),
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
              padding: const EdgeInsets.only(top: 26),
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
        onRefresh: loadDocuments,
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

    if (documents.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadDocuments,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 150),
            Center(
              child: Text(
                'Belum ada dokumen ketidakhadiran',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadDocuments,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        itemCount: documents.length,
        itemBuilder: (context, index) {
          return buildDocumentItem(documents[index]);
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
          'Dokumen Ketidakhadiran',
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