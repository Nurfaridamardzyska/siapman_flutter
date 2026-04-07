import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Untuk iPhone fisik / device lain dalam jaringan yang sama
  static const String baseUrl = 'http://10.110.118.205:8000/api';

  // Kalau nanti pakai simulator di Mac yang sama, ganti ke:
  // static const String baseUrl = 'http://127.0.0.1:8000/api';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();

    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
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
    return jsonDecode(response.body);
  }

  Exception _buildException(http.Response response, dynamic data, String fallback) {
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
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'nip': nip,
        'password': password,
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

  Future<Map<String, dynamic>> registerFace({
    required String filePath,
  }) async {
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

    request.files.add(
      await http.MultipartFile.fromPath('face_image', filePath),
    );

    final streamedResponse = await request.send();
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
    request.fields['type'] = type;

    request.files.add(
      await http.MultipartFile.fromPath('face_image', filePath),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data);
    }

    throw _buildException(response, data, 'Absensi gagal');
  }

  Future<Map<String, dynamic>> getAttendanceHistory() async {
    final response = await http.get(
      Uri.parse('$baseUrl/attendance-history'),
      headers: await _authHeaders(),
    );

    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(data);
    }

    throw _buildException(response, data, 'Gagal mengambil riwayat absensi');
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

  Future<List<dynamic>> getAbsenceDocuments() async {
    final response = await http.get(
      Uri.parse('$baseUrl/absence-documents'),
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

    throw _buildException(
      response,
      data,
      'Gagal mengambil dokumen ketidakhadiran',
    );
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
      body: jsonEncode({
        'judul': judul,
        'deskripsi': deskripsi,
      }),
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
}