import 'package:flutter/material.dart';
import '../models/absence_document_model.dart';
import '../services/absence_document_service.dart';
import 'dokumen_ketidakhadiran_detail_page.dart';
import 'dokumen_ketidakhadiran_form_page.dart';

class DokumenKetidakhadiranPage extends StatefulWidget {
  const DokumenKetidakhadiranPage({super.key});

  @override
  State<DokumenKetidakhadiranPage> createState() => _DokumenKetidakhadiranPageState();
}

class _DokumenKetidakhadiranPageState extends State<DokumenKetidakhadiranPage> {
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
          'Dokumen Ketidakhadiran',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const DokumenKetidakhadiranFormPage()),
              );
              if (created == true) {
                await loadDocuments();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dokumen berhasil dikirim')),
                );
              }
            },
            icon: Icon(Icons.add_circle_outline_rounded, color: isDark ? Colors.cyanAccent : const Color(0xFF2563EB)),
          ),
          const SizedBox(width: 8),
        ],
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
              onRefresh: loadDocuments,
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
    if (documents.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 150),
            child: Column(
              children: [
                Icon(Icons.folder_open_rounded, size: 80, color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
                const SizedBox(height: 24),
                Text(
                  'Belum ada riwayat pengajuan.',
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
      itemCount: documents.length,
      itemBuilder: (context, index) {
        return buildDocumentItem(documents[index], isDark);
      },
    );
  }

  Widget buildDocumentItem(AbsenceDocumentModel item, bool isDark) {
    Color statusColor;
    if (item.status.toLowerCase() == 'approved') {
      statusColor = const Color(0xFF10B981);
    } else if (item.status.toLowerCase() == 'pending') {
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusColor = const Color(0xFFF43F5E);
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
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DokumenKetidakhadiranDetailPage(documentId: item.id)),
        ),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: (item.color ?? const Color(0xFF3B82F6)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.description_outlined, color: item.color ?? const Color(0xFF3B82F6), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.documentType.toUpperCase(),
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
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.status.toUpperCase(),
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
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white.withOpacity(0.7) : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      formatDateRange(item.startDate, item.endDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white.withOpacity(0.4) : Colors.black45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white12 : Colors.black12),
            ],
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
            color: isDark ? Colors.white.withOpacity(0.6) : Colors.black54, 
            fontWeight: FontWeight.w500
          ),
        ),
      ],
    );
  }
}