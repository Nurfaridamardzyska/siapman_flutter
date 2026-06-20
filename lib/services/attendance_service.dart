import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siapman_baru/services/device_service.dart';

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
  static String get baseUrl => ApiService.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<AttendanceResponse> submitAttendance({
    required String mode,
    required File imageFile,
    required double? latitude,
    required double? longitude,
    required String sessionId,
    required String livenessToken,
    bool debugMode = false,
    bool localLiveness = false,
  }) async {
    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Token login tidak ditemukan, silakan login ulang');
      }

      final uri = Uri.parse('$baseUrl/attendance-face');
      final request = http.MultipartRequest('POST', uri);
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final nonce = '$ts-${Random.secure().nextInt(1 << 31)}';
      final deviceId = await DeviceService.getUniqueId();

      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['X-Device-Id'] = deviceId;
      request.headers['X-Request-Timestamp'] = ts.toString();
      request.headers['X-Request-Nonce'] = nonce;

      request.fields['type'] = mode;
      request.fields['session_id'] = sessionId;
      request.fields['liveness_token'] = livenessToken;
      if (debugMode && !kReleaseMode) {
        request.fields['debug_mode'] = '1';
      }
      if (localLiveness) {
        request.fields['local_liveness'] = '1';
      }

      if (latitude != null) {
        request.fields['latitude'] = latitude.toString();
      }
      if (longitude != null) {
        request.fields['longitude'] = longitude.toString();
      }

      request.files.add(
        await http.MultipartFile.fromPath('face_image', imageFile.path),
      );

      final streamed = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamed);

      final dynamic parsed = jsonDecode(response.body);
      final Map<String, dynamic> body = parsed is Map<String, dynamic>
          ? parsed
          : <String, dynamic>{};

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return AttendanceResponse.fromJson(body);
      }

      return AttendanceResponse(
        success: false,
        message:
            body['message']?.toString() ??
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
