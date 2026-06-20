import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_activity_model.dart';
import 'api_service.dart';

class DailyActivityService {
  static String get baseUrl => ApiService.baseUrl;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<List<DailyActivityModel>> getActivities() async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Token login tidak ditemukan');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/daily-activities'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final list = data['data'] as List? ?? [];
      return list.map((item) => DailyActivityModel.fromJson(item)).toList();
    }

    throw Exception(data['message'] ?? 'Gagal mengambil data laporan kegiatan');
  }

  Future<DailyActivityModel> submitActivity({
    required String activityDate,
    required String startTime,
    required String endTime,
    required String title,
    required String description,
  }) async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Token login tidak ditemukan');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/daily-activities'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'activity_date': activityDate,
        'start_time': startTime,
        'end_time': endTime,
        'title': title,
        'description': description,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return DailyActivityModel.fromJson(data['data']);
    }

    throw Exception(data['message'] ?? 'Gagal menyimpan laporan kegiatan');
  }
}
