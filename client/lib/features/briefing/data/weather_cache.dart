import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';

const _weatherCacheVersion = 3;

class WeatherCache {
  WeatherCache(this._prefs);

  final SharedPreferences _prefs;

  String _key(String cityId) => 'weather_bundle_v$_weatherCacheVersion:$cityId';

  WeatherBundle? read({required String cityId, required String date}) {
    final raw = _prefs.getString(_key(cityId));
    if (raw == null) return null;

    try {
      final payload = json.decode(raw) as Map<String, dynamic>;
      if (payload['date'] != date) return null;
      return _bundleFromJson(payload['bundle'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> write({
    required String cityId,
    required String date,
    required WeatherBundle bundle,
  }) {
    return _prefs.setString(
      _key(cityId),
      json.encode({
        'date': date,
        'saved_at': DateTime.now().toIso8601String(),
        'bundle': _bundleToJson(bundle),
      }),
    );
  }
}

Map<String, dynamic> _bundleToJson(WeatherBundle bundle) {
  return {
    'today': {
      for (final entry in bundle.today.entries)
        entry.key.toString(): _hourToJson(entry.value),
    },
    'today_summary': bundle.todaySummary == null
        ? null
        : _dailyToJson(bundle.todaySummary!),
    'yesterday_summary': bundle.yesterdaySummary == null
        ? null
        : _dailyToJson(bundle.yesterdaySummary!),
    'week_days': bundle.weekDays.map(_weekDayToJson).toList(),
    'sunrise': bundle.sunriseToday?.toIso8601String(),
    'sunset': bundle.sunsetToday?.toIso8601String(),
    'ultra_short': bundle.ultraShort == null
        ? null
        : {
            'base_time': bundle.ultraShort!.baseTime.toIso8601String(),
            'hours': bundle.ultraShort!.hours.map(_hourToJson).toList(),
          },
  };
}

WeatherBundle _bundleFromJson(Map<String, dynamic> json) {
  final todayJson = json['today'] as Map<String, dynamic>;
  final summaryJson = json['today_summary'] as Map<String, dynamic>?;
  final yesterdaySummaryJson =
      json['yesterday_summary'] as Map<String, dynamic>?;
  final ultraJson = json['ultra_short'] as Map<String, dynamic>?;

  return WeatherBundle(
    today: {
      for (final entry in todayJson.entries)
        int.parse(entry.key): _hourFromJson(
          entry.value as Map<String, dynamic>,
        ),
    },
    todaySummary: summaryJson == null ? null : _dailyFromJson(summaryJson),
    yesterdaySummary: yesterdaySummaryJson == null
        ? null
        : _dailyFromJson(yesterdaySummaryJson),
    weekDays: (json['week_days'] as List)
        .cast<Map<String, dynamic>>()
        .map(_weekDayFromJson)
        .toList(growable: false),
    sunriseToday: DateTime.tryParse(json['sunrise'] as String? ?? ''),
    sunsetToday: DateTime.tryParse(json['sunset'] as String? ?? ''),
    ultraShort: ultraJson == null
        ? null
        : UltraShortForecast(
            baseTime: DateTime.parse(ultraJson['base_time'] as String),
            hours: (ultraJson['hours'] as List)
                .cast<Map<String, dynamic>>()
                .map(_hourFromJson)
                .toList(growable: false),
          ),
  );
}

Map<String, dynamic> _hourToJson(HourlyWeather value) {
  return {
    'hour': value.hour,
    'temperature_c': value.temperatureC,
    'feels_like_c': value.feelsLikeC,
    'condition': value.condition,
    'precipitation_prob': value.precipitationProb,
    'humidity': value.humidity,
    'weather_code': value.weatherCode,
    'uv_index': value.uvIndex,
    'pm10': value.pm10,
    'pm25': value.pm25,
  };
}

HourlyWeather _hourFromJson(Map<String, dynamic> json) {
  return HourlyWeather(
    hour: (json['hour'] as num).toInt(),
    temperatureC: (json['temperature_c'] as num).toDouble(),
    feelsLikeC: (json['feels_like_c'] as num?)?.toDouble(),
    condition: json['condition'] as String,
    precipitationProb: (json['precipitation_prob'] as num).toInt(),
    humidity: (json['humidity'] as num?)?.toInt(),
    weatherCode: (json['weather_code'] as num?)?.toInt(),
    uvIndex: (json['uv_index'] as num?)?.toDouble(),
    pm10: (json['pm10'] as num?)?.toInt(),
    pm25: (json['pm25'] as num?)?.toInt(),
  );
}

Map<String, dynamic> _dailyToJson(DailySummary value) {
  return {
    'date': value.date,
    'max_c': value.maxC,
    'min_c': value.minC,
    'condition': value.condition,
    'precipitation_prob_max': value.precipitationProbMax,
  };
}

DailySummary _dailyFromJson(Map<String, dynamic> json) {
  return DailySummary(
    date: json['date'] as String,
    maxC: (json['max_c'] as num).toDouble(),
    minC: (json['min_c'] as num).toDouble(),
    condition: json['condition'] as String,
    precipitationProbMax: (json['precipitation_prob_max'] as num).toInt(),
  );
}

Map<String, dynamic> _weekDayToJson(WeekDay value) {
  return {
    'date': value.date,
    'weekday': value.weekday,
    'morning': _dayPartToJson(value.morning),
    'afternoon': _dayPartToJson(value.afternoon),
    'evening': _dayPartToJson(value.evening),
  };
}

WeekDay _weekDayFromJson(Map<String, dynamic> json) {
  return WeekDay(
    date: json['date'] as String,
    weekday: (json['weekday'] as num).toInt(),
    morning: _dayPartFromJson(json['morning'] as Map<String, dynamic>),
    afternoon: _dayPartFromJson(json['afternoon'] as Map<String, dynamic>),
    evening: _dayPartFromJson(json['evening'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _dayPartToJson(DayPartSummary value) {
  return {'condition': value.condition, 'temp_c': value.tempC};
}

DayPartSummary _dayPartFromJson(Map<String, dynamic> json) {
  return DayPartSummary(
    condition: json['condition'] as String,
    tempC: (json['temp_c'] as num).toInt(),
  );
}

final weatherCacheProvider = Provider<WeatherCache>((ref) {
  return WeatherCache(ref.watch(sharedPreferencesProvider));
});
