import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ─── Base URL ──────────────────────────────────────────────────────────────
  // Default per platform:
  // • Web / Desktop     → 127.0.0.1
  // • Android emulator  → 10.0.2.2 (alias localhost dari emulator)
  // Override dengan: --dart-define=API_BASE_URL=http://<host>:8000/api
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (kIsWeb) return 'http://127.0.0.1:8000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  // ─── Helper: headers JSON ──────────────────────────────────────────────────
  static Map<String, String> _jsonHeaders({String? token}) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // ─── Helper: baca token dari pref ─────────────────────────────────────────
  Future<String> _requireToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (token.isEmpty) throw Exception('Token tidak ditemukan, silakan login ulang');
    return token;
  }

  // ─── Auth: Login ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login({
    required String nip,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/login'),
          headers: _jsonHeaders(),
          body: jsonEncode({'nip': nip, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Login gagal (${response.statusCode})');
  }

  // ─── Auth: Me ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMe() async {
    final token = await _requireToken();
    final response = await http
        .get(
          Uri.parse('$baseUrl/me'),
          headers: _jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 15));

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Gagal mengambil data user');
  }

  // ─── Dashboard ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboard() async {
    final token = await _requireToken();
    final response = await http
        .get(
          Uri.parse('$baseUrl/dashboard'),
          headers: _jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 15));

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Gagal mengambil data dashboard');
  }

  // ─── Face: Register Wajah ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> registerFace({
    required String filePath,
  }) async {
    final token = await _requireToken();

    final uri = Uri.parse('$baseUrl/register-face');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('face_image', filePath));

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw Exception(body['message'] ?? 'Gagal mendaftarkan wajah');
  }

  // ─── Face: Absensi (check-in / check-out) ────────────────────────────────
  Future<Map<String, dynamic>> submitAttendanceFace({
    required String type, // 'masuk' atau 'pulang'
    required String filePath,
  }) async {
    final token = await _requireToken();

    final uri = Uri.parse('$baseUrl/attendance-face');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['type'] = type
      ..files.add(await http.MultipartFile.fromPath('face_image', filePath));

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw Exception(body['message'] ?? 'Gagal mengirim absensi');
  }

  // ─── Attendance: History ──────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAttendanceHistory() async {
    final token = await _requireToken();
    final response = await http
        .get(
          Uri.parse('$baseUrl/attendance-history'),
          headers: _jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return (data['data'] as List? ?? []).cast<Map<String, dynamic>>();
    }
    throw Exception(data['message'] ?? 'Gagal mengambil riwayat kehadiran');
  }

  // ─── Attendance: Today ────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getTodayAttendance() async {
    final token = await _requireToken();
    final response = await http
        .get(
          Uri.parse('$baseUrl/today-attendance'),
          headers: _jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data['data'] as Map<String, dynamic>?;
    }
    throw Exception(data['message'] ?? 'Gagal mengambil kehadiran hari ini');
  }

  // ─── Absence Documents ────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAbsenceDocuments() async {
    final token = await _requireToken();
    final response = await http
        .get(
          Uri.parse('$baseUrl/absence-documents'),
          headers: _jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return (data['data'] as List? ?? []).cast<Map<String, dynamic>>();
    }
    throw Exception(data['message'] ?? 'Gagal mengambil dokumen ketidakhadiran');
  }

  Future<Map<String, dynamic>> submitAbsenceDocument({
    required String documentType,
    required String title,
    required String startDate,
    required String endDate,
    String? notes,
    File? file,
  }) async {
    final token = await _requireToken();

    final uri = Uri.parse('$baseUrl/absence-documents');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['document_type'] = documentType
      ..fields['title'] = title
      ..fields['start_date'] = startDate
      ..fields['end_date'] = endDate;

    if (notes != null) request.fields['notes'] = notes;
    if (file != null) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
    }

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201 || response.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Gagal mengirim dokumen');
  }

  // ─── Fault Reports ────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getFaultReports() async {
    final token = await _requireToken();
    final response = await http
        .get(
          Uri.parse('$baseUrl/fault-reports'),
          headers: _jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return (data['data'] as List? ?? []).cast<Map<String, dynamic>>();
    }
    throw Exception(data['message'] ?? 'Gagal mengambil laporan kendala');
  }

  Future<Map<String, dynamic>> submitFaultReport({
    required String title,
    required String description,
    File? attachment,
  }) async {
    final token = await _requireToken();

    final uri = Uri.parse('$baseUrl/fault-reports');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['title'] = title
      ..fields['description'] = description;

    if (attachment != null) {
      request.files
          .add(await http.MultipartFile.fromPath('attachment', attachment.path));
    }

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201 || response.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Gagal mengirim laporan kendala');
  }

  // ─── Helper: URL gambar di storage ────────────────────────────────────────
  static String imageUrl(String path) {
    final origin = baseUrl.replaceFirst('/api', '');
    return '$origin/storage/$path';
  }
}