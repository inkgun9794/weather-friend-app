import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:just_audio/just_audio.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:weather_friend/core/services/audio_player_service.dart';
import 'package:weather_friend/core/utils/kst.dart';

const _channelId = 'daily_briefing';
const _channelName = '하루 브리핑';
const _channelDescription = '오전 6시 알림';
const _playbackChannelId = 'briefing_audio_playback';
const _playbackChannelName = '음성 브리핑 재생';
const _playbackChannelDescription = '알림에서 시작한 음성 브리핑 재생 상태';
const _playbackNotificationId = 7001;

// 기록(다이어리) 리마인더 — 오후 7시까지 미작성 시 로컬 알림.
const _recordReminderChannelId = 'record_reminder';
const _recordReminderChannelName = '기록 리마인더';
const _recordReminderChannelDescription = '오후 7시까지 기록을 안 했을 때 알림';

/// 기록 리마인더 알림 본문 탭 → 기록 화면 라우팅 식별용 페이로드.
const recordReminderPayload = 'weather-friend://record';

const audioBriefingCategoryId = 'audio_briefing';
const playAudioActionId = 'play_audio';
const stopAudioActionId = 'stop_audio';
const _audioPagesBaseUrl = 'https://inkgun9794.github.io/weather-friend-app';
const _audioLocatorScheme = 'weather-friend';
const _audioLocatorHost = 'briefing-audio';

AudioPlayer? _notificationAudioPlayer;

@pragma('vm:entry-point')
void notificationActionBackgroundHandler(NotificationResponse response) {
  WidgetsFlutterBinding.ensureInitialized();
  if (response.actionId == playAudioActionId) {
    unawaited(_playNotificationAudio(response.payload));
  } else if (response.actionId == stopAudioActionId) {
    unawaited(_stopNotificationAudio());
  }
}

Future<void> _playNotificationAudio(String? payload) async {
  final audioUrl = resolveAudioNotificationPayload(
    payload,
    date: todayKstIso(),
  );
  if (audioUrl == null) return;

  final previous = _notificationAudioPlayer;
  if (previous != null) {
    await previous.stop();
  }

  final player = AudioPlayer();
  _notificationAudioPlayer = player;
  try {
    if (Platform.isAndroid) {
      await _startAndroidPlaybackService();
    }
    await configureSpeechAudioSession();
    await player.setUrl(audioUrl);
    await player.play();
  } catch (error, stackTrace) {
    debugPrint('Notification audio playback failed: $error\n$stackTrace');
  } finally {
    await player.dispose();
    if (identical(_notificationAudioPlayer, player)) {
      _notificationAudioPlayer = null;
      if (Platform.isAndroid) {
        await _stopAndroidPlaybackService();
      }
    }
  }
}

Future<void> _stopNotificationAudio() async {
  final player = _notificationAudioPlayer;
  _notificationAudioPlayer = null;
  await player?.stop();
  if (Platform.isAndroid) {
    await _stopAndroidPlaybackService();
  }
}

Future<void> _startAndroidPlaybackService() async {
  final android = FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await android?.startForegroundService(
    id: _playbackNotificationId,
    title: '날사친 음성 브리핑',
    body: '음성을 재생하고 있어요',
    notificationDetails: const AndroidNotificationDetails(
      _playbackChannelId,
      _playbackChannelName,
      channelDescription: _playbackChannelDescription,
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      onlyAlertOnce: true,
      ongoing: true,
      autoCancel: false,
      actions: [
        AndroidNotificationAction(
          stopAudioActionId,
          '재생 중지',
          showsUserInterface: false,
          cancelNotification: false,
        ),
      ],
    ),
    startType: AndroidServiceStartType.startNotSticky,
    foregroundServiceTypes: {
      AndroidServiceForegroundType.foregroundServiceTypeMediaPlayback,
    },
  );
}

Future<void> _stopAndroidPlaybackService() async {
  final android = FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await android?.stopForegroundService();
}

String briefingAudioNotificationPayload({
  required String city,
  required int hour,
  required String characterId,
}) {
  return Uri(
    scheme: _audioLocatorScheme,
    host: _audioLocatorHost,
    queryParameters: {
      'city': city,
      'hour': hour.toString(),
      'character': characterId,
    },
  ).toString();
}

