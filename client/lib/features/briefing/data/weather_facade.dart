import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/features/briefing/data/firestore_weather_source.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart'
    show HourlyWeather, WeatherBundle;
import 'package:weather_friend/features/briefing/data/open_meteo_weather_source.dart';
import 'package:weather_friend/features/briefing/data/weather_source.dart';
import 'package:weather_friend/features/location/data/city_catalog.dart';

/// KMA + Open-Meteo 병행 호출 후 합쳐서 단일 [WeatherBundle] 반환.
///
/// 데이터 우선순위:
/// - 조건/기온/예보 = KMA (Firestore 캐시) 절대 우선
/// - 일출/일몰 / WMO weather_code (강도 보강) = Open-Meteo 보조
///   → KMA가 못 주는 데이터만 가져와 KMA 위에 덮어씀
///
/// KMA 실패 시 Open-Meteo만으로 fallback. Open-Meteo 실패 시 KMA만으로.
/// 둘 다 실패하면 예외 throw.
class WeatherFacade {
  WeatherFacade({required this.primary, required this.fallback});

  final WeatherSource primary; // KMA (Firestore)
  final WeatherSource fallback; // Open-Meteo

  Future<WeatherBundle> fetchBundle({
    String city = WeatherCity.seoulCityId,
  }) async {
    final sw = Stopwatch()..start();
    // 두 소스 병렬 호출 — KMA는 메인 데이터, Open-Meteo는 보조 (sunrise/sunset, weather_code)
    final results = await Future.wait([
      _timed(primary.id, () => primary.fetchBundle(city: city)),
      _timed(fallback.id, () => fallback.fetchBundle(city: city)),
    ]);
    final kma = results[0];
    final om = results[1];
    sw.stop();
    debugPrint('[weather_facade] ⏱ total ${sw.elapsedMilliseconds}ms');

    if (kma == null && om == null) {
      throw Exception('All weather sources failed (KMA + Open-Meteo)');
    }
    if (kma == null) {
      debugPrint('[weather_facade] ↩️ source=${fallback.id} only (KMA down)');
      return om!;
    }
    if (om == null) {
      debugPrint(
        '[weather_facade] ✅ source=${primary.id} only (Open-Meteo down)',
      );
      return kma;
    }

    // 둘 다 성공 — KMA 데이터 위에 Open-Meteo의 보조 데이터(일출/일몰, weather_code) 덮어씀.
    debugPrint('[weather_facade] ✅ KMA + Open-Meteo 병합');
    return _mergeKmaWithOpenMeteoAux(kma, om);
  }

  /// KMA bundle을 base로 두고 Open-Meteo에서 다음만 보강:
  /// - sunriseToday / sunsetToday (KMA는 안 줌)
  /// - 각 hourlyWeather의 weatherCode (강도 매핑용)
  WeatherBundle _mergeKmaWithOpenMeteoAux(WeatherBundle kma, WeatherBundle om) {
    // KMA의 hourly에 Open-Meteo의 weatherCode만 보강 (조건/기온은 KMA 유지)
    final mergedHourly = <int, HourlyWeather>{};
    kma.today.forEach((hour, kmaHour) {
      final omHour = om.today[hour];
      mergedHourly[hour] = HourlyWeather(
        hour: kmaHour.hour,
        temperatureC: kmaHour.temperatureC,
        condition: kmaHour.condition,
        precipitationProb: kmaHour.precipitationProb,
        // KMA 조건 유지. Open-Meteo의 weather_code만 가져와서 강도 보강용 (UI는 KMA condition 우선)
        weatherCode: omHour?.weatherCode,
      );
    });

    return WeatherBundle(
      today: mergedHourly,
      todaySummary: kma.todaySummary,
      weekDays: kma.weekDays,
      sunriseToday: om.sunriseToday,
      sunsetToday: om.sunsetToday,
      ultraShort: kma.ultraShort,
    );
  }
}

final weatherFacadeProvider = Provider<WeatherFacade>((ref) {
  return WeatherFacade(
    primary: ref.watch(firestoreWeatherSourceProvider),
    fallback: ref.watch(openMeteoWeatherSourceProvider),
  );
});

/// 단일 source fetch 시간 측정 + 에러는 null 반환.
Future<WeatherBundle?> _timed(
  String label,
  Future<WeatherBundle> Function() task,
) async {
  final sw = Stopwatch()..start();
  try {
    final result = await task();
    sw.stop();
    debugPrint('[weather_facade] ⏱ $label ${sw.elapsedMilliseconds}ms');
    return result;
  } catch (e) {
    sw.stop();
    debugPrint(
      '[weather_facade] ⚠️ $label failed (${sw.elapsedMilliseconds}ms): $e',
    );
    return null;
  }
}
