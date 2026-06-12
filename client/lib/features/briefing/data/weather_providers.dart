import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/features/briefing/data/weather_cache.dart';
import 'package:weather_friend/features/briefing/data/weather_facade.dart';
import 'package:weather_friend/features/location/data/selected_city_provider.dart';

class WeatherBundleNotifier extends AsyncNotifier<WeatherBundle> {
  bool _refreshing = false;

  @override
  Future<WeatherBundle> build() async {
    final city = ref.watch(selectedCityProvider);
    final date = todayKstIso();
    final cached = ref
        .read(weatherCacheProvider)
        .read(cityId: city.cityId, date: date);

    if (cached != null) {
      unawaited(
        Future<void>.microtask(
          () => _refresh(cityId: city.cityId, date: date, silent: true),
        ),
      );
      return cached;
    }

    return _fetchAndCache(cityId: city.cityId, date: date);
  }

  Future<void> refresh() async {
    final city = ref.read(selectedCityProvider);
    await _refresh(cityId: city.cityId, date: todayKstIso(), silent: false);
  }

  Future<void> _refresh({
    required String cityId,
    required String date,
    required bool silent,
  }) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final fresh = await _fetchAndCache(cityId: cityId, date: date);
      if (ref.read(selectedCityProvider).cityId == cityId) {
        state = AsyncData(fresh);
      }
    } catch (error, stackTrace) {
      if (!silent && state is! AsyncData<WeatherBundle>) {
        state = AsyncError(error, stackTrace);
      } else {
        debugPrint('[weather_cache] refresh failed, keeping cache: $error');
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<WeatherBundle> _fetchAndCache({
    required String cityId,
    required String date,
  }) async {
    final bundle = await ref
        .read(weatherFacadeProvider)
        .fetchBundle(city: cityId);
    await ref
        .read(weatherCacheProvider)
        .write(cityId: cityId, date: date, bundle: bundle);
    return bundle;
  }
}

final weatherBundleProvider =
    AsyncNotifierProvider<WeatherBundleNotifier, WeatherBundle>(
      WeatherBundleNotifier.new,
    );

final todayHourlyWeatherProvider =
    Provider<AsyncValue<Map<int, HourlyWeather>>>(
      (ref) =>
          ref.watch(weatherBundleProvider).whenData((bundle) => bundle.today),
    );

final todayDailySummaryProvider = Provider<AsyncValue<DailySummary?>>(
  (ref) => ref
      .watch(weatherBundleProvider)
      .whenData((bundle) => bundle.todaySummary),
);

final yesterdayDailySummaryProvider = Provider<AsyncValue<DailySummary?>>(
  (ref) => ref
      .watch(weatherBundleProvider)
      .whenData((bundle) => bundle.yesterdaySummary),
);

final weekDaysProvider = Provider<AsyncValue<List<WeekDay>>>(
  (ref) =>
      ref.watch(weatherBundleProvider).whenData((bundle) => bundle.weekDays),
);

final todaySunriseSunsetProvider = Provider<AsyncValue<(DateTime?, DateTime?)>>(
  (ref) => ref
      .watch(weatherBundleProvider)
      .whenData((bundle) => (bundle.sunriseToday, bundle.sunsetToday)),
);
