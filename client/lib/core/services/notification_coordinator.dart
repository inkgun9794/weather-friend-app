import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/app/router/app_router.dart';
import 'package:weather_friend/core/services/audio_player_service.dart';
import 'package:weather_friend/core/services/fcm_service.dart';
import 'package:weather_friend/core/services/notification_service.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/data/briefing_repository.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/features/location/data/onboarding_provider.dart';
import 'package:weather_friend/features/location/data/selected_city_provider.dart';

/// 플랫폼별 알림 전달 경로를 동기화.
///
/// Android: FCM 토픽 구독 — 서버가 audio 준비 후 push.
/// iOS (APNs Auth Key 발급 전): Firestore에서 오늘의 audio가 준비됐는지
///   확인해서 일회성 로컬 알림으로 우회. 준비 안 됐으면 알림 X.
/// iOS (APNs Auth Key 발급 후): [_isIosFcmReady] 플래그를 true로 바꾸면
///   Android와 동일한 FCM 경로로 자동 전환.
///
/// 트리거:
///  - 앱 시작 직후 (onboarding 완료 상태에서)
///  - 앱이 foreground로 돌아올 때
///  - 선택한 캐릭터가 바뀔 때
class NotificationCoordinator extends ConsumerStatefulWidget {
  const NotificationCoordinator({required this.child, super.key});

  final Widget child;

  /// APNs Auth Key가 Firebase Console에 업로드되면 true로 변경 → iOS도 FCM 경로 사용.
  /// (build flag로 빼고 싶으면 String.fromEnvironment 등으로 교체)
  static const bool _isIosFcmReady = false;

  @override
  ConsumerState<NotificationCoordinator> createState() =>
      _NotificationCoordinatorState();
}

class _NotificationCoordinatorState
    extends ConsumerState<NotificationCoordinator>
    with WidgetsBindingObserver {
  StreamSubscription<RemoteMessage>? _fcmForegroundSub;
  StreamSubscription<RemoteMessage>? _fcmOpenedSub;
  StreamSubscription<NotificationResponse>? _notificationResponseSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // FCM 포그라운드 메시지 도착 → 즉시 브리핑 invalidate.
    // (앱이 켜진 상태에서 6시 푸시 받으면 화면 자동 갱신.)
    final notifications = ref.read(notificationServiceProvider);
    _notificationResponseSub = notifications.responses.listen(
      _handleNotificationResponse,
    );

    _fcmForegroundSub = FirebaseMessaging.onMessage.listen((msg) async {
      if (!mounted) return;
      debugPrint('FCM foreground: ${msg.notification?.title}');
      final briefing = RemoteBriefingNotification.fromData(msg.data);
      if (briefing != null && !kIsWeb && Platform.isAndroid) {
        await notifications.showBriefingPush(
          title: briefing.title,
          body: briefing.body,
          audioUrl: briefing.audioUrl,
        );
      }
      ref.invalidate(todayBriefingsProvider);
    });
    _fcmOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedRemoteMessage,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _fcmForegroundSub?.cancel();
    _fcmOpenedSub?.cancel();
    _notificationResponseSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      // resume 시에도 브리핑 다시 fetch (background에서 도착한 메시지 반영).
      ref.invalidate(todayBriefingsProvider);
    }
  }

  bool get _usesFcm =>
      kIsWeb ||
      Platform.isAndroid ||
      (Platform.isIOS && NotificationCoordinator._isIosFcmReady);

  Future<void> _initialize() async {
    final notifications = ref.read(notificationServiceProvider);
    await notifications.init();
    final initialResponse = notifications.takeInitialResponse();
    if (initialResponse != null) {
      await _handleNotificationResponse(initialResponse);
    }

    try {
      final initialRemoteMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialRemoteMessage != null) {
        await _handleOpenedRemoteMessage(initialRemoteMessage);
      }
    } catch (e) {
      debugPrint('NotificationCoordinator: initial FCM message skipped: $e');
    }
    await _refresh();
  }

  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    // 음성 재생 액션.
    if (response.actionId == playAudioActionId) {
      final audioUrl = resolveAudioNotificationPayload(
        response.payload,
        date: todayKstIso(),
      );
      if (audioUrl != null) await _playAudio(audioUrl);
      return;
    }
    // 기록 리마인더 본문 탭 → 기록 화면으로 이동.
    if (response.payload == recordReminderPayload) {
      ref.read(appRouterProvider).go('/record');
    }
  }

  Future<void> _handleOpenedRemoteMessage(RemoteMessage message) async {
    final briefing = RemoteBriefingNotification.fromData(message.data);
    if (briefing == null) return;
    await _playAudio(briefing.audioUrl);
  }

  Future<void> _playAudio(String audioUrl) async {
    final playing = ref.read(currentlyPlayingProvider.notifier);
    playing.start(audioUrl);
    try {
      await ref.read(audioPlayerServiceProvider).playUrl(audioUrl);
    } catch (e) {
      playing.stop();
      debugPrint('NotificationCoordinator: audio playback failed: $e');
    }
  }

  Future<void> _refresh() async {
    if (!ref.read(onboardingCompleteProvider)) return;
    final character = ref.read(selectedCharacterProvider);
    final city = ref.read(selectedCityProvider);

    if (_usesFcm) {
      await ref
          .read(fcmServiceProvider)
          .syncSubscriptions(current: character, city: city.briefingCityKey);
    } else {
      await _syncIosLocalSchedules(character, city.briefingCityKey);
    }
  }

  /// iOS 우회 — 매일 [BriefingSlot.minute]분에 반복 발사되는 로컬 알림을 예약.
  ///
  /// 발사 시각은 6:05 — 워커 cron이 약간 늦어도 audio가 준비될 마진.
  /// 본문은 오늘 transcript가 Firestore에 있으면 그걸로, 없으면 fallback.
  /// (background에서 발사되므로 본문은 마지막 sync 시점 기준.)
  Future<void> _syncIosLocalSchedules(
    CharacterId character,
    String city,
  ) async {
    final notifications = ref.read(notificationServiceProvider);
    if (!await notifications.hasPermission()) return;

    final repo = ref.read(briefingRepositoryProvider);
    final date = todayKstIso();
    final displayName = Character.byId(character).displayName;

    for (final slot in BriefingSlot.values) {
      String body = slot.fallbackBody;
      try {
        final briefing = await repo.fetchOne(
          city: city,
          date: date,
          hour: slot.hour,
          characterId: character.name,
        );
        if (briefing != null && briefing.audioUrl != null) {
          body = briefing.transcript;
        }
      } catch (e) {
        debugPrint('NotificationCoordinator: $slot fetch failed: $e');
      }
      await notifications.scheduleDaily(
        slot: slot,
        title: displayName,
        body: body,
        audioPayload: briefingAudioNotificationPayload(
          city: city,
          hour: slot.hour,
          characterId: character.name,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CharacterId>(selectedCharacterProvider, (prev, next) {
      if (prev != next) _refresh();
    });
    ref.listen(selectedCityProvider, (prev, next) {
      if (prev?.cityId != next.cityId) _refresh();
    });
    ref.listen<bool>(onboardingCompleteProvider, (prev, next) {
      if (prev != true && next == true) _refresh();
    });
    return widget.child;
  }
}
