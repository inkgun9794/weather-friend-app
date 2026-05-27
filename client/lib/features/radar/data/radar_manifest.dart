import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// 한 슬라이더 포지션의 메타 — 'past'(=-60분) 또는 'current'(=0분).
/// PNG 자체는 GitHub Pages에서 [url]로 fetch.
class RadarFrame {
  const RadarFrame({
    required this.slot,
    required this.kind,
    required this.tm,
    required this.offsetMin,
    required this.url,
  });

  /// 'past' | 'current'
  final String slot;

  /// 'obs' (실측) | 'fcst' (외삽 예측)
  final String kind;

  /// YYYYMMDDHHmm (KST)
  final String tm;

  /// 분 단위 오프셋. -60 또는 양수.
  final int offsetMin;

  /// GitHub Pages public URL. base_tm을 ?v= 쿼리로 붙여 캐시 버스팅됨.
  final String url;

  bool get isObservation => kind == 'obs';

  factory RadarFrame.fromMap(Map<String, dynamic> m) => RadarFrame(
        slot: m['slot'] as String,
        kind: m['kind'] as String,
        tm: m['tm'] as String,
        offsetMin: (m['offset_min'] as num).toInt(),
        url: m['url'] as String,
      );
}

/// 'current' PNG의 원본 위경도 영역. 외삽 frame은 이걸 shift해서 그림.
class RadarBounds {
  const RadarBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  LatLngBounds toLatLngBounds() =>
      LatLngBounds(LatLng(south, west), LatLng(north, east));

  RadarBounds shifted({required double dlat, required double dlon}) =>
      RadarBounds(
        south: south + dlat,
        west: west + dlon,
        north: north + dlat,
        east: east + dlon,
      );

  factory RadarBounds.fromMap(Map<String, dynamic> m) => RadarBounds(
        south: (m['south'] as num).toDouble(),
        west: (m['west'] as num).toDouble(),
        north: (m['north'] as num).toDouble(),
        east: (m['east'] as num).toDouble(),
      );
}

/// 시간당 위경도 이동량.
class RadarMotionDeg {
  const RadarMotionDeg({required this.dlat, required this.dlon});
  final double dlat;
  final double dlon;

  factory RadarMotionDeg.fromMap(Map<String, dynamic> m) => RadarMotionDeg(
        dlat: (m['dlat'] as num).toDouble(),
        dlon: (m['dlon'] as num).toDouble(),
      );
}

/// manifest 1개 doc만 fetch — PNG는 [RadarFrame.url]로 NetworkImage가 알아서 받음.
class RadarState {
  const RadarState({
    required this.baseTm,
    required this.bounds,
    required this.motionDeg,
    required this.frames,
  });

  final String baseTm;
  final RadarBounds bounds;
  final RadarMotionDeg motionDeg;
  final List<RadarFrame> frames;

  RadarBounds boundsFor(RadarFrame f) {
    if (f.slot == 'current' && f.offsetMin != 0) {
      final hours = f.offsetMin / 60.0;
      return bounds.shifted(
        dlat: motionDeg.dlat * hours,
        dlon: motionDeg.dlon * hours,
      );
    }
    return bounds;
  }
}

final radarStateProvider = FutureProvider<RadarState?>((ref) async {
  final fs = FirebaseFirestore.instance;
  final doc = await fs.collection('kma_radar').doc('latest').get();
  if (!doc.exists) return null;
  final data = doc.data()!;

  final frames = ((data['frames'] as List?) ?? const [])
      .cast<Map<String, dynamic>>()
      .map(RadarFrame.fromMap)
      .toList()
    ..sort((a, b) => a.offsetMin.compareTo(b.offsetMin));

  final motionMap =
      (data['motion_per_hour_deg'] as Map<String, dynamic>? ?? const {});
  return RadarState(
    baseTm: data['base_tm'] as String,
    bounds: RadarBounds.fromMap(data['bounds'] as Map<String, dynamic>),
    motionDeg: RadarMotionDeg.fromMap(motionMap),
    frames: frames,
  );
});
