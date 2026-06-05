import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/briefing/presentation/current_weather_display.dart';

void main() {
  const briefing = Briefing(
    city: 'seoul',
    date: '2026-06-05',
    hour: 6,
    characterId: 'jiyoung',
    type: BriefingType.morning,
    transcript: 'morning',
    weatherSnapshot: WeatherSnapshot(
      temperatureC: 16,
      feelsLikeC: 16,
      condition: '맑음',
      precipitationProb: 2,
      windSpeedKmh: 1,
      humidity: 87,
    ),
  );

  test('current hourly values win over a briefing snapshot', () {
    const hourly = HourlyWeather(
      hour: 16,
      temperatureC: 28,
      feelsLikeC: 29,
      condition: '구름 조금',
      precipitationProb: 10,
      humidity: 55,
    );

    final display = resolveCurrentWeatherDisplay(
      hourly: hourly,
      exactBriefing: briefing,
    );

    expect(display.temperatureC, 28);
    expect(display.feelsLikeC, 29);
    expect(display.condition, '구름 조금');
    expect(display.precipitationProb, 10);
    expect(display.humidity, 55);
  });

  test(
    'same-hour briefing is used only when hourly weather is unavailable',
    () {
      final display = resolveCurrentWeatherDisplay(
        hourly: null,
        exactBriefing: briefing,
      );

      expect(display.temperatureC, 16);
      expect(display.feelsLikeC, 16);
      expect(display.humidity, 87);
    },
  );
}
