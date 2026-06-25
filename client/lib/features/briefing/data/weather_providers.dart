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
  DateTime? _lastFetchedAt;

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

  /// 앱 resume 시 호출용. 마지막 성공 fetch가 [minAge]보다 오래됐을 때만 갱신해
  /// 잠깐 앱을 나갔다 돌아온 경우의 헛 호출을 막는다. 아직 한 번도 못 받았으면(null) 갱신.
  Future<void> refreshIfStale({
    Duration minAge = const Duration(minutes: 15),
  }) async {
    final last = _lastFetchedAt;
    if (last != null && DateTime.now().difference(last) < minAge) return;
    await refresh();
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
    _lastFetchedAt = DateTime.now();
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
