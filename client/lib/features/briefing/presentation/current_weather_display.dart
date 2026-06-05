import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';

class CurrentWeatherDisplay {
  const CurrentWeatherDisplay({
    this.temperatureC,
    this.feelsLikeC,
    this.condition,
    this.precipitationProb,
    this.humidity,
  });

  final double? temperatureC;
  final double? feelsLikeC;
  final String? condition;
  final int? precipitationProb;
  final int? humidity;
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
  );
}
