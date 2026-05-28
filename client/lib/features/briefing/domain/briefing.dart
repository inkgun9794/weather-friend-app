import 'package:freezed_annotation/freezed_annotation.dart';

part 'briefing.freezed.dart';
part 'briefing.g.dart';

enum BriefingType {
  @JsonValue('morning')
  morning,
  @JsonValue('evening')
  evening,
  @JsonValue('hourly')
  hourly,
  @JsonValue('casual')
  casual,
}

@freezed
abstract class WeatherSnapshot with _$WeatherSnapshot {
  const factory WeatherSnapshot({
    @JsonKey(name: 'temperature_c') required double temperatureC,
    @JsonKey(name: 'feels_like_c') required double feelsLikeC,
    required String condition,
    @JsonKey(name: 'precipitation_prob') required int precipitationProb,
    @JsonKey(name: 'wind_speed_kmh') required double windSpeedKmh,
    required int humidity,
    int? pm10,
  }) = _WeatherSnapshot;

  factory WeatherSnapshot.fromJson(Map<String, Object?> json) =>
      _$WeatherSnapshotFromJson(json);
}

@freezed
abstract class Briefing with _$Briefing {
  const factory Briefing({
    required String city,
    required String date,
    required int hour,
    @JsonKey(name: 'character_id') required String characterId,
    required BriefingType type,
    required String transcript,
    @JsonKey(name: 'voice_script') String? voiceScript,
    @JsonKey(name: 'audio_url') String? audioUrl,
    // casual 타입은 날씨 데이터 없음 — nullable 처리.
    @JsonKey(name: 'weather_snapshot') WeatherSnapshot? weatherSnapshot,
  }) = _Briefing;

  factory Briefing.fromJson(Map<String, Object?> json) =>
      _$BriefingFromJson(json);
}

String briefingDocId({
  required String city,
  required String date,
  required int hour,
  required String characterId,
}) => '${city}_${date}_${hour.toString().padLeft(2, '0')}_$characterId';
