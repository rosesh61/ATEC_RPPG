import 'package:shared_preferences/shared_preferences.dart';
import '../db/user_dao.dart';
import '../models/user.dart';
import 'shared_api_service.dart';

/// 현재 로그인된 사용자를 앱 전역에서 관리
class UserSession {
  static final UserSession instance = UserSession._internal();
  UserSession._internal();

  static const _keyUserId = 'current_user_id';

  User? _currentUser;
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// 앱 시작 시 호출 — 저장된 사용자 ID로 자동 복원
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_keyUserId);
    if (userId != null) {
      _currentUser = await UserDao().getById(userId);
    }
  }

  /// 사용자 등록 후 세션 저장
  /// 서버 우선 → 실패 시 로컬만 저장
  Future<void> register(User user, {List<double>? faceDescriptor}) async {
    print('[register] 얼굴 임베딩: ${faceDescriptor != null ? '${faceDescriptor.length}차원' : 'null'}');
    // 1. 서버에 먼저 등록 시도
    String? serverId = await SharedApiService.instance.createUser(
      name: user.name,
      phone: user.phone,
      birthYear: user.birthYear,
      gender: user.gender,
      region: user.region,
      faceDescriptor: faceDescriptor,
    );
    print('[register] serverId: $serverId');

    // 생성 실패 시 동명 사용자가 이미 있는지 검색해서 연결
    if (serverId == null) {
      final existing = await SharedApiService.instance.findUserByName(user.name);
      serverId = existing?['user_id'] as String?;
    }

    final userWithServerId = serverId != null
        ? user.copyWith(serverId: serverId)
        : user;

    // 2. 로컬 DB 저장
    final localId = await UserDao().insert(userWithServerId);
    _currentUser = userWithServerId.copyWith(id: localId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, localId);
  }

  /// 기존 회원 이름으로 로그인
  /// 서버 우선 → 실패 시 로컬 DB fallback
  Future<User?> loginByName(String name) async {
    // 1. 서버에서 검색
    final serverData = await SharedApiService.instance.findUserByName(name);
    if (serverData != null) {
      final info = serverData['user_info'] as Map<String, dynamic>;
      final serverId = serverData['user_id'] as String;

      // 로컬 DB에서 server_id로 매칭 또는 이름으로 찾아 업데이트
      User? localUser = await UserDao().getByServerId(serverId);
      if (localUser == null) {
        // 로컬에 없으면 이름으로 찾기
        localUser = await _findLocalByName(name);
        if (localUser != null) {
          // server_id 연결
          localUser = localUser.copyWith(serverId: serverId);
          await UserDao().update(localUser);
        } else {
          // 로컬에 아예 없으면 새로 삽입
          final newUser = User(
            name: info['name'] as String? ?? name,
            phone: info['phone'] as String?,
            serverId: serverId,
          );
          final localId = await UserDao().insert(newUser);
          localUser = newUser.copyWith(id: localId);
        }
      }

      _currentUser = localUser;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyUserId, localUser.id!);
      return _currentUser;
    }

    // 2. 서버 실패 → 로컬 fallback
    final localUser = await _findLocalByName(name);
    if (localUser == null) return null;
    _currentUser = localUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, localUser.id!);
    return _currentUser;
  }

  Future<User?> _findLocalByName(String name) async {
    final all = await UserDao().getAll();
    final found = all.where((u) => u.name.trim() == name.trim()).toList();
    return found.isEmpty ? null : found.first;
  }

  /// 얼굴 임베딩으로 로그인 (서버 전용 — 로컬 fallback 없음)
  Future<User?> loginByFace(List<double> descriptor) async {
    final serverData =
        await SharedApiService.instance.loginWithFace(descriptor);
    if (serverData == null) return null;

    final info = serverData['user_info'] as Map<String, dynamic>;
    final serverId = serverData['user_id'] as String;

    User? localUser = await UserDao().getByServerId(serverId);
    if (localUser == null) {
      final newUser = User(
        name: info['name'] as String? ?? '',
        phone: info['phone'] as String?,
        serverId: serverId,
      );
      final localId = await UserDao().insert(newUser);
      localUser = newUser.copyWith(id: localId);
    }

    _currentUser = localUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, localUser.id!);
    return _currentUser;
  }

  /// 사용자 정보 수정
  Future<void> update(User user) async {
    await UserDao().update(user);
    _currentUser = user;
  }

  /// 로그아웃
  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
  }
}
