import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/features/briefing/data/weather_cache.dart';
import 'package:weather_friend/features/briefing/data/weather_facade.dart';
import 'package:weather_friend/features/briefing/data/weather_providers.dart';
import 'package:weather_friend/features/briefing/data/weather_source.dart';
import 'package:weather_friend/features/location/data/city_catalog.dart';
import 'package:weather_friend/features/location/data/selected_city_provider.dart';

class _RecordingWeatherSource implements WeatherSource {
  _RecordingWeatherSource(this.id);

  @override
  final String id;

  final requestedCities = <String>[];

  @override
  Future<WeatherBundle> fetchBundle({
    String city = WeatherCity.seoulCityId,
  }) async {
    requestedCities.add(city);
    return const WeatherBundle(today: {}, todaySummary: null, weekDays: []);
  }
}

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

  test('weather provider refetches when the selected city changes', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final primary = _RecordingWeatherSource('primary');
    final fallback = _RecordingWeatherSource('fallback');
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        weatherFacadeProvider.overrideWithValue(
          WeatherFacade(primary: primary, fallback: fallback),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(weatherBundleProvider.future);
    expect(primary.requestedCities, [WeatherCity.seoulCityId]);

    const busan = WeatherCity(
      cityId: '2600000000',
      label: '부산',
      lat: 35.1796,
      lon: 129.0756,
      shortNx: 98,
      shortNy: 76,
      midLandRegId: '11H20000',
      midTempRegId: '11H20201',
    );
    await container.read(selectedCityProvider.notifier).set(busan);
    await container.read(weatherBundleProvider.future);

    expect(primary.requestedCities, [WeatherCity.seoulCityId, busan.cityId]);
    expect(fallback.requestedCities, [WeatherCity.seoulCityId, busan.cityId]);
  });
}
