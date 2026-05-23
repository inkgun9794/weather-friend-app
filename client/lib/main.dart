import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/app/app.dart';
import 'package:weather_friend/core/services/notification_service.dart';
import 'package:weather_friend/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 로컬 알림 시스템 초기화 (timezone DB + 채널 생성).
  // 권한 요청은 온보딩 알림 단계에서 명시적으로 진행.
  final notifications = NotificationService();
  await notifications.init();

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const WeatherFriendApp(),
    ),
  );
}
