import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SharedApiService {
  static final SharedApiService instance = SharedApiService._internal();
  SharedApiService._internal();

  static const _keyServerUrl = 'server_url';
  static const _defaultUrl = 'http://127.0.0.1:8000';

  Future<String> get baseUrl async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServerUrl) ?? _defaultUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, url.trimRight().replaceAll(RegExp(r'/$'), ''));
  }

  /// 서버 연결 상태 확인
  Future<bool> checkHealth() async {
    try {
      final url = await baseUrl;
      final res = await http
          .get(Uri.parse('$url/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // 사용자
  // ─────────────────────────────────────────────

  /// 사용자 생성. 반환값: server user_id (UUID string) or null
  Future<String?> createUser({
    required String name,
    String? phone,
    int? birthYear,
    int? birthMonth,
    String? gender,
    String? region,
    List<double>? faceDescriptor,
  }) async {
    try {
      final url = await baseUrl;
      final res = await http
          .post(
            Uri.parse('$url/users'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_info': {
                'name': name,
                if (phone != null) 'phone': phone,
                if (birthYear != null) 'birth_year': birthYear,
                if (birthMonth != null) 'birth_month': birthMonth,
                if (gender != null) 'gender': gender,
                if (region != null) 'region': region,
              },
              if (faceDescriptor != null) 'face_descriptor': faceDescriptor,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['user_id'] as String?;
      }
      print('[createUser] 실패 status=${res.statusCode} body=${res.body}');
    } catch (e) {
      print('[createUser] 예외: $e');
    }
    return null;
  }

  /// 얼굴 임베딩으로 로그인. 반환값: 사용자 데이터 or null
  Future<Map<String, dynamic>?> loginWithFace(
    List<double> descriptor, {
    double threshold = 0.363,
  }) async {
    try {
      final url = await baseUrl;
      final res = await http
          .post(
            Uri.parse('$url/users/face-login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'descriptor': descriptor,
              'threshold': threshold,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = res.body.trim();
        if (body == 'null') return null;
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// 기존 사용자의 얼굴 임베딩 업데이트
  Future<bool> updateFaceDescriptor(
      String serverId, List<double> descriptor) async {
    try {
      final url = await baseUrl;
      final res = await http
          .put(
            Uri.parse('$url/users/$serverId/face'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'face_descriptor': descriptor}),
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  /// 이름으로 사용자 검색. 첫 번째 매칭 사용자 반환
  Future<Map<String, dynamic>?> findUserByName(String name) async {
    try {
      final url = await baseUrl;
      final res = await http
          .get(Uri.parse('$url/users?name=${Uri.encodeComponent(name)}'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        if (list.isNotEmpty) return list.first as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// server_id로 사용자 조회
  Future<Map<String, dynamic>?> getUserById(String serverId) async {
    try {
      final url = await baseUrl;
      final res = await http
          .get(Uri.parse('$url/users/$serverId'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ─────────────────────────────────────────────
  // QR 토큰
  // ─────────────────────────────────────────────

  /// QR 토큰 생성. 반환값: token string or null
  Future<String?> generateQrToken(String serverId, {int expiresMinutes = 5}) async {
    try {
      final url = await baseUrl;
      final res = await http
          .post(
            Uri.parse('$url/users/$serverId/qr-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'expires_minutes': expiresMinutes}),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['token'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// QR 토큰으로 로그인. 반환값: 사용자 데이터 or null
  Future<Map<String, dynamic>?> loginWithQrToken(String token) async {
    try {
      final url = await baseUrl;
      final res = await http
          .get(Uri.parse('$url/users/qr-login?token=${Uri.encodeComponent(token)}'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = res.body.trim();
        if (body == 'null') return null;
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// QR 토큰 무효화
  Future<void> invalidateQrToken(String serverId) async {
    try {
      final url = await baseUrl;
      await http
          .delete(Uri.parse('$url/users/$serverId/qr-token'))
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // 세션 (측정 결과)
  // ─────────────────────────────────────────────

  /// 측정 결과 세션 저장
  Future<bool> saveSession(String serverId, Map<String, dynamic> sessionData) async {
    try {
      final url = await baseUrl;
      final res = await http
          .post(
            Uri.parse('$url/users/$serverId/sessions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(sessionData),
          )
          .timeout(const Duration(seconds: 10));

      return res.statusCode == 201;
    } catch (_) {}
    return false;
  }

  /// 세션 기록 조회
  Future<List<Map<String, dynamic>>> getSessions(String serverId) async {
    try {
      final url = await baseUrl;
      final res = await http
          .get(Uri.parse('$url/users/$serverId/sessions'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }
}
