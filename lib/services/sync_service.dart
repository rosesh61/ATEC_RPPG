import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../db/cause_dao.dart';
import '../db/measurement_dao.dart';
import '../db/user_dao.dart';
import '../models/user.dart';
import 'shared_api_service.dart';
import 'user_session.dart';

/// 서버 미동기화 데이터(사용자/측정/원인 기록)를 자동으로 올리는 서비스.
///
/// 저장 시점에는 각 화면이 즉시 업로드를 시도하고, 실패한 데이터는
/// synced=0(사용자는 server_id 없음)으로 남는다. 이 서비스가 그 잔여분을
/// 다음 시점마다 다시 밀어올린다:
///   1. 앱 시작 시
///   2. 네트워크 연결이 복구될 때
///   3. 주기적으로 (5분)
///   4. 서버 주소가 새로 설정됐을 때 (설정 화면/QR 스캔)
class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  bool _started = false;
  bool _syncing = false;
  Timer? _periodicTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// 앱 시작 시 1회 호출. 즉시 동기화를 시도하고 자동 트리거를 등록한다.
  void start() {
    if (_started) return;
    _started = true;

    syncAll();

    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) syncAll();
    });

    _periodicTimer =
        Timer.periodic(const Duration(minutes: 5), (_) => syncAll());
  }

  void dispose() {
    _periodicTimer?.cancel();
    _connectivitySub?.cancel();
    _started = false;
  }

  /// 미동기화 데이터 일괄 업로드. 동시 실행은 1회로 제한.
  Future<void> syncAll() async {
    if (_syncing) return;
    _syncing = true;
    try {
      // 서버가 안 닿으면 시도 자체를 생략 (불필요한 타임아웃 방지)
      if (!await SharedApiService.instance.checkHealth()) return;

      // 측정/원인 기록은 사용자의 server_id가 필요하므로 사용자부터
      await _syncUsers();
      await _syncMeasurements();
      await _syncCauses();
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncUsers() async {
    final dao = UserDao();
    final pending = await dao.getUnsynced();
    for (final user in pending) {
      String? serverId = await SharedApiService.instance.createUser(
        name: user.name,
        phone: user.phone,
        birthYear: user.birthYear,
        birthMonth: user.birthMonth,
        gender: user.gender,
        region: user.region,
        faceDescriptor: user.faceDescriptor,
      );

      // 생성 실패 시 동명 사용자가 이미 서버에 있는지 확인해서 연결
      if (serverId == null) {
        final existing =
            await SharedApiService.instance.findUserByName(user.name);
        serverId = existing?['user_id'] as String?;
        // 기존 서버 사용자에 연결된 경우, 보존해둔 얼굴 임베딩도 올려준다
        if (serverId != null && user.faceDescriptor != null) {
          await SharedApiService.instance
              .updateFaceDescriptor(serverId, user.faceDescriptor!);
        }
      }

      if (serverId != null) {
        await dao.update(user.copyWith(serverId: serverId));
        print('[SyncService] 사용자 동기화 완료: ${user.name} → $serverId');
        // 로그인 중인 사용자라면 세션도 갱신 (이후 저장이 바로 서버로 가도록)
        if (UserSession.instance.currentUser?.id == user.id) {
          await UserSession.instance.refreshCurrentUser();
        }
      }
    }
  }

  Future<void> _syncMeasurements() async {
    final dao = MeasurementDao();
    final pending = await dao.getUnsynced();
    for (final record in pending) {
      final serverId = await _serverIdOf(record.userId);
      if (serverId == null) continue; // 사용자 동기화 전이면 다음 기회에

      final ok = await SharedApiService.instance.saveSession(serverId, {
        'timestamp': record.measuredAt.toIso8601String(),
        'type': 'hrv_measurement',
        'heart_rate': record.heartRate,
        'hrv': record.hrv,
        'stress_index': record.stressIndex,
        'stress_level': record.stressLevel,
        'hrv_level': record.hrvLevel,
        'measurement_duration': record.measurementDuration,
        'rr_intervals': record.rrIntervals,
      });
      if (ok && record.id != null) {
        await dao.markSynced(record.id!);
        print('[SyncService] 측정 기록 동기화 완료: id=${record.id}');
      }
    }
  }

  Future<void> _syncCauses() async {
    final dao = CauseDao();
    final pending = await dao.getUnsynced();
    for (final record in pending) {
      final serverId = await _serverIdOf(record.userId);
      if (serverId == null) continue;

      final ok = await SharedApiService.instance.saveCause(
        serverId,
        symptom: record.symptom,
        cause: record.cause,
        sessionId: record.measurementId,
        recordedAt: record.recordedAt.toIso8601String(),
      );
      if (ok && record.id != null) {
        await dao.markSynced(record.id!);
        print('[SyncService] 원인 기록 동기화 완료: id=${record.id}');
      }
    }
  }

  final Map<int, String?> _serverIdCache = {};

  Future<String?> _serverIdOf(int? localUserId) async {
    if (localUserId == null) return null;
    if (_serverIdCache.containsKey(localUserId)) {
      final cached = _serverIdCache[localUserId];
      if (cached != null) return cached;
    }
    final User? user = await UserDao().getById(localUserId);
    final serverId = user?.serverId;
    _serverIdCache[localUserId] = serverId;
    return serverId;
  }
}
