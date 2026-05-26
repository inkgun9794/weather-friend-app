import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';
import 'package:weather_friend/features/character/domain/character.dart';

/// 토픽 명명 규칙은 worker/adapters/push_fcm.py의 `_topic_name`과 동일해야 함.
///     briefing-{city}-{slot}-{characterId}
const _topicCity = 'seoul'; // MVP: 단일 도시
const _slotMorning = 'morning';
const _slotEvening = 'evening';

/// 마지막으로 토픽 구독한 캐릭터 id. SharedPreferences 키.
/// `SelectedCharacterNotifier`는 영속화되지 않아 매 launch마다 jiyoung으로
/// 초기화되므로, FCM 토픽 구독은 별도로 추적해야 stale 구독 leak을 막을 수 있음.
const _kLastSubscribedCharacterKey = 'fcm_last_subscribed_character';

String _topicName({
  required String slot,
  required CharacterId character,
}) => 'briefing-$_topicCity-$slot-${character.name}';

/// FCM 푸시 구독/권한 관리.
///
/// 토픽은 캐릭터별 × 슬롯별로 분리되어 있다 (총 8 토픽). 사용자가 선택한
/// 캐릭터의 morning + evening 두 토픽만 구독한다. 캐릭터를 바꾸면 이전
/// 캐릭터의 두 토픽은 unsubscribe.
class FcmService {
  FcmService(this._prefs);

  final SharedPreferences _prefs;
  // Firebase 미초기화 환경(테스트 등)에서 `instance` 접근이 throw하지 않도록 lazy.
  late final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    // iOS는 foreground에서도 알림 배너/사운드가 보이도록 명시적으로 활성화.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    _initialized = true;
  }

  /// 푸시 권한 요청. true = 허용됨.
  /// iOS는 명시적 요청 필요, Android 13+ 도 동일.
  Future<bool> requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<bool> hasPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// 캐릭터 변경/온보딩 완료 시 호출. 이전 구독을 정리하고 새 토픽 2개 구독.
  ///
  /// 권한이 없으면 no-op. 같은 캐릭터로 다시 호출하면 no-op (idempotent).
  Future<void> syncSubscriptions(CharacterId current) async {
    if (!await hasPermission()) {
      debugPrint('FcmService: permission denied, skipping subscription');
      return;
    }

    final lastName = _prefs.getString(_kLastSubscribedCharacterKey);
    final last = lastName == null ? null : Character.parseId(lastName);

    if (last == current) return; // 변경 없음

    if (last != null) {
      // 이전 캐릭터 토픽 해지. 실패해도 진행 — 다음 sync에서 또 시도.
      await _safeUnsubscribe(_topicName(slot: _slotMorning, character: last));
      await _safeUnsubscribe(_topicName(slot: _slotEvening, character: last));
    }

    await _safeSubscribe(_topicName(slot: _slotMorning, character: current));
    await _safeSubscribe(_topicName(slot: _slotEvening, character: current));

    await _prefs.setString(_kLastSubscribedCharacterKey, current.name);
  }

  /// 권한이 박탈됐거나 사용자가 해지한 경우. 저장된 구독을 모두 해지.
  Future<void> unsubscribeAll() async {
    final lastName = _prefs.getString(_kLastSubscribedCharacterKey);
    final last = lastName == null ? null : Character.parseId(lastName);
    if (last != null) {
      await _safeUnsubscribe(_topicName(slot: _slotMorning, character: last));
      await _safeUnsubscribe(_topicName(slot: _slotEvening, character: last));
    }
    await _prefs.remove(_kLastSubscribedCharacterKey);
  }

  Future<void> _safeSubscribe(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('FcmService: subscribed to $topic');
    } catch (e) {
      debugPrint('FcmService: subscribe $topic failed: $e');
    }
  }

  Future<void> _safeUnsubscribe(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('FcmService: unsubscribed from $topic');
    } catch (e) {
      debugPrint('FcmService: unsubscribe $topic failed: $e');
    }
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(ref.watch(sharedPreferencesProvider));
});
