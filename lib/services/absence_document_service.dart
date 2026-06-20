import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/absence_document_model.dart';
import '../models/document_type_model.dart';
import 'api_service.dart';

class AbsenceDocumentService {
  static String get baseUrl => ApiService.baseUrl;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<List<AbsenceDocumentModel>> getDocuments() async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Token login tidak ditemukan');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/absence-documents'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final list = data['data'] as List? ?? [];
      return list.map((item) => AbsenceDocumentModel.fromJson(item)).toList();
    }

    throw Exception(
      data['message'] ?? 'Gagal mengambil dokumen ketidakhadiran',
    );
  }

  Future<List<DocumentTypeModel>> getDocumentTypes() async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Token login tidak ditemukan');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/document-types'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final list = data['data'] as List? ?? [];
      return list.map((item) => DocumentTypeModel.fromJson(item)).toList();
    }

    throw Exception(data['message'] ?? 'Gagal mengambil tipe dokumen');
  }

  Future<AbsenceDocumentModel> getDocumentDetail(int id) async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Token login tidak ditemukan');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/absence-documents/$id'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return AbsenceDocumentModel.fromJson(
        data['data'] as Map<String, dynamic>,
      );
    }

    throw Exception(
      data['message'] ?? 'Gagal mengambil detail dokumen ketidakhadiran',
    );
  }

  Future<AbsenceDocumentModel> submitDocument({
    required String documentType,
    required String title,
    required String startDate,
    required String endDate,
    String? notes,
    PlatformFile? file,
    String? lokasiTujuan,
    String? namaKegiatan,
  }) async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Token login tidak ditemukan');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/absence-documents'),
    );

    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['document_type'] = documentType;
    request.fields['title'] = title;
    request.fields['start_date'] = startDate;
    request.fields['end_date'] = endDate;

    if (notes != null && notes.trim().isNotEmpty) {
      request.fields['notes'] = notes.trim();
    }
    
    if (lokasiTujuan != null && lokasiTujuan.trim().isNotEmpty) {
      request.fields['lokasi_tujuan'] = lokasiTujuan.trim();
    }
    
    if (namaKegiatan != null && namaKegiatan.trim().isNotEmpty) {
      request.fields['nama_kegiatan'] = namaKegiatan.trim();
    }

    if (file != null) {
      if (file.path != null && file.path!.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('file', file.path!),
        );
      } else if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            file.bytes!,
            filename: file.name,
          ),
        );
      }
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final dynamic decoded = jsonDecode(response.body);

    final Map<String, dynamic> body = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return AbsenceDocumentModel.fromJson(
        body['data'] as Map<String, dynamic>,
      );
    }

    throw Exception(body['message'] ?? 'Gagal mengirim dokumen ketidakhadiran');
  }
}
