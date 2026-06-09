import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';
import 'package:weather_friend/features/location/data/city_catalog.dart';

const _kCityIdKey = 'selected_city_id';

/// 사용자가 온보딩 위치 단계에서 resolve한 KMA 지원 도시.
///
/// 위치 거부/실패 시 서울로 폴백. 도시 카탈로그는 main에서 미리 로드하므로
/// 저장된 도시를 첫 weather provider 평가 전에 동기로 복원한다.
class SelectedCityNotifier extends Notifier<WeatherCity> {
  @override
  WeatherCity build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getString(_kCityIdKey);
    if (saved == null || saved.isEmpty) return WeatherCity.seoul;
    return CityCatalog.findByIdSync(saved);
  }

  Future<void> set(WeatherCity city) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (state.cityId == city.cityId) {
      if (prefs.getString(_kCityIdKey) != city.cityId) {
        await prefs.setString(_kCityIdKey, city.cityId);
      }
      return;
    }
    await prefs.setString(_kCityIdKey, city.cityId);
    state = city;
  }

  Future<WeatherCity> setNearest({
    required double lat,
    required double lon,
  }) async {
    final city = await CityCatalog.nearest(lat: lat, lon: lon);
    await set(city);
    return city;
  }
}

final selectedCityProvider =
    NotifierProvider<SelectedCityNotifier, WeatherCity>(
      SelectedCityNotifier.new,
    );
