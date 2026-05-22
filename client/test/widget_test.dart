import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/app/app.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_screen.dart';

void main() {
  testWidgets('app boots and shows briefing screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayBriefingsProvider.overrideWith(
            (ref) => Future.value(<int, Briefing>{}),
          ),
          todayHourlyWeatherProvider.overrideWith(
            (ref) => Future.value(<int, HourlyWeather>{}),
          ),
        ],
        child: const WeatherFriendApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BriefingScreen), findsOneWidget);
  });
}
