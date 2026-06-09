import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';
import 'package:weather_friend/features/character/domain/character.dart';

/// 토픽 명명 규칙은 worker/adapters/push_fcm.py의 `_topic_name`과 동일해야 함.
///     briefing-{city}-{slot}-{characterId}
const _slotMorning = 'morning';

/// 마지막으로 토픽 구독한 city/character. SharedPreferences 키.
const _kLastSubscribedTargetKey = 'fcm_last_subscribed_target';
const _kLegacyLastSubscribedCharacterKey = 'fcm_last_subscribed_character';

String _topicName({
  required String city,
  required String slot,
  required CharacterId character,
}) => 'briefing-$city-$slot-${character.name}';

/// FCM 푸시 구독/권한 관리.
///
/// 현재 정책은 오전 6시 음성 브리핑만 푸시한다. 사용자가 선택한 위치/캐릭터의
/// morning 토픽만 구독하고, 변경 시 이전 토픽은 unsubscribe.
class FcmService {
  FcmService(this._prefs);

  final SharedPreferences _prefs;
  // Firebase 미초기화 환경(테스트 등)에서 `instance` 접근이 throw하지 않도록 lazy.
  late final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;
  Future<void>? _initializing;

  Future<void> init() {
    if (_initialized) return Future.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      // iOS는 foreground에서도 알림 배너/사운드가 보이도록 명시적으로 활성화.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  /// 푸시 권한 요청. true = 허용됨.
  /// iOS는 명시적 요청 필요, Android 13+ 도 동일.
  Future<bool> requestPermissions() async {
    await init();
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<bool> hasPermission() async {
    await init();
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// 캐릭터/위치 변경/온보딩 완료 시 호출. 이전 구독을 정리하고 새 토픽 구독.
  ///
  /// 권한이 없으면 no-op. 같은 캐릭터로 다시 호출하면 no-op (idempotent).
  Future<void> syncSubscriptions({
    required CharacterId current,
    required String city,
  }) async {
    await init();
    if (!await hasPermission()) {
      debugPrint('FcmService: permission denied, skipping subscription');
      return;
    }

    final next = _SubscriptionTarget(city: city, character: current);
    final last = _readLastTarget();

    if (last == next) return; // 변경 없음

    if (last != null) {
      // 이전 토픽 해지. 실패해도 진행 — 다음 sync에서 또 시도.
      await _safeUnsubscribe(
        _topicName(
          city: last.city,
          slot: _slotMorning,
          character: last.character,
        ),
      );
      // 이전 버전은 evening도 구독했으므로 한 번 정리해 둔다.
      await _safeUnsubscribe(
        _topicName(city: last.city, slot: 'evening', character: last.character),
      );
    }

    await _safeSubscribe(
      _topicName(city: city, slot: _slotMorning, character: current),
    );

    await _prefs.setString(_kLastSubscribedTargetKey, next.encoded);
    await _prefs.remove(_kLegacyLastSubscribedCharacterKey);
  }

  /// 권한이 박탈됐거나 사용자가 해지한 경우. 저장된 구독을 모두 해지.
  Future<void> unsubscribeAll() async {
    await init();
    final last = _readLastTarget();
    if (last != null) {
      await _safeUnsubscribe(
        _topicName(
          city: last.city,
          slot: _slotMorning,
          character: last.character,
        ),
      );
      await _safeUnsubscribe(
        _topicName(city: last.city, slot: 'evening', character: last.character),
      );
    }
    await _prefs.remove(_kLastSubscribedTargetKey);
    await _prefs.remove(_kLegacyLastSubscribedCharacterKey);
  }

  _SubscriptionTarget? _readLastTarget() {
    final raw = _prefs.getString(_kLastSubscribedTargetKey);
    if (raw != null) return _SubscriptionTarget.decode(raw);

    final legacy = _prefs.getString(_kLegacyLastSubscribedCharacterKey);
    final legacyCharacter = legacy == null ? null : Character.parseId(legacy);
    if (legacyCharacter == null) return null;
    return _SubscriptionTarget(city: 'seoul', character: legacyCharacter);
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

class _SubscriptionTarget {
  const _SubscriptionTarget({required this.city, required this.character});

  final String city;
  final CharacterId character;

  String get encoded => '$city|${character.name}';

  static _SubscriptionTarget? decode(String raw) {
    final parts = raw.split('|');
    if (parts.length != 2) return null;
    final character = Character.parseId(parts[1]);
    if (character == null || parts[0].isEmpty) return null;
    return _SubscriptionTarget(city: parts[0], character: character);
  }

  @override
  bool operator ==(Object other) {
    return other is _SubscriptionTarget &&
        other.city == city &&
        other.character == character;
  }

  @override
  int get hashCode => Object.hash(city, character);
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(ref.watch(sharedPreferencesProvider));
});