String? resolveAudioNotificationPayload(
  String? payload, {
  required String date,
}) {
  if (payload == null || payload.isEmpty) return null;
  final uri = Uri.tryParse(payload);
  if (uri == null) return null;
  if ((uri.scheme == 'https' || uri.scheme == 'http') && uri.hasAuthority) {
    return payload;
  }
  if (uri.scheme != _audioLocatorScheme || uri.host != _audioLocatorHost) {
    return null;
  }

  final city = uri.queryParameters['city'];
  final hour = int.tryParse(uri.queryParameters['hour'] ?? '');
  final character = uri.queryParameters['character'];
  if (city == null ||
      city.isEmpty ||
      hour == null ||
      hour < 0 ||
      hour > 23 ||
      character == null ||
      character.isEmpty) {
    return null;
  }

  return '$_audioPagesBaseUrl/briefings/'
      '${Uri.encodeComponent(city)}/$date/'
      '${hour.toString().padLeft(2, '0')}/'
      '${Uri.encodeComponent(character)}.mp3';
}

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
  ),
  evening(
    id: 2,
    hour: 21,
    minute: 5,
    fallbackTitle: '저녁 브리핑',
    fallbackBody: '내일 날씨 브리핑이 준비됐어요',
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
  final StreamController<NotificationResponse> _responses =
      StreamController<NotificationResponse>.broadcast();
  bool _initialized = false;
  Future<void>? _initializing;
  NotificationResponse? _initialResponse;

  Stream<NotificationResponse> get responses => _responses.stream;

  NotificationResponse? takeInitialResponse() {
    final response = _initialResponse;
    _initialResponse = null;
    return response;
  }

  Future<void> init() {
    if (_initialized) return Future.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      tz_data.initializeTimeZones();
      try {
        final localName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localName));
      } catch (e) {
        debugPrint('NotificationService: timezone lookup failed: $e');
      }

      final settings = InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              audioBriefingCategoryId,
              actions: [
                DarwinNotificationAction.plain(playAudioActionId, '음성 재생'),
              ],
            ),
          ],
        ),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _responses.add,
        onDidReceiveBackgroundNotificationResponse:
            notificationActionBackgroundHandler,
      );
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        _initialResponse = launchDetails?.notificationResponse;
      }

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
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _recordReminderChannelId,
          _recordReminderChannelName,
          description: _recordReminderChannelDescription,
          importance: Importance.high,
        ),
      );

      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  /// iOS는 권한 요청을 FlutterLocalNotifications 경로로도 받을 수 있어야 함
  /// (FcmService 없이 NotificationService만 쓰는 우회 경로일 때).
  /// 내부적으로 OS 권한은 동일.
  Future<bool> requestPermissions() async {
    await init();
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
    await init();
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
    String? audioPayload,
  }) async {
    await init();
    await _plugin.cancel(id: slot.id);
    await _plugin.zonedSchedule(
      id: slot.id,
      title: title,
      body: body,
      scheduledDate: _nextOccurrence(slot.hour, slot.minute),
      notificationDetails: _briefingDetails(hasAudio: audioPayload != null),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: audioPayload,
    );
  }

  Future<void> showBriefingPush({
    required String title,
    required String body,
    required String audioUrl,
  }) async {
    await init();
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff),
      title: title,
      body: body,
      notificationDetails: _briefingDetails(hasAudio: true),
      payload: audioUrl,
    );
  }

  Future<void> cancelSlot(BriefingSlot slot) async {
    await init();
    await _plugin.cancel(id: slot.id);
  }

  Future<void> cancelAllSlots() async {
    await init();
    for (final slot in BriefingSlot.values) {
      await _plugin.cancel(id: slot.id);
    }
  }

  /// 디버그용: 즉시 알림 발사.
  Future<void> showTestNotification({String? body}) async {
    await init();
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

  Future<void> scheduleOneShot({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    await init();
    await _plugin.cancel(id: id);
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// 기록 리마인더 일회성 예약 — 본문 탭 시 [recordReminderPayload]로 라우팅.
  /// 오후 7시 ±수 분이면 충분하므로 inexact(절전 친화) 스케줄.
  Future<void> scheduleRecordReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    await init();
    await _plugin.cancel(id: id);
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _recordReminderChannelId,
          _recordReminderChannelName,
          channelDescription: _recordReminderChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: recordReminderPayload,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id: id);

  NotificationDetails _briefingDetails({required bool hasAudio}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        actions: hasAudio
            ? const [
                AndroidNotificationAction(
                  playAudioActionId,
                  '음성 재생',
                  showsUserInterface: false,
                  cancelNotification: true,
                ),
              ]
            : const [],
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: hasAudio ? audioBriefingCategoryId : null,
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
