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
  _RecordingWeatherSource(this.id, {this.bundle});

  @override
  final String id;
  final WeatherBundle? bundle;

  final requestedCities = <String>[];

  @override
  Future<WeatherBundle> fetchBundle({
    String city = WeatherCity.seoulCityId,
  }) async {
    requestedCities.add(city);
    return bundle ??
        const WeatherBundle(today: {}, todaySummary: null, weekDays: []);
  }
}

void main() {
  test('weather cities resolve to KMA ASOS stations', () {
    expect(WeatherCity.seoul.asosStnId, '108');
  });

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
      yesterdaySummary: DailySummary(
        date: '2026-06-08',
        maxC: 24,
        minC: 16,
        condition: '구름 조금',
        precipitationProbMax: 20,
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
    expect(restored?.yesterdaySummary?.maxC, 24);
    expect(restored?.weekDays.single.afternoon.tempC, 26);

    expect(cache.read(cityId: '1100000000', date: '2026-06-10'), isNull);
  });

  test('temperature comparison describes warmer, cooler, and similar days', () {
    const yesterday = DailySummary(
      date: '2026-06-11',
      maxC: 24,
      minC: 16,
      condition: '맑음',
      precipitationProbMax: 0,
    );

    expect(
      temperatureComparisonLine(
        const DailySummary(
          date: '2026-06-12',
          maxC: 28,
          minC: 18,
          condition: '맑음',
          precipitationProbMax: 0,
        ),
        yesterday,
      ),
      '오늘은 어제보다 3도 높습니다.',
    );
    expect(
      temperatureComparisonLine(
        const DailySummary(
          date: '2026-06-12',
          maxC: 21,
          minC: 13,
          condition: '흐림',
          precipitationProbMax: 20,
        ),
        yesterday,
      ),
      '오늘은 어제보다 3도 낮습니다.',
    );
    expect(
      temperatureComparisonLine(
        const DailySummary(
          date: '2026-06-12',
          maxC: 25,
          minC: 16,
          condition: '맑음',
          precipitationProbMax: 0,
        ),
        yesterday,
      ),
      '오늘은 어제와 비슷합니다.',
    );
  });

  test('rain headline takes priority over temperature comparison', () {
    expect(
      temperatureComparisonLine(
        const DailySummary(
          date: '2026-06-12',
          maxC: 28,
          minC: 18,
          condition: '비',
          precipitationProbMax: 80,
        ),
        const DailySummary(
          date: '2026-06-11',
          maxC: 20,
          minC: 14,
          condition: '맑음',
          precipitationProbMax: 0,
        ),
      ),
      '오늘은 비가 옵니다.',
    );
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

  test('weather facade keeps the KMA observation for yesterday', () async {
    const kmaYesterday = DailySummary(
      date: '2026-06-11',
      maxC: 27,
      minC: 18,
      condition: '기상청 관측',
      precipitationProbMax: 0,
    );
    const openMeteoYesterday = DailySummary(
      date: '2026-06-11',
      maxC: 99,
      minC: 99,
      condition: 'fallback',
      precipitationProbMax: 0,
    );
    final facade = WeatherFacade(
      primary: _RecordingWeatherSource(
        'kma',
        bundle: const WeatherBundle(
          today: {},
          todaySummary: null,
          yesterdaySummary: kmaYesterday,
          weekDays: [],
        ),
      ),
      fallback: _RecordingWeatherSource(
        'open-meteo',
        bundle: const WeatherBundle(
          today: {},
          todaySummary: null,
          yesterdaySummary: openMeteoYesterday,
          weekDays: [],
        ),
      ),
    );

    final merged = await facade.fetchBundle();

    expect(merged.yesterdaySummary?.maxC, 27);
    expect(merged.yesterdaySummary?.condition, '기상청 관측');
  });

  test('weather facade fills missing KMA summaries from fallback', () async {
    const fallbackToday = DailySummary(
      date: '2026-06-12',
      maxC: 27,
      minC: 19,
      condition: '맑음',
      precipitationProbMax: 0,
    );
    const fallbackYesterday = DailySummary(
      date: '2026-06-11',
      maxC: 24,
      minC: 18,
      condition: '맑음',
      precipitationProbMax: 0,
    );
    final facade = WeatherFacade(
      primary: _RecordingWeatherSource(
        'kma',
        bundle: const WeatherBundle(
          today: {},
          todaySummary: null,
          weekDays: [],
        ),
      ),
      fallback: _RecordingWeatherSource(
        'open-meteo',
        bundle: const WeatherBundle(
          today: {},
          todaySummary: fallbackToday,
          yesterdaySummary: fallbackYesterday,
          weekDays: [],
        ),
      ),
    );

    final merged = await facade.fetchBundle();

    expect(merged.todaySummary, same(fallbackToday));
    expect(merged.yesterdaySummary, same(fallbackYesterday));
  });
}
