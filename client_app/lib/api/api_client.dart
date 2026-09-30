import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://law-union-backend.onrender.com',
);


class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(
    this.message, {
    this.statusCode,
  });

  @override
  String toString() => message;
}


class ApiClient {
  static const String _tokenKey = 'auth_token';


  Future<String?> get _token async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_tokenKey);
  }


  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _tokenKey,
      token,
    );
  }


  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_tokenKey);
  }


  Future<Map<String, String>> _headers({
    bool json = true,
  }) async {
    final token = await _token;

    return {
      if (json)
        'Content-Type': 'application/json',

      'Accept': 'application/json',

      if (token != null && token.isNotEmpty)
        'Authorization': 'Token $token',
    };
  }


  Uri _uri(
    String path,
  ) {
    final base = kApiBaseUrl.endsWith('/')
        ? kApiBaseUrl.substring(
            0,
            kApiBaseUrl.length - 1,
          )
        : kApiBaseUrl;

    return Uri.parse(
      '$base$path',
    );
  }


  dynamic _decode(http.Response response) {
    if (response.body.isEmpty) {
      return {};
    }

    try {
      return jsonDecode(response.body);
    } catch (_) {
      return {
        'detail': response.body,
      };
    }
  }


  String _errorMessage(
    dynamic data,
    String fallback,
  ) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];

      if (detail != null) {
        return detail.toString();
      }

      final firstError = data.values.firstOrNull;

      if (firstError != null) {
        if (firstError is List && firstError.isNotEmpty) {
          return firstError.first.toString();
        }

        return firstError.toString();
      }
    }

    return fallback;
  }


  Future<Map<String, dynamic>> health() async {
    final response = await http.get(
      _uri('/api/health/'),
      headers: await _headers(
        json: false,
      ),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw ApiException(
        _errorMessage(
          data,
          'Backend health check failed.',
        ),
        statusCode: response.statusCode,
      );
    }

    return Map<String, dynamic>.from(
      data as Map,
    );
  }


  Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final response = await http.post(
      _uri('/api/auth/login/'),
      headers: await _headers(),
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw ApiException(
        _errorMessage(
          data,
          'Sign in failed.',
        ),
        statusCode: response.statusCode,
      );
    }

    final token = data['token'];

    if (token == null || token.toString().isEmpty) {
      throw ApiException(
        'The server did not return an authentication token.',
      );
    }

    await _saveToken(
      token.toString(),
    );

    return Map<String, dynamic>.from(
      data as Map,
    );
  }


  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String studentId,
    required String displayName,
  }) async {
    final response = await http.post(
      _uri('/api/auth/register/'),
      headers: await _headers(),
      body: jsonEncode({
        'username': username,
        'password': password,
        'student_id': studentId,
        'display_name': displayName,
      }),
    );

    final data = _decode(response);

    if (response.statusCode != 201) {
      throw ApiException(
        _errorMessage(
          data,
          'Registration failed.',
        ),
        statusCode: response.statusCode,
      );
    }

    final token = data['token'];

    if (token != null) {
      await _saveToken(
        token.toString(),
      );
    }

    return Map<String, dynamic>.from(
      data as Map,
    );
  }


  Future<Map<String, dynamic>> me() async {
    final response = await http.get(
      _uri('/api/auth/me/'),
      headers: await _headers(),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw ApiException(
        _errorMessage(
          data,
          'Unable to load profile.',
        ),
        statusCode: response.statusCode,
      );
    }

    return Map<String, dynamic>.from(
      data as Map,
    );
  }


  Future<List<dynamic>> getHubs() async {
    final response = await http.get(
      _uri('/api/hubs/'),
      headers: await _headers(),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw ApiException(
        _errorMessage(
          data,
          'Unable to load community data.',
        ),
        statusCode: response.statusCode,
      );
    }

    if (data is List) {
      return data;
    }

    if (data is Map<String, dynamic>) {
      final results = data['results'];

      if (results is List) {
        return results;
      }
    }

    return [];
  }


  Future<List<dynamic>> getHubMembershipRequests(int hubId) async {
    final response = await http.get(
      _uri('/api/hubs/$hubId/membership_requests/'),
      headers: await _headers(),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(data, 'تعذر تحميل طلبات الانضمام.'), statusCode: response.statusCode);
    }
    if (data is List) return data;
    return [];
  }

  Future<void> approveHubMember(int hubId, int userId) async {
    final response = await http.post(
      _uri('/api/hubs/$hubId/approve_member/'),
      headers: await _headers(),
      body: jsonEncode({'user_id': userId}),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(data, 'تعذر قبول العضو.'), statusCode: response.statusCode);
    }
  }

  Future<void> rejectHubMember(int hubId, int userId) async {
    final response = await http.post(
      _uri('/api/hubs/$hubId/reject_member/'),
      headers: await _headers(),
      body: jsonEncode({'user_id': userId}),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(data, 'تعذر رفض الطلب.'), statusCode: response.statusCode);
    }
  }

  Future<String> requestHubMembership(int hubId) async {
    final response = await http.post(
      _uri('/api/hubs/$hubId/request_membership/'),
      headers: await _headers(),
    );
    final data = _decode(response);
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw ApiException(
        _errorMessage(data, 'تعذر إرسال طلب الانضمام.'),
        statusCode: response.statusCode,
      );
    }
    return (data is Map ? data['status'] : null)?.toString() ?? 'pending';
  }

  Future<List<dynamic>> getPosts(
    int hubId,
  ) async {
    final response = await http.get(
      _uri('/api/posts/?hub=$hubId'),
      headers: await _headers(),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw ApiException(
        _errorMessage(
          data,
          'Unable to load posts.',
        ),
        statusCode: response.statusCode,
      );
    }

    if (data is List) {
      return data;
    }

    if (data is Map<String, dynamic>) {
      final results = data['results'];

      if (results is List) {
        return results;
      }
    }

    return [];
  }


  Future<void> createPost(
    int hubId,
    String body,
  ) async {
    final response = await http.post(
      _uri('/api/posts/'),
      headers: await _headers(),
      body: jsonEncode({
        'hub': hubId,
        'body': body,
      }),
    );

    if (response.statusCode != 201) {
      final data = _decode(response);

      throw ApiException(
        _errorMessage(
          data,
          'Unable to publish post.',
        ),
        statusCode: response.statusCode,
      );
    }
  }


  Future<List<dynamic>> getMessages(
    int roomId,
  ) async {
    final response = await http.get(
      _uri('/api/messages/?room=$roomId'),
      headers: await _headers(),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw ApiException(
        _errorMessage(
          data,
          'Unable to load messages.',
        ),
        statusCode: response.statusCode,
      );
    }

    if (data is List) {
      return data;
    }

    if (data is Map<String, dynamic>) {
      final results = data['results'];

      if (results is List) {
        return results;
      }
    }

    return [];
  }

  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> values,
  ) async {
    final response = await http.patch(
      _uri('/api/auth/me/'),
      headers: await _headers(),
      body: jsonEncode(values),
    );

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw ApiException(
        _errorMessage(data, 'Unable to update profile.'),
        statusCode: response.statusCode,
      );
    }

    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<dynamic>> getChatRooms() async {
    final response = await http.get(
      _uri('/api/chat-rooms/'),
      headers: await _headers(),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _errorMessage(data, 'Unable to load chats.'),
        statusCode: response.statusCode,
      );
    }
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['results'] is List) {
      return data['results'];
    }
    return [];
  }

  Future<Map<String, dynamic>> createChatRoom({
    int? hubId,
    required String name,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'is_direct_message': false,
    };
    if (hubId != null) body['hub'] = hubId;

    final response = await http.post(
      _uri('/api/chat-rooms/'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    final data = _decode(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _errorMessage(data, 'Unable to create chat room.'),
        statusCode: response.statusCode,
      );
    }
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> sendMessage(
    int roomId,
    String body,
  ) async {
    final response = await http.post(
      _uri('/api/messages/'),
      headers: await _headers(),
      body: jsonEncode({
        'room': roomId,
        'body': body,
      }),
    );
    if (response.statusCode != 201) {
      final data = _decode(response);
      throw ApiException(
        _errorMessage(data, 'Unable to send message.'),
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<dynamic>> getWiki(int hubId) async {
    final response = await http.get(
      _uri('/api/wiki/?hub=$hubId'),
      headers: await _headers(),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _errorMessage(data, 'Unable to load wiki.'),
        statusCode: response.statusCode,
      );
    }
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['results'] is List) {
      return data['results'];
    }
    return [];
  }

  Future<Map<String, dynamic>> createWiki({
    required int hubId,
    required String title,
    required String content,
  }) async {
    final response = await http.post(
      _uri('/api/wiki/'),
      headers: await _headers(),
      body: jsonEncode({
        'hub': hubId,
        'title': title,
        'content': content,
        'slug': title.toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
      }),
    );
    final data = _decode(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _errorMessage(data, 'Unable to create wiki page.'),
        statusCode: response.statusCode,
      );
    }
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<dynamic>> getFlashcards(int hubId) async {
    final response = await http.get(
      _uri('/api/flashcards/?hub=$hubId'),
      headers: await _headers(),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(data, 'تعذر تحميل البطاقات التعليمية.'), statusCode: response.statusCode);
    }
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['results'] is List) return data['results'];
    return [];
  }

  Future<Map<String, dynamic>> createFlashcard({
    required int hubId,
    required String frontText,
    required String backText,
  }) async {
    final response = await http.post(
      _uri('/api/flashcards/'),
      headers: await _headers(),
      body: jsonEncode({
        'hub': hubId,
        'front_text': frontText,
        'back_text': backText,
      }),
    );
    final data = _decode(response);
    if (response.statusCode != 201) {
      throw ApiException(_errorMessage(data, 'تعذر إنشاء البطاقة التعليمية.'), statusCode: response.statusCode);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<dynamic>> getPolls(int hubId) async {
    final response = await http.get(
      _uri('/api/polls/?hub=$hubId'),
      headers: await _headers(),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(data, 'تعذر تحميل الاستطلاعات.'), statusCode: response.statusCode);
    }
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['results'] is List) return data['results'];
    return [];
  }

  Future<List<dynamic>> getQuizzes(int hubId) async {
    final response = await http.get(
      _uri('/api/quizzes/?hub=$hubId'),
      headers: await _headers(),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(data, 'تعذر تحميل الاختبارات.'), statusCode: response.statusCode);
    }
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['results'] is List) return data['results'];
    return [];
  }

  Future<List<dynamic>> getBadges() async {
    final response = await http.get(
      _uri('/api/user-badges/'),
      headers: await _headers(),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _errorMessage(data, 'Unable to load badges.'),
        statusCode: response.statusCode,
      );
    }
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['results'] is List) {
      return data['results'];
    }
    return [];
  }

  Future<String?> authToken() async {
    return _token;
  }

}


extension FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull {
    if (isEmpty) {
      return null;
    }

    return first;
  }
}
