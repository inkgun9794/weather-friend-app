import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/app/app.dart';
import 'package:weather_friend/core/services/fcm_service.dart';
import 'package:weather_friend/core/services/notification_service.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';
import 'package:weather_friend/core/services/weather_widget_background.dart';
import 'package:weather_friend/features/location/data/city_catalog.dart';
import 'package:weather_friend/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  final briefing = RemoteBriefingNotification.fromData(message.data);
  if (briefing == null) return;
  await NotificationService().showBriefingPush(
    title: briefing.title,
    body: briefing.body,
    audioUrl: briefing.audioUrl,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final results = await Future.wait<Object>([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    SharedPreferences.getInstance(),
    CityCatalog.load(),
  ]);
  final prefs = results[1] as SharedPreferences;
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final notifications = NotificationService();
  final fcm = FcmService(prefs);

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
        sharedPreferencesProvider.overrideWithValue(prefs),
        fcmServiceProvider.overrideWithValue(fcm),
      ],
      child: const WeatherFriendApp(),
    ),
  );

  // 알림 플러그인 준비는 첫 화면 표시를 막을 이유가 없다. 각 서비스의 공개
  // 메서드도 init을 보장하므로 여기서는 warm-up만 백그라운드로 시작한다.
  unawaited(
    notifications.init().catchError((Object error, StackTrace stackTrace) {
      debugPrint('NotificationService warm-up failed: $error');
    }),
  );
  unawaited(
    fcm.init().catchError((Object error, StackTrace stackTrace) {
      debugPrint('FcmService warm-up failed: $error');
    }),
  );

  // 앱을 안 열어도 위젯이 주기적으로 최신 날씨를 받도록 백그라운드 태스크 등록.
  unawaited(
    initWeatherWidgetBackgroundRefresh().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      debugPrint('Weather widget bg refresh registration failed: $error');
    }),
  );
}
