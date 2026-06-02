import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/app/app.dart';
import 'package:weather_friend/core/services/fcm_service.dart';
import 'package:weather_friend/core/services/notification_service.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_screen.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/features/location/data/onboarding_provider.dart';

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

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService();
  @override
  Future<void> init() async {}
  @override
  Future<bool> hasPermission() async => false;
  @override
  Future<bool> requestPermissions() async => false;
  @override
  Future<void> scheduleDaily({
    required BriefingSlot slot,
    required String title,
    required String body,
  }) async {}
  @override
  Future<void> cancelSlot(BriefingSlot slot) async {}
  @override
  Future<void> cancelAllSlots() async {}
  @override
  Future<void> showTestNotification({String? body}) async {}
}

void main() {
  testWidgets('app boots and shows briefing screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          fcmServiceProvider.overrideWithValue(_FakeFcmService(prefs)),
          notificationServiceProvider.overrideWithValue(
            _FakeNotificationService(),
          ),
          onboardingCompleteProvider.overrideWith(_FakeOnboardingComplete.new),
          // pumpAndSettle이 hang하지 않게 stream을 한 번만 emit.
          kstDateProvider.overrideWith((ref) => Stream.value('2026-05-23')),
          kstHourProvider.overrideWith((ref) => Stream.value(12)),
          todayBriefingsProvider.overrideWith(
            (ref) => Future.value(<int, Briefing>{}),
          ),
          todayHourlyWeatherProvider.overrideWith(
            (ref) => Future.value(<int, HourlyWeather>{}),
          ),
          todayDailySummaryProvider.overrideWith((ref) => Future.value(null)),
          weekDaysProvider.overrideWith(
            (ref) => Future.value(const <WeekDay>[]),
          ),
        ],
        child: const WeatherFriendApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BriefingScreen), findsOneWidget);
  });
}
