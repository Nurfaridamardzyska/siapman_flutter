import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siapman_baru/services/device_service.dart';

class ApiService {
  static const String _devBaseUrl = String.fromEnvironment(
    'API_BASE_URL_DEV',
    defaultValue: 'https://siapman.tech/api',
  );
  static const String _prodBaseUrl = String.fromEnvironment(
    'API_BASE_URL_PROD',
    defaultValue: 'https://siapman.tech/api',
  );

  static String get baseUrl {
    if (kReleaseMode && _prodBaseUrl.isNotEmpty) {
      return _prodBaseUrl;
    }
    return _devBaseUrl;
  }

  static String formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    String str = amount.toString();
    String result = '';
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      result = str[i] + result;
      count++;
      if (count % 3 == 0 && i != 0) {
        result = '.$result';
      }
    }
    return result;
  }

  Future<List<dynamic>> getNotifications() async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: await _authHeaders(),
    );

    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      if (data is Map<String, dynamic> && data['data'] is List) {
        return data['data'] as List<dynamic>;
      }
      return [];
    }

    throw _buildException(response, data, 'Gagal mengambil notifikasi');
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    final deviceId = await DeviceService.getUniqueId();

    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
      'X-Device-Id': deviceId,
    };
  }

  Future<Map<String, String>> _authHeadersWithNonce() async {
    final headers = await _authHeaders();
    _applyNonceHeaders(headers);
    return headers;
  }

  void _applyNonceHeaders(Map<String, String> headers) {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nonce = '$ts-${Random.secure().nextInt(1 << 31)}';
    headers['X-Request-Timestamp'] = ts.toString();
    headers['X-Request-Nonce'] = nonce;
  }

  Future<Map<String, String>> _jsonHeaders() async {
    final token = await _getToken();

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  dynamic _decodeBody(http.Response response) {
    if (response.body.isEmpty) return {};
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return {'message': response.body};
    }
  }

  Exception _buildException(
    http.Response response,
    dynamic data,
    String fallback,
  ) {
    if (data is Map<String, dynamic>) {
      if (data['message'] != null) {
        return Exception(data['message']);
      }

      if (data['errors'] != null) {
        return Exception(data['errors'].toString());
      }
    }

    return Exception('$fallback (HTTP ${response.statusCode})');
  }

  Future<Map<String, dynamic>> login({
    required String nip,
    required String password,
  }) async {
    // Otomatis deteksi Device ID
    final String deviceId = await DeviceService.getUniqueId();

    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'nip': nip,
        'password': password,
        'device_id': deviceId,
      }),
    );

    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data);
    }

    throw _buildException(response, data, 'Login gagal');
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard'),
      headers: await _authHeaders(),
    );

    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data);
    }

    throw _buildException(response, data, 'Gagal mengambil dashboard');
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/me/profile'),
      headers: await _authHeaders(),
    );

    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data);
    }

    throw _buildException(response, data, 'Gagal mengambil profil pegawai');
  }

  Future<Map<String, dynamic>> registerFace({required String filePath}) async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Token login tidak ditemukan, silakan login ulang');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/register-face'),
    );

    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['X-Device-Id'] = await DeviceService.getUniqueId();
    _applyNonceHeaders(request.headers);

    request.files.add(
      await http.MultipartFile.fromPath('face_image', filePath),
    );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
    );
    final response = await http.Response.fromStream(streamedResponse);
    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data);
    }

    throw _buildException(response, data, 'Registrasi wajah gagal');
  }

  Future<Map<String, dynamic>> attendanceFace({
    required String filePath,
    required String type,
    required double latitude,
    required double longitude,
    required String sessionId,
    required String livenessToken,
  }) async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Token login tidak ditemukan, silakan login ulang');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/attendance-face'),
    );

    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['X-Device-Id'] = await DeviceService.getUniqueId();
    _applyNonceHeaders(request.headers);
    request.fields['type'] = type;
    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();
    request.fields['session_id'] = sessionId;
    request.fields['liveness_token'] = livenessToken;

    request.files.add(
      await http.MultipartFile.fromPath('face_image', filePath),
    );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
    );
    final response = await http.Response.fromStream(streamedResponse);
    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data);
    }

    throw _buildException(response, data, 'Absensi gagal');
  }

  Future<Map<String, dynamic>> getFaceLivenessStatus() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/face/liveness/status'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 10));

    final data = _decodeBody(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(data as Map);
    }

    throw _buildException(response, data, 'Gagal mengambil status liveness');
  }

  Future<Map<String, dynamic>> submitFaceLivenessFrame({
    required String filePath,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token login tidak ditemukan, silakan login ulang');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/face/liveness/frame'),
    );
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['X-Device-Id'] = await DeviceService.getUniqueId();
    _applyNonceHeaders(request.headers);
    request.files.add(
      await http.MultipartFile.fromPath('face_image', filePath),
    );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 15),
    );
    final response = await http.Response.fromStream(streamedResponse);
    final data = _decodeBody(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(data as Map);
    }

    throw _buildException(response, data, 'Gagal memproses frame liveness');
  }

  Future<Map<String, dynamic>> resetFaceLiveness() async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/face/liveness/reset'),
          headers: await _authHeadersWithNonce(),
        )
        .timeout(const Duration(seconds: 10));

    final data = _decodeBody(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(data as Map);
    }

    throw _buildException(response, data, 'Gagal reset liveness');
  }

  Future<Map<String, dynamic>> getAttendanceHistory() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/attendance-history'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 30));

      final data = _decodeBody(response);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(data);
      }

      throw _buildException(response, data, 'Gagal mengambil riwayat absensi');
    } on TimeoutException {
      throw Exception('Koneksi ke server timeout. Silakan periksa koneksi internet Anda dan coba lagi.');
    }
  }

  Future<Map<String, dynamic>> getDailyAttendanceReport({
    String? tanggal,
  }) async {
    final uri = tanggal == null
        ? Uri.parse('$baseUrl/laporan/presensi-harian')
        : Uri.parse('$baseUrl/laporan/presensi-harian?tanggal=$tanggal');

    final response = await http.get(uri, headers: await _authHeaders());

    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data as Map);
    }

    throw _buildException(
      response,
      data,
      'Gagal mengambil laporan presensi harian',
    );
  }

  Future<Map<String, dynamic>> getMonthlyAttendanceReport({
    required int month,
    required int year,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/laporan/presensi-bulanan?month=$month&year=$year',
    );

    final response = await http.get(uri, headers: await _authHeaders());

    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data as Map);
    }

    throw _buildException(
      response,
      data,
      'Gagal mengambil laporan presensi bulanan',
    );
  }

  Future<Map<String, dynamic>> getTodayAttendance() async {
    final response = await http.get(
      Uri.parse('$baseUrl/today-attendance'),
      headers: await _authHeaders(),
    );

    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data);
    }

    throw _buildException(
      response,
      data,
      'Gagal mengambil status absensi hari ini',
    );
  }

  Future<Map<String, dynamic>> getAttendanceSchedules({int? categoryId}) async {
    final uri = categoryId == null
        ? Uri.parse('$baseUrl/attendance-schedules')
        : Uri.parse('$baseUrl/attendance-schedules?category_id=$categoryId');

    final response = await http.get(uri, headers: await _authHeaders());

    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data as Map);
    }

    throw _buildException(response, data, 'Gagal mengambil jadwal absensi');
  }

  Future<List<dynamic>> getAbsenceDocuments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/absence-documents'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 30));

      final data = _decodeBody(response);

      if (response.statusCode == 200) {
        if (data is List) {
          return data;
        }

        if (data is Map<String, dynamic> && data['data'] is List) {
          return data['data'] as List<dynamic>;
        }

        return [];
      }

      throw _buildException(
        response,
        data,
        'Gagal mengambil dokumen ketidakhadiran',
      );
    } on TimeoutException {
      throw Exception('Koneksi ke server timeout. Silakan periksa koneksi internet Anda dan coba lagi.');
    }
  }

  Future<List<dynamic>> getKendalaList() async {
    final response = await http.get(
      Uri.parse('$baseUrl/kendala'),
      headers: await _authHeaders(),
    );

    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      if (data is List) {
        return data;
      }

      if (data is Map<String, dynamic> && data['data'] is List) {
        return data['data'] as List<dynamic>;
      }

      return [];
    }

    throw _buildException(response, data, 'Gagal mengambil laporan kendala');
  }

  Future<Map<String, dynamic>> createKendala({
    required String judul,
    required String deskripsi,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/kendala'),
      headers: await _jsonHeaders(),
      body: jsonEncode({'judul': judul, 'deskripsi': deskripsi}),
    );

    final data = _decodeBody(response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(data);
    }

    throw _buildException(response, data, 'Gagal mengirim laporan kendala');
  }

  Future<Map<String, dynamic>> getKendalaDetail(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/kendala/$id'),
      headers: await _authHeaders(),
    );

    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data);
    }

    throw _buildException(response, data, 'Gagal mengambil detail kendala');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('name');
    await prefs.remove('email');
    await prefs.remove('username');
    await prefs.remove('nip');
    await prefs.remove('role');
    await prefs.remove('unit_kerja');
    await prefs.remove('status');
  }

  Future<Map<String, dynamic>> getTppPercentage() async {
    final response = await http.get(
      Uri.parse('$baseUrl/tpp-percentage'),
      headers: await _authHeaders(),
    );

    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data);
    }

    throw _buildException(response, data, 'Gagal mengambil data TPP');
  }
}
