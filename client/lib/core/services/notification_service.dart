import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 알림 슬롯. 기기 로컬 시간 기준 고정 스케줄.
enum BriefingSlot {
  morning(id: 1, hour: 5, fallbackTitle: '아침 브리핑', fallbackBody: '오늘 날씨 브리핑이 준비됐어요'),
  evening(id: 2, hour: 21, fallbackTitle: '저녁 브리핑', fallbackBody: '오늘 하루 어땠어요? 내일 날씨 보러 가요');

  const BriefingSlot({
    required this.id,
    required this.hour,
    required this.fallbackTitle,
    required this.fallbackBody,
  });

  final int id;
  final int hour;
  final String fallbackTitle;
  final String fallbackBody;
}

const _channelId = 'daily_briefing';
const _channelName = '하루 브리핑';
const _channelDescription = '오전 5시 · 오후 9시 알림';

/// 로컬 알림 예약/취소/권한 관리.
///
/// 사용 패턴:
/// 1. 앱 시작 시 [init] 호출 (timezone DB 로드 + 기기 로컬 타임존 설정)
/// 2. 온보딩 알림 단계에서 [requestPermissions]
/// 3. 브리핑 데이터가 준비될 때마다 [scheduleDailyBriefings] 로 본문 갱신 + 재예약
class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (e) {
      // 기기 타임존을 못 얻으면 UTC fallback. 알림은 동작하지만 시각이 어긋날 수 있음.
      debugPrint('NotificationService: timezone lookup failed: $e');
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // 권한은 별도 단계에서 명시적으로 요청 — init 시점엔 묻지 않음.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);

    // Android 채널 생성 (idempotent)
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  /// 알림 권한 요청. true = 허용됨.
  Future<bool> requestPermissions() async {
    final iOS = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iOS != null) {
      return await iOS.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  /// 현재 권한 상태 (요청 없이).
  Future<bool> hasPermission() async {
    final iOS = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iOS != null) {
      final opts = await iOS.checkPermissions();
      return opts?.isAlertEnabled ?? false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    return false;
  }

  /// 두 슬롯(아침/저녁)을 본문과 함께 재예약.
  ///
  /// [bodies] 가 null이거나 비어 있으면 각 슬롯의 fallback 문구로 예약.
  /// 매일 같은 시각에 반복 (matchDateTimeComponents: DateTimeComponents.time).
  Future<void> scheduleDailyBriefings({
    Map<BriefingSlot, String>? bodies,
  }) async {
    for (final slot in BriefingSlot.values) {
      final body = bodies?[slot] ?? slot.fallbackBody;
      await _scheduleSlot(slot, body);
    }
  }

  Future<void> _scheduleSlot(BriefingSlot slot, String body) async {
    // 이전 예약 취소 후 다시 등록.
    await _plugin.cancel(id: slot.id);

    final scheduled = _nextOccurrence(slot.hour);
    await _plugin.zonedSchedule(
      id: slot.id,
      title: slot.fallbackTitle,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// 디버그용: 즉시 알림 발사.
  Future<void> showTestNotification({String? body}) async {
    await _plugin.show(
      id: 999,
      title: '테스트 알림',
      body: body ?? '알림이 정상 작동합니다. 매일 오전 5시·오후 9시에 도착해요.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// 다음 [hour]시 정각(기기 로컬). 이미 오늘 그 시각이 지났으면 내일.
  tz.TZDateTime _nextOccurrence(int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
