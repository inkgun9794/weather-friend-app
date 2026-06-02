import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _channelId = 'daily_briefing';
const _channelName = '하루 브리핑';
const _channelDescription = '오전 6시 알림';

/// 하루 알람 슬롯 — 로컬 알림 ID·발사 시각·fallback 본문.
///
/// iOS 우회 경로(APNs Auth Key 발급 전)에서 사용. FCM이 활성화되면
/// Android와 iOS 모두 토픽 푸시로 전환되어 이 enum은 채널 식별용으로만 의미.
///
/// minute=5인 이유: GitHub Actions cron은 매 15분이고 가끔 dropped될 수
/// 있어서 5분 마진을 두면 워커가 audio 생성을 완료할 시간이 확보됨.
enum BriefingSlot {
  morning(
    id: 1,
    hour: 6,
    minute: 5,
    fallbackTitle: '아침 브리핑',
    fallbackBody: '오늘 날씨 브리핑이 준비됐어요',
  );

  const BriefingSlot({
    required this.id,
    required this.hour,
    required this.minute,
    required this.fallbackTitle,
    required this.fallbackBody,
  });

  final int id;
  final int hour;
  final int minute;
  final String fallbackTitle;
  final String fallbackBody;
}

/// 알림 채널/플러그인 초기화 + 로컬 알림 발사.
///
/// 두 가지 용도:
///   1. FCM 푸시가 표시될 Android 채널 사전 생성 + 테스트 알림.
///   2. iOS 우회 경로 — APNs Auth Key 없을 때 readiness 기반 일회성 스케줄링.
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
      debugPrint('NotificationService: timezone lookup failed: $e');
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
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

  /// iOS는 권한 요청을 FlutterLocalNotifications 경로로도 받을 수 있어야 함
  /// (FcmService 없이 NotificationService만 쓰는 우회 경로일 때).
  /// 내부적으로 OS 권한은 동일.
  Future<bool> requestPermissions() async {
    final iOS = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iOS != null) {
      return await iOS.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  Future<bool> hasPermission() async {
    final iOS = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iOS != null) {
      final opts = await iOS.checkPermissions();
      return opts?.isAlertEnabled ?? false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    return false;
  }

  /// 매일 [slot] 시각에 반복 발사되는 로컬 알림을 예약(덮어쓰기).
  ///
  /// OS가 알아서 매일 발사 — 앱이 background거나 종료돼 있어도 동작.
  /// 본문은 호출 시점 기준 최신값을 박아두고, 다음 foreground 진입 때
  /// transcript가 새로 채워졌으면 다시 호출해서 덮어쓴다.
  Future<void> scheduleDaily({
    required BriefingSlot slot,
    required String title,
    required String body,
  }) async {
    await _plugin.cancel(id: slot.id);
    await _plugin.zonedSchedule(
      id: slot.id,
      title: title,
      body: body,
      scheduledDate: _nextOccurrence(slot.hour, slot.minute),
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

  Future<void> cancelSlot(BriefingSlot slot) async {
    await _plugin.cancel(id: slot.id);
  }

  Future<void> cancelAllSlots() async {
    for (final slot in BriefingSlot.values) {
      await _plugin.cancel(id: slot.id);
    }
  }

  /// 디버그용: 즉시 알림 발사.
  Future<void> showTestNotification({String? body}) async {
    await _plugin.show(
      id: 999,
      title: '테스트 알림',
      body: body ?? '알림이 정상 작동합니다. 매일 오전 6시에 도착해요.',
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

  /// 다음 [hour]:[minute] 발사 시각 (기기 로컬). 오늘 그 시각이 지났으면 내일.
  tz.TZDateTime _nextOccurrence(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
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
