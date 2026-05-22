import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/app/app.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_screen.dart';
import 'package:weather_friend/features/location/data/onboarding_provider.dart';

class _FakeOnboardingComplete extends OnboardingCompleteNotifier {
  @override
  bool build() => true;
}

void main() {
  testWidgets('app boots and shows briefing screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
          tomorrowHourlyWeatherProvider.overrideWith(
            (ref) => Future.value(<int, HourlyWeather>{}),
          ),
          todayDailySummaryProvider.overrideWith((ref) => Future.value(null)),
          tomorrowDailySummaryProvider.overrideWith((ref) => Future.value(null)),
        ],
        child: const WeatherFriendApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BriefingScreen), findsOneWidget);
  });
}
