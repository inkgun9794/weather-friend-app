import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/app/app.dart';
import 'package:weather_friend/core/services/fcm_service.dart';
import 'package:weather_friend/core/services/notification_service.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/features/briefing/data/weather_providers.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_screen.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/features/location/data/onboarding_provider.dart';
import 'package:weather_friend/features/record/presentation/record_screen.dart';

/// 기록 리마인더 알림 탭 → /record 라우팅 와이어링 검증.
///
/// 실제 NotificationService/NotificationCoordinator/라우터를 쓰고
/// flutter_local_notifications의 메서드 채널만 모킹한다.
///  - 앱 실행 중 탭: 플랫폼이 didReceiveNotificationResponse를 보냄.
///  - 종료 상태 탭(cold start): getNotificationAppLaunchDetails가 응답을 돌려줌.
const _pluginChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

class _FakeOnboardingComplete extends OnboardingCompleteNotifier {
  @override
  bool build() => true;
}

class _FakeFcmService extends FcmService {
  _FakeFcmService(super._prefs);
  @override
  Future<void> init() async {}
  @override
  Future<bool> hasPermission() async => false;
  @override
  Future<bool> requestPermissions() async => false;
  @override
  Future<void> syncSubscriptions({
    required CharacterId current,
    required String city,
  }) async {}
  @override
  Future<void> unsubscribeAll() async {}
}

class _FakeTodayBriefings extends TodayBriefingsNotifier {
  @override
  Future<Map<int, Briefing>> build() async => const {};

  @override
  Future<void> refresh() async {}
}

Map<String, Object?> _launchDetails({required bool fromNotification}) => {
  'notificationLaunchedApp': fromNotification,
  if (fromNotification)
    'notificationResponse': {
      'notificationId': 4100,
      'actionId': null,
      'input': null,
      'notificationResponseType': 0,
      'payload': recordReminderPayload,
    },
};

void _mockPluginChannel(
  WidgetTester tester, {
  required bool launchedFromNotification,
}) {
  // 테스트에선 플러그인 등록이 없어 platform instance가 비어 있다.
  // 실 기기(Android)와 같은 코드 경로를 타도록 직접 등록한다.
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  // 모킹 없는 채널 호출은 widget test에서 영원히 완료되지 않아
  // NotificationService.init()이 멈춰버린다 — timezone 채널도 모킹.
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('flutter_timezone'),
    (call) async => 'Asia/Seoul',
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _pluginChannel,
    (call) async {
      switch (call.method) {
        case 'initialize':
          return true;
        case 'getNotificationAppLaunchDetails':
          return _launchDetails(fromNotification: launchedFromNotification);
        case 'areNotificationsEnabled':
          // 권한 없음 → RecordReminderCoordinator가 예약을 건너뛰어
          // 테스트가 Firestore(리마인더 본문)에 닿지 않는다.
          return false;
        default:
          return null;
      }
    },
  );
}

/// 플랫폼(네이티브)이 알림 탭을 전달했을 때를 재현.
Future<void> _simulateNotificationTap(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    _pluginChannel.name,
    const StandardMethodCodec().encodeMethodCall(
      const MethodCall('didReceiveNotificationResponse', {
        'notificationId': 4100,
        'actionId': null,
        'input': null,
        'payload': recordReminderPayload,
        'notificationResponseType': 0,
      }),
    ),
    (_) {},
  );
}

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        fcmServiceProvider.overrideWithValue(_FakeFcmService(prefs)),
        notificationServiceProvider.overrideWithValue(NotificationService()),
        onboardingCompleteProvider.overrideWith(_FakeOnboardingComplete.new),
        // pumpAndSettle이 hang하지 않게 stream을 한 번만 emit.
        kstDateProvider.overrideWith((ref) => Stream.value('2026-06-11')),
        kstHourProvider.overrideWith((ref) => Stream.value(12)),
        todayBriefingsProvider.overrideWith(_FakeTodayBriefings.new),
        todayHourlyWeatherProvider.overrideWith(
          (ref) => AsyncData({
            for (var hour = 0; hour < 24; hour++)
              hour: HourlyWeather(
                hour: hour,
                temperatureC: 20,
                condition: '맑음',
                precipitationProb: 0,
              ),
          }),
        ),
        todayDailySummaryProvider.overrideWith((ref) => const AsyncData(null)),
        todaySunriseSunsetProvider.overrideWith(
          (ref) => const AsyncData((null, null)),
        ),
        weekDaysProvider.overrideWith((ref) => const AsyncData(<WeekDay>[])),
      ],
      child: const WeatherFriendApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('앱 실행 중 기록 리마인더를 탭하면 기록 화면으로 이동한다', (tester) async {
    _mockPluginChannel(tester, launchedFromNotification: false);
    await _pumpApp(tester);
    expect(find.byType(BriefingScreen), findsOneWidget);

    await _simulateNotificationTap(tester);
    await tester.pumpAndSettle();

    expect(find.byType(RecordScreen), findsOneWidget);
  });

  testWidgets('종료 상태에서 기록 리마인더 탭으로 앱이 켜지면 기록 화면으로 이동한다', (tester) async {
    _mockPluginChannel(tester, launchedFromNotification: true);
    await _pumpApp(tester);

    expect(find.byType(RecordScreen), findsOneWidget);
  });

  testWidgets('알림 없이 일반 실행하면 브리핑 화면에 머문다', (tester) async {
    _mockPluginChannel(tester, launchedFromNotification: false);
    await _pumpApp(tester);

    expect(find.byType(BriefingScreen), findsOneWidget);
    expect(find.byType(RecordScreen), findsNothing);
  });
}
