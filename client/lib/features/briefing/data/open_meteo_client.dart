import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Open-Meteo는 무료·무제한·인증 X. worker가 사용하는 것과 동일한 endpoint.
/// 클라이언트가 직접 호출해서 24h hourly 기온/날씨를 24-칩에 채움 — 메시지 없는
/// hour (수면 시간대 등)에도 weather가 보이게 하기 위함.

class HourlyWeather {
  const HourlyWeather({
    required this.hour,
    required this.temperatureC,
    required this.condition,
    required this.precipitationProb,
  });

  final int hour;
  final double temperatureC;
  final String condition;
  final int precipitationProb;
}

class TwoDayWeather {
  const TwoDayWeather({required this.today, required this.tomorrow});

  final Map<int, HourlyWeather> today;
  final Map<int, HourlyWeather> tomorrow;
}

// WMO weather code → 한국어. worker/adapters/weather_open_meteo.py와 정합.
const _weatherCodeKo = <int, String>{
  0: '맑음',
  1: '대체로 맑음',
  2: '구름 조금',
  3: '흐림',
  45: '안개',
  48: '짙은 안개',
  51: '약한 이슬비',
  53: '이슬비',
  55: '강한 이슬비',
  61: '약한 비',
  63: '비',
  65: '강한 비',
  71: '약한 눈',
  73: '눈',
  75: '강한 눈',
  77: '싸락눈',
  80: '소나기',
  81: '강한 소나기',
  82: '매우 강한 소나기',
  85: '약한 눈 소나기',
  86: '강한 눈 소나기',
  95: '천둥번개',
  96: '천둥번개 (우박)',
  99: '강한 천둥번개',
};

const _cityCoords = <String, (double, double)>{
  'seoul': (37.5665, 126.9780),
};

class OpenMeteoClient {
  OpenMeteoClient(this._http);

  final http.Client _http;

  /// 오늘 + 내일 48시간 hourly를 한 번에 받음. Open-Meteo는 forecast_days=2를
  /// 단일 GET으로 처리해서 API 한 번이면 끝.
  Future<TwoDayWeather> fetchTwoDays({String city = 'seoul'}) async {
    final coords = _cityCoords[city];
    if (coords == null) {
      throw ArgumentError('Unsupported city: $city');
    }
    final (lat, lng) = coords;

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toString(),
      'longitude': lng.toString(),
      'hourly': 'temperature_2m,precipitation_probability,weather_code',
      'timezone': 'Asia/Seoul',
      'forecast_days': '2',
    });

    final resp = await _http.get(uri).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw OpenMeteoException('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final data = json.decode(resp.body) as Map<String, dynamic>;
    final hourly = data['hourly'] as Map<String, dynamic>;
    final temps = (hourly['temperature_2m'] as List);
    final probs = (hourly['precipitation_probability'] as List);
    final codes = (hourly['weather_code'] as List);

    final today = <int, HourlyWeather>{};
    final tomorrow = <int, HourlyWeather>{};
    for (var h = 0; h < 24 && h < temps.length; h++) {
      today[h] = _snapshot(h, temps[h], probs[h], codes[h]);
    }
    for (var h = 0; h < 24 && (24 + h) < temps.length; h++) {
      tomorrow[h] = _snapshot(h, temps[24 + h], probs[24 + h], codes[24 + h]);
    }
    return TwoDayWeather(today: today, tomorrow: tomorrow);
  }

  HourlyWeather _snapshot(int hour, Object? temp, Object? prob, Object? code) {
    return HourlyWeather(
      hour: hour,
      temperatureC: (temp as num).toDouble(),
      condition: _weatherCodeKo[(code as num).toInt()] ?? '알 수 없음',
      precipitationProb: ((prob as num?) ?? 0).toInt(),
    );
  }
}

class OpenMeteoException implements Exception {
  OpenMeteoException(this.message);
  final String message;
  @override
  String toString() => 'OpenMeteoException: $message';
}

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final openMeteoClientProvider = Provider<OpenMeteoClient>((ref) {
  return OpenMeteoClient(ref.watch(httpClientProvider));
});

/// 단일 Open-Meteo 호출의 raw 결과 — 두 day provider가 같이 watch해서 cache 공유.
final twoDayWeatherProvider = FutureProvider<TwoDayWeather>((ref) async {
  final client = ref.watch(openMeteoClientProvider);
  return client.fetchTwoDays();
});

final todayHourlyWeatherProvider = FutureProvider<Map<int, HourlyWeather>>((ref) async {
  return (await ref.watch(twoDayWeatherProvider.future)).today;
});

final tomorrowHourlyWeatherProvider = FutureProvider<Map<int, HourlyWeather>>((ref) async {
  return (await ref.watch(twoDayWeatherProvider.future)).tomorrow;
});
