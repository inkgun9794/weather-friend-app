import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WeatherCity {
  const WeatherCity({
    required this.cityId,
    required this.label,
    required this.lat,
    required this.lon,
    required this.shortNx,
    required this.shortNy,
    required this.midLandRegId,
    required this.midTempRegId,
  });

  static const seoulCityId = '1100000000';

  static const seoul = WeatherCity(
    cityId: seoulCityId,
    label: '서울',
    lat: 37.5635694444444,
    lon: 126.980008333333,
    shortNx: 60,
    shortNy: 127,
    midLandRegId: '11B00000',
    midTempRegId: '11B10101',
  );

  final String cityId;
  final String label;
  final double lat;
  final double lon;
  final int shortNx;
  final int shortNy;
  final String midLandRegId;
  final String midTempRegId;

  String get asosStnId => _asosStationByMidTempRegId[midTempRegId]!;

  /// Generated AI briefings still use the old Seoul slug. Other city IDs are
  /// future-compatible for when per-city briefings are enabled server-side.
  String get briefingCityKey => cityId == seoulCityId ? 'seoul' : cityId;

  factory WeatherCity.fromJson(Map<String, dynamic> json) {
    return WeatherCity(
      cityId: json['city_id'] as String,
      label: json['label'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      shortNx: (json['nx'] as num).toInt(),
      shortNy: (json['ny'] as num).toInt(),
      midLandRegId: json['mid_land_reg_id'] as String,
      midTempRegId: json['mid_temp_reg_id'] as String,
    );
  }
}

const _asosStationByMidTempRegId = {
  '11B10101': '108', // 서울
  '11B20201': '112', // 인천
  '11B20601': '119', // 수원
  '11C10301': '131', // 청주
  '11C20101': '129', // 서산
  '11C20401': '133', // 대전
  '11C20404': '239', // 세종
  '11D10301': '101', // 춘천
  '11D20501': '105', // 강릉
  '11F10201': '146', // 전주
  '11F20501': '156', // 광주
  '11G00201': '184', // 제주
  '11H10501': '136', // 안동
  '11H10701': '143', // 대구
  '11H20101': '152', // 울산
  '11H20201': '159', // 부산
  '11H20301': '155', // 창원
  '21F20801': '165', // 목포
};

class CityCatalog {
  CityCatalog._();

  static List<WeatherCity>? _cache;

  static Future<List<WeatherCity>> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString('assets/maps/cities_kma.json');
    final data = (json.decode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map(WeatherCity.fromJson)
        .toList(growable: false);
    _cache = data;
    return data;
  }

  static Future<WeatherCity> findById(String cityId) async {
    final cities = await load();
    return findByIdSync(cityId, cities: cities);
  }

  static WeatherCity findByIdSync(String cityId, {List<WeatherCity>? cities}) {
    final loaded = cities ?? _cache;
    if (loaded == null) return WeatherCity.seoul;
    for (final city in loaded) {
      if (city.cityId == cityId) return city;
    }
    return WeatherCity.seoul;
  }

  static Future<WeatherCity> nearest({
    required double lat,
    required double lon,
  }) async {
    final cities = await load();
    WeatherCity best = WeatherCity.seoul;
    var bestKm = double.infinity;
    for (final city in cities) {
      final km = _distanceKm(lat, lon, city.lat, city.lon);
      if (km < bestKm) {
        best = city;
        bestKm = km;
      }
    }
    return best;
  }

  static Future<WeatherCity?> matchAddress({
    String? administrativeArea,
    String? locality,
    String? subAdministrativeArea,
    String? subLocality,
  }) async {
    final admin = _normalizeRegion(administrativeArea);
    final local = _normalizePlace(locality);
    final subAdmin = _normalizePlace(subAdministrativeArea);
    final subLocal = _normalizePlace(subLocality);

    if ([
      admin,
      local,
      subAdmin,
      subLocal,
    ].any((p) => p.contains('서울') || p.contains('seoul'))) {
      return WeatherCity.seoul;
    }

    const metroLabels = {
      '부산': '부산',
      'busan': '부산',
      '대구': '대구',
      'daegu': '대구',
      '인천': '인천',
      'incheon': '인천',
      '광주': '광주',
      'gwangju': '광주',
      '대전': '대전',
      'daejeon': '대전',
      '울산': '울산',
      'ulsan': '울산',
      '세종': '세종',
      'sejong': '세종',
    };
    for (final entry in metroLabels.entries) {
      if ([
        admin,
        local,
        subAdmin,
        subLocal,
      ].any((p) => p.contains(entry.key))) {
        return findByLabel(entry.value);
      }
    }

    final candidates = <String>{
      '$admin$local$subLocal',
      '$admin$local',
      '$admin$subAdmin$subLocal',
      '$admin$subAdmin',
      '$admin$subLocal',
    }.where((s) => s.isNotEmpty).toList();

    final cities = await load();

    // 1) 정확 일치 우선 — 가장 구체적인 후보부터.
    for (final candidate in candidates) {
      for (final city in cities) {
        if (_normalizePlace(city.label) == candidate) return city;
      }
    }

    // 2) 접두 일치 — 한 후보가 여러 도시에 걸리면(예: "경기성남시" → 수정·중원·분당구)
    //    모호하므로 임의로 첫 항목을 고르지 않고 건너뛴다. caller가 nearest()로 폴백.
    for (final candidate in candidates) {
      final matches = cities
          .where((c) => _normalizePlace(c.label).startsWith(candidate))
          .toList();
      if (matches.length == 1) return matches.first;
    }

    return null;
  }

  static Future<WeatherCity?> findByLabel(String label) async {
    final normalized = _normalizePlace(label);
    final cities = await load();
    for (final city in cities) {
      if (_normalizePlace(city.label) == normalized) return city;
    }
    return null;
  }

  static double _distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthKm = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  static String _normalizePlace(String? value) {
    return (value ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('특별자치시', '')
        .replaceAll('특별자치도', '')
        .replaceAll('특별시', '')
        .replaceAll('광역시', '')
        .replaceAll('자치구', '구')
        .trim();
  }

  static String _normalizeRegion(String? value) {
    final normalized = _normalizePlace(value).replaceFirst(RegExp(r'도$'), '');
    return switch (normalized) {
      '경상남' => '경남',
      '경상북' => '경북',
      '전라남' => '전남',
      '전라북' => '전북',
      '충청남' => '충남',
      '충청북' => '충북',
      _ => normalized,
    };
  }
}

final cityCatalogProvider = FutureProvider<List<WeatherCity>>((ref) {
  return CityCatalog.load();
});
