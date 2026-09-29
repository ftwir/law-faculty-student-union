import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Base URL is injected at build time:
/// flutter build apk --dart-define=API_BASE_URL=https://law-union-backend.onrender.com
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  static const _tokenKey = 'auth_token';

  Future<String?> get _token async =>
      (await SharedPreferences.getInstance()).getString(_tokenKey);

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await _token;
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  Uri _u(String path) => Uri.parse('$kApiBaseUrl$path');

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http.post(
      _u('/api/auth/login/'),
      headers: await _headers(),
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw ApiException(data['detail']?.toString() ?? 'فشل تسجيل الدخول');
    }
    await _saveToken(data['token']);
    return data;
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String studentId,
    required String displayName,
  }) async {
    final res = await http.post(
      _u('/api/auth/register/'),
      headers: await _headers(),
      body: jsonEncode({
        'username': username,
        'password': password,
        'student_id': studentId,
        'display_name': displayName,
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 201) {
      throw ApiException(data.toString());
    }
    await _saveToken(data['token']);
    return data;
  }

  Future<List<dynamic>> getHubs() async {
    final res = await http.get(_u('/api/hubs/'), headers: await _headers());
    if (res.statusCode != 200) throw ApiException('تعذر تحميل الأقسام');
    final data = jsonDecode(res.body);
    return data is List ? data : data['results'] ?? [];
  }

  Future<List<dynamic>> getPosts(int hubId) async {
    final res = await http.get(
      _u('/api/posts/?hub=$hubId'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) throw ApiException('تعذر تحميل المنشورات');
    final data = jsonDecode(res.body);
    return data is List ? data : data['results'] ?? [];
  }

  Future<void> createPost(int hubId, String body) async {
    final res = await http.post(
      _u('/api/posts/'),
      headers: await _headers(),
      body: jsonEncode({'hub': hubId, 'body': body}),
    );
    if (res.statusCode != 201) throw ApiException('تعذر نشر المنشور');
  }

  Future<List<dynamic>> getMessages(int roomId) async {
    final res = await http.get(
      _u('/api/messages/?room=$roomId'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) throw ApiException('تعذر تحميل الرسائل');
    final data = jsonDecode(res.body);
    return data is List ? data : data['results'] ?? [];
  }
}
