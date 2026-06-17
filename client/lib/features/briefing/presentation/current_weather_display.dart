import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';

class CurrentWeatherDisplay {
  const CurrentWeatherDisplay({
    this.temperatureC,
    this.feelsLikeC,
    this.condition,
    this.precipitationProb,
    this.humidity,
    this.uvIndex,
    this.pm10,
    this.pm25,
  });

  final double? temperatureC;
  final double? feelsLikeC;
  final String? condition;
  final int? precipitationProb;
  final int? humidity;
  final double? uvIndex;
  final int? pm10;
  final int? pm25;
}

/// Resolves values for the "지금" UI without borrowing stale weather from an
/// earlier briefing. The current hourly forecast is preferred, while a
/// briefing snapshot is only valid when it belongs to the exact current hour.
CurrentWeatherDisplay resolveCurrentWeatherDisplay({
  required HourlyWeather? hourly,
  required Briefing? exactBriefing,
}) {
  final exact = exactBriefing?.weatherSnapshot;
  return CurrentWeatherDisplay(
    temperatureC: hourly?.temperatureC ?? exact?.temperatureC,
    feelsLikeC: hourly?.feelsLikeC ?? exact?.feelsLikeC,
    condition: hourly?.condition ?? exact?.condition,
    precipitationProb: hourly?.precipitationProb ?? exact?.precipitationProb,
    humidity: hourly?.humidity ?? exact?.humidity,
    // UV/PM2.5는 hourly에서만 옴 (스냅샷엔 없음). PM10은 스냅샷에도 있어 폴백.
    uvIndex: hourly?.uvIndex,
    pm10: hourly?.pm10 ?? exact?.pm10,
    pm25: hourly?.pm25,
  );
}

/// 미세먼지(PM10) 한국어 등급 — 환경부 4단계 기준(μg/m³).
/// null이면 표시할 등급 없음(데이터 미수신).
String? pm10GradeKo(int? v) {
  if (v == null) return null;
  if (v <= 30) return '좋음';
  if (v <= 80) return '보통';
  if (v <= 150) return '나쁨';
  return '매우나쁨';
}

/// 자외선 지수 한국어 등급 — 기상청 5단계 기준.
/// null이면 표시할 등급 없음(데이터 미수신).
String? uvGradeKo(double? v) {
  if (v == null) return null;
  if (v < 3) return '낮음';
  if (v < 6) return '보통';
  if (v < 8) return '높음';
  if (v < 11) return '매우높음';
  return '위험';
}

/// 자외선 지수 표시 문자열 — "지수 등급"(예: "7 높음").
/// 기상청 표기 방식대로 지수를 정수로 반올림한 뒤 그 값으로 등급을 매겨,
/// 표시 숫자와 등급이 항상 같은 단계 안에 들도록 한다.
/// null이면 표시할 값 없음(데이터 미수신).
String? uvLabelKo(double? v) {
  if (v == null) return null;
  final idx = v.round();
  return '$idx ${uvGradeKo(idx.toDouble())}';
}
