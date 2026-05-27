import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/features/radar/data/lambert.dart';

/// 시·군·구 한 곳의 outline. path는 **격자 좌표계** (1-based, float).
/// 화면에 그릴 때 viewport 따라 Matrix4로 transform.
class MunicipalityShape {
  const MunicipalityShape({required this.path});
  final Path path;
}

/// 한국 시·군·구 GeoJSON polygon 전체.
/// asset `korea_municipalities.json` (~1MB) 를 한 번만 parse + 캐시.
final koreaMunicipalitiesProvider =
    FutureProvider<List<MunicipalityShape>>((ref) async {
  ref.keepAlive();
  final raw = await rootBundle.loadString('assets/maps/korea_municipalities.json');
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return _parseFeatures(json);
});

List<MunicipalityShape> _parseFeatures(Map<String, dynamic> geo) {
  final out = <MunicipalityShape>[];
  final features = (geo['features'] as List).cast<Map<String, dynamic>>();
  for (final feature in features) {
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final type = geometry['type'] as String;
    final coords = geometry['coordinates'] as List;
    final path = Path();
    if (type == 'Polygon') {
      _addPolygon(path, coords);
    } else if (type == 'MultiPolygon') {
      for (final polygon in coords) {
        _addPolygon(path, polygon as List);
      }
    }
    out.add(MunicipalityShape(path: path));
  }
  return out;
}

/// GeoJSON Polygon = [outer_ring, hole1, hole2, ...]
/// 각 ring = [[lon, lat], [lon, lat], ...]
void _addPolygon(Path path, List polygon) {
  for (final ring in polygon) {
    final points = (ring as List);
    for (var i = 0; i < points.length; i++) {
      final pt = points[i] as List;
      final lon = (pt[0] as num).toDouble();
      final lat = (pt[1] as num).toDouble();
      final g = latLonToGridFloat(lat, lon);
      if (i == 0) {
        path.moveTo(g.nx, g.ny);
      } else {
        path.lineTo(g.nx, g.ny);
      }
    }
    path.close();
  }
}
