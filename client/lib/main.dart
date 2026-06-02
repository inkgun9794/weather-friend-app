import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/app/app.dart';
import 'package:weather_friend/core/services/fcm_service.dart';
import 'package:weather_friend/core/services/notification_service.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';
import 'package:weather_friend/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 알림 채널 생성 + timezone 초기화. 매일 6시 정기 알림은 FCM 토픽 푸시로 처리;
  // 이 서비스는 FCM 푸시가 표시될 Android 채널 사전 생성 + 테스트 알림 발사용.
  final notifications = NotificationService();
  await notifications.init();

  // SharedPreferences는 여기서 한 번만 await — Notifier들이 build()에서
  // 동기로 읽을 수 있게 override로 주입. 안 그러면 라우터가 prefs 로딩
  // 끝나기 전에 redirect 평가해서 온보딩 완료 사용자도 다시 온보딩으로 보내짐.
  final prefs = await SharedPreferences.getInstance();

  final fcm = FcmService(prefs);
  await fcm.init();

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
}
