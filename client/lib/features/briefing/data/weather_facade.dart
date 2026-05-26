import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/features/briefing/data/firestore_weather_source.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart'
    show WeatherBundle;
import 'package:weather_friend/features/briefing/data/open_meteo_weather_source.dart';
import 'package:weather_friend/features/briefing/data/weather_source.dart';

/// 두 [WeatherSource]를 KMA → OpenMeteo 순으로 시도.
///
/// - KMA (Firestore 캐시) 가 우선. 캐시 미스/오류 시 OpenMeteo로 폴백.
/// - 폴백 발생 시 로그 남김 (관측·디버깅용).
class WeatherFacade {
  WeatherFacade({required this.primary, required this.fallback});

  final WeatherSource primary;
  final WeatherSource fallback;

  Future<WeatherBundle> fetchBundle({String city = 'seoul'}) async {
    try {
      final result = await primary.fetchBundle(city: city);
      debugPrint('[weather_facade] ✅ source=${primary.id}');
      return result;
    } catch (e) {
      debugPrint('[weather_facade] ⚠️ ${primary.id} failed: $e');
      final result = await fallback.fetchBundle(city: city);
      debugPrint('[weather_facade] ↩️ source=${fallback.id} (fallback)');
      return result;
    }
  }
}

final weatherFacadeProvider = Provider<WeatherFacade>((ref) {
  return WeatherFacade(
    primary: ref.watch(firestoreWeatherSourceProvider),
    fallback: ref.watch(openMeteoWeatherSourceProvider),
  );
});
