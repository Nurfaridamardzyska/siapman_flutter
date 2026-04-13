import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fault_report_model.dart';
import 'api_service.dart';

class FaultReportService {
  static String get _baseUrl => ApiService.baseUrl;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<List<FaultReportModel>> getReports() async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Token login tidak ditemukan');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/fault-reports'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final list = data['data'] as List? ?? [];
      return list.map((e) => FaultReportModel.fromJson(e)).toList();
    }

    throw Exception(data['message'] ?? 'Gagal mengambil laporan kendala');
  }
}