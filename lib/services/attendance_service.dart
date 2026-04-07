import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String baseUrl = 'http://10.110.118.205:8000/api';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<AttendanceResponse> submitAttendance({
    required String mode,
    required File imageFile,
  }) async {
    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Token login tidak ditemukan, silakan login ulang');
      }

      final uri = Uri.parse('$baseUrl/attendance-face');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['type'] = mode;

      request.files.add(
        await http.MultipartFile.fromPath('face_image', imageFile.path),
      );

      final streamed = await request.send();
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
}