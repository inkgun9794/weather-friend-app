import 'package:weather_friend/features/briefing/data/open_meteo_client.dart'
    show WeatherBundle;
import 'package:weather_friend/features/location/data/city_catalog.dart';

/// 날씨 데이터 소스 추상화.
///
/// 구현체는 [OpenMeteoWeatherSource] (기본 폴백), 향후 [KmaWeatherSource]
/// (Firestore 캐시 기반) 등이 들어옴. UI/Provider 레이어는 이 인터페이스만 의존.
abstract class WeatherSource {
  /// 식별자 — 로깅·디버깅·UI 뱃지용. 예: 'open-meteo', 'kma'.
  String get id;

  /// KMA city id로 오늘 + 주간 번들 조회.
  Future<WeatherBundle> fetchBundle({String city = WeatherCity.seoulCityId});
}
