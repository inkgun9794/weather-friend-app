import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/features/briefing/data/weather_cache.dart';

void main() {
  test('weather cache round-trips only for the requested date', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = WeatherCache(await SharedPreferences.getInstance());
    const bundle = WeatherBundle(
      today: {
        12: HourlyWeather(
          hour: 12,
          temperatureC: 24.5,
          feelsLikeC: 25.2,
          condition: '맑음',
          precipitationProb: 10,
          humidity: 55,
          weatherCode: 0,
        ),
      },
      todaySummary: DailySummary(
        date: '2026-06-09',
        maxC: 27,
        minC: 18,
        condition: '맑음',
        precipitationProbMax: 10,
      ),
      weekDays: [
        WeekDay(
          date: '2026-06-09',
          weekday: DateTime.tuesday,
          morning: DayPartSummary(condition: '맑음', tempC: 20),
          afternoon: DayPartSummary(condition: '맑음', tempC: 26),
          evening: DayPartSummary(condition: '구름많음', tempC: 22),
        ),
      ],
    );

    await cache.write(cityId: '1100000000', date: '2026-06-09', bundle: bundle);

    final restored = cache.read(cityId: '1100000000', date: '2026-06-09');
    expect(restored?.today[12]?.temperatureC, 24.5);
    expect(restored?.today[12]?.humidity, 55);
    expect(restored?.todaySummary?.maxC, 27);
    expect(restored?.weekDays.single.afternoon.tempC, 26);

    expect(cache.read(cityId: '1100000000', date: '2026-06-10'), isNull);
  });
}
