import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/features/briefing/data/weather_source.dart';

/// 기존 [OpenMeteoClient]를 [WeatherSource] 인터페이스로 감싸는 어댑터.
///
/// 현재는 폴백 경로(KMA 실패 시) 및 로컬 개발용 기본 소스.
class OpenMeteoWeatherSource implements WeatherSource {
  OpenMeteoWeatherSource(this._client);

  final OpenMeteoClient _client;

  @override
  String get id => 'open-meteo';

  @override
  Future<WeatherBundle> fetchBundle({String city = 'seoul'}) {
    return _client.fetchBundle(city: city);
  }
}

final openMeteoWeatherSourceProvider = Provider<WeatherSource>((ref) {
  final client = ref.watch(openMeteoClientProvider);
  return OpenMeteoWeatherSource(client);
});
