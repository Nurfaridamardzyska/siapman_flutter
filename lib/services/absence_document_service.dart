import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/absence_document_model.dart';
import 'api_service.dart';

class AbsenceDocumentService {
  static const String baseUrl = ApiService.baseUrl;

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
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final list = data['data'] as List? ?? [];
      return list
          .map((item) => AbsenceDocumentModel.fromJson(item))
          .toList();
    }

    throw Exception(
      data['message'] ?? 'Gagal mengambil dokumen ketidakhadiran',
    );
  }
}