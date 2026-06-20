import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/document_type_model.dart';
import '../services/absence_document_service.dart';

class DokumenKetidakhadiranFormPage extends StatefulWidget {
  const DokumenKetidakhadiranFormPage({super.key});

  @override
  State<DokumenKetidakhadiranFormPage> createState() =>
      _DokumenKetidakhadiranFormPageState();
}

class _DokumenKetidakhadiranFormPageState
    extends State<DokumenKetidakhadiranFormPage> {
  final AbsenceDocumentService _service = AbsenceDocumentService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _lokasiTujuanController = TextEditingController();
  final _namaKegiatanController = TextEditingController();

  List<DocumentTypeModel> _documentTypes = [];
  bool _isLoadingTypes = true;
  String _typeErrorMessage = '';
  DocumentTypeModel? _selectedType;

  bool _isSubmitting = false;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  PlatformFile? _selectedFile;

  @override
  void initState() {
    super.initState();
    _fetchDocumentTypes();
  }

  Future<void> _fetchDocumentTypes() async {
    setState(() {
      _isLoadingTypes = true;
      _typeErrorMessage = '';
    });

    try {
      final types = await _service.getDocumentTypes();
      if (!mounted) return;
      setState(() {
        _documentTypes = types;
        if (types.isNotEmpty) {
          _selectedType = types.first;
        }
        _isLoadingTypes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _typeErrorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoadingTypes = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _lokasiTujuanController.dispose();
    _namaKegiatanController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) => DateFormat('dd MMMM yyyy', 'id_ID').format(date);

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
      locale: const Locale('id', 'ID'),
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _selectedFile = result.files.first;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // VALIDASI DARI MASTER: Jika tipe dokumen ini mewajibkan lampiran
    if (_selectedType != null && _selectedType!.isRequired && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File lampiran WAJIB diunggah untuk pengajuan ${_selectedType!.name}.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    // Validasi 3 hari
    final today = DateTime.now();
    final diffDays = today.difference(_startDate).inDays;
    if (diffDays > 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Surat keterangan maksimal diunggah 3 hari setelah tanggal mulai.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return;
    }

    final isDinasLuar = _selectedType?.name.toLowerCase() == 'dinas luar';
    if (isDinasLuar) {
      if (_lokasiTujuanController.text.trim().isEmpty || _namaKegiatanController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tempat/Lokasi Tujuan dan Nama Kegiatan WAJIB diisi untuk Dinas Luar.'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _service.submitDocument(
        documentType: _selectedType?.name ?? '',
        title: _titleController.text.trim(),
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        file: _selectedFile,
        lokasiTujuan: isDinasLuar ? _lokasiTujuanController.text.trim() : null,
        namaKegiatan: isDinasLuar ? _namaKegiatanController.text.trim() : null,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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
          'Ajukan Dokumen',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoadingTypes 
        ? const Center(child: CircularProgressIndicator())
        : _typeErrorMessage.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_typeErrorMessage, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _fetchDocumentTypes, child: const Text('Coba Lagi'))
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Container(
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
                        'Form Pengajuan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<DocumentTypeModel>(
                        value: _selectedType,
                        dropdownColor: colorScheme.surfaceContainerHighest,
                        isExpanded: true,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Jenis dokumen',
                          labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        items: _documentTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: type.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(type.name),
                                    if (type.isRequired)
                                      const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _titleController,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Judul dokumen',
                          labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Judul dokumen wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickDate(isStart: true),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Tanggal mulai',
                                  labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(_formatDate(_startDate), style: TextStyle(color: colorScheme.onSurface)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickDate(isStart: false),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Tanggal selesai',
                                  labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(_formatDate(_endDate), style: TextStyle(color: colorScheme.onSurface)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedType?.name.toLowerCase() == 'dinas luar') ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _lokasiTujuanController,
                          style: TextStyle(color: colorScheme.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Tempat / Lokasi Tujuan',
                            labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Lokasi Tujuan wajib diisi untuk Dinas Luar';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _namaKegiatanController,
                          style: TextStyle(color: colorScheme.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Nama Kegiatan / Acara',
                            labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama Kegiatan wajib diisi untuk Dinas Luar';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 4,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Catatan tambahan',
                          labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: _pickFile,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: (_selectedType?.isRequired ?? false) && _selectedFile == null
                                ? Colors.orange.shade300
                                : colorScheme.outlineVariant
                            ),
                            color: colorScheme.surface,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.attach_file, color: colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedFile?.name ?? 
                                  ((_selectedType?.isRequired ?? false) 
                                    ? 'Wajib unggah file PDF / JPG / PNG'
                                    : 'Pilih file PDF / JPG / PNG (opsional)'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: (_selectedType?.isRequired ?? false) && _selectedFile == null
                                      ? Colors.orange.shade900
                                      : colorScheme.onSurface,
                                    fontWeight: (_selectedType?.isRequired ?? false) && _selectedFile == null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Kirim Dokumen',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
