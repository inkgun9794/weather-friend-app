import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 서울 자치구 1개 — 이름과 (CCTV 조회 중심으로 쓸) 폴리곤 bbox 중심 좌표.
class SeoulDistrict {
  const SeoulDistrict({
    required this.name,
    required this.lat,
    required this.lon,
  });

  final String name; // 예: '종로구'
  final double lat;
  final double lon;
}

/// 앱에 이미 번들된 전국 시군구 GeoJSON(`korea_municipalities.json`)에서
/// 서울 자치구(행정코드 접두사 `11`)만 뽑아 중심 좌표를 계산한다.
///
/// 별도 좌표 테이블을 하드코딩하지 않고 기존 자산을 재사용. 한 번 파싱 후 캐시.
class SeoulDistricts {
  SeoulDistricts._();

  static List<SeoulDistrict>? _cache;

  static Future<List<SeoulDistrict>> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(
      'assets/maps/korea_municipalities.json',
    );
    final fc = json.decode(raw) as Map<String, dynamic>;
    final features = (fc['features'] as List).cast<Map<String, dynamic>>();

    final out = <SeoulDistrict>[];
    for (final f in features) {
      final props = f['properties'] as Map<String, dynamic>?;
      final code = (props?['code'] ?? '').toString();
      final name = (props?['name'] ?? '').toString();
      if (name.isEmpty || !code.startsWith('11')) continue; // 서울 자치구만
      final center = _bboxCenter(f['geometry']);
      if (center == null) continue;
      out.add(SeoulDistrict(name: name, lat: center.$1, lon: center.$2));
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    _cache = out;
    return out;
  }

  /// Polygon/MultiPolygon 좌표를 재귀로 훑어 bbox 중심 (lat, lon) 반환.
  static (double, double)? _bboxCenter(dynamic geometry) {
    final coords = geometry is Map ? geometry['coordinates'] : null;
    if (coords == null) return null;

    var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0;
    var found = false;

    void visit(dynamic node) {
      if (node is! List) return;
      if (node.length >= 2 && node[0] is num && node[1] is num) {
        final lon = (node[0] as num).toDouble();
        final lat = (node[1] as num).toDouble();
        minLon = math.min(minLon, lon);
        maxLon = math.max(maxLon, lon);
        minLat = math.min(minLat, lat);
        maxLat = math.max(maxLat, lat);
        found = true;
      } else {
        for (final child in node) {
          visit(child);
        }
      }
    }

    visit(coords);
    if (!found) return null;
    return ((minLat + maxLat) / 2, (minLon + maxLon) / 2);
  }
}

final seoulDistrictsProvider = FutureProvider<List<SeoulDistrict>>((ref) {
  return SeoulDistricts.load();
});
