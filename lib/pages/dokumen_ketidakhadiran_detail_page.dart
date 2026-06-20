import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/absence_document_model.dart';
import '../services/absence_document_service.dart';

class DokumenKetidakhadiranDetailPage extends StatefulWidget {
  final int documentId;

  const DokumenKetidakhadiranDetailPage({super.key, required this.documentId});

  @override
  State<DokumenKetidakhadiranDetailPage> createState() =>
      _DokumenKetidakhadiranDetailPageState();
}

class _DokumenKetidakhadiranDetailPageState
    extends State<DokumenKetidakhadiranDetailPage> {
  final AbsenceDocumentService _service = AbsenceDocumentService();
  AbsenceDocumentModel? _document;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await _service.getDocumentDetail(widget.documentId);
      if (!mounted) return;
      setState(() {
        _document = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _openFile() async {
    final url = _document?.fileUrl;
    if (url == null || url.isEmpty) return;

    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka file dokumen')),
      );
    }
  }

  Widget _buildInfoRow(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Detail Dokumen',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDetail,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _document?.title ?? '-',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _document?.documentType ?? '-',
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildInfoRow('Periode', '${_document?.startDate ?? '-'} - ${_document?.endDate ?? '-'}'),
                            _buildInfoRow('Status', _document?.status ?? '-'),
                            _buildInfoRow('Persetujuan', _document?.approvedBy ?? '-'),
                            _buildInfoRow('Penolakan', _document?.rejectedBy ?? '-'),
                            _buildInfoRow('Diputuskan', _document?.decidedAt ?? '-'),
                            _buildInfoRow('Catatan Keputusan', _document?.decisionNotes?.isNotEmpty == true ? _document!.decisionNotes! : '-'),
                            _buildInfoRow('Catatan', _document?.notes?.isNotEmpty == true ? _document!.notes! : '-'),
                            const SizedBox(height: 12),
                            if (_document?.fileUrl != null)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _openFile,
                                  icon: const Icon(Icons.open_in_new, color: Colors.white),
                                  label: const Text(
                                    'Buka File Lampiran',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
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
}
