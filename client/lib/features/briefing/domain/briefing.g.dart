// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'briefing.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WeatherSnapshot _$WeatherSnapshotFromJson(Map<String, dynamic> json) =>
    _WeatherSnapshot(
      temperatureC: (json['temperature_c'] as num).toDouble(),
      feelsLikeC: (json['feels_like_c'] as num).toDouble(),
      condition: json['condition'] as String,
      precipitationProb: (json['precipitation_prob'] as num).toInt(),
      windSpeedKmh: (json['wind_speed_kmh'] as num).toDouble(),
      humidity: (json['humidity'] as num).toInt(),
      pm10: (json['pm10'] as num?)?.toInt(),
    );

Map<String, dynamic> _$WeatherSnapshotToJson(_WeatherSnapshot instance) =>
    <String, dynamic>{
      'temperature_c': instance.temperatureC,
      'feels_like_c': instance.feelsLikeC,
      'condition': instance.condition,
      'precipitation_prob': instance.precipitationProb,
      'wind_speed_kmh': instance.windSpeedKmh,
      'humidity': instance.humidity,
      'pm10': instance.pm10,
    };

_Briefing _$BriefingFromJson(Map<String, dynamic> json) => _Briefing(
  city: json['city'] as String,
  date: json['date'] as String,
  hour: (json['hour'] as num).toInt(),
  characterId: json['character_id'] as String,
  type: $enumDecode(_$BriefingTypeEnumMap, json['type']),
  transcript: json['transcript'] as String,
  voiceScript: json['voice_script'] as String?,
  audioUrl: json['audio_url'] as String?,
  weatherSnapshot: WeatherSnapshot.fromJson(
    json['weather_snapshot'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$BriefingToJson(_Briefing instance) => <String, dynamic>{
  'city': instance.city,
  'date': instance.date,
  'hour': instance.hour,
  'character_id': instance.characterId,
  'type': _$BriefingTypeEnumMap[instance.type]!,
  'transcript': instance.transcript,
  'voice_script': instance.voiceScript,
  'audio_url': instance.audioUrl,
  'weather_snapshot': instance.weatherSnapshot,
};

const _$BriefingTypeEnumMap = {
  BriefingType.morning: 'morning',
  BriefingType.evening: 'evening',
  BriefingType.hourly: 'hourly',
};
