import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class AttendanceResponse {
  final bool success;
  final String message;
  final String? type;
  final Map<String, dynamic>? data;

  AttendanceResponse({
    required this.success,
    required this.message,
    this.type,
    this.data,
  });

  factory AttendanceResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceResponse(
      success: (json['matched'] == true) || (json['success'] == true),
      message: json['message']?.toString() ?? 'Tidak ada pesan',
      type: json['type']?.toString(),
      data: json,
    );
  }
}

class AttendanceService {
  static String get _baseUrl => ApiService.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<AttendanceResponse> submitAttendance({
    required String mode,
    required Uint8List imageBytes,
    String fileName = 'face.jpg',
  }) async {
    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Token login tidak ditemukan, silakan login ulang');
      }

      final uri = Uri.parse('$_baseUrl/attendance-face');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['type'] = mode;

      request.files.add(
        http.MultipartFile.fromBytes(
          'face_image',
          imageBytes,
          filename: fileName,
        ),
      );

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return AttendanceResponse.fromJson(body);
      }

      return AttendanceResponse(
        success: false,
        message: body['message']?.toString() ??
            'HTTP ${response.statusCode}: ${response.body}',
        type: body['type']?.toString(),
        data: body,
      );
    } catch (e) {
      return AttendanceResponse(
        success: false,
        message: 'Gagal kirim absensi: $e',
      );
    }
  }

  static Future<List<Map<String, dynamic>>> getHistory() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token login tidak ditemukan');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/attendance-history'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final list = data['data'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    }

    throw Exception(data['message'] ?? 'Gagal mengambil riwayat kehadiran');
  }

  static Future<Map<String, dynamic>?> getTodayAttendance() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token login tidak ditemukan');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/today-attendance'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data['data'] as Map<String, dynamic>?;
    }

    throw Exception(data['message'] ?? 'Gagal mengambil kehadiran hari ini');
  }
}