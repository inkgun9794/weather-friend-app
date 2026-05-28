import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// 4개 anchor 중 하나 — current(=0분 실측 레이더) 또는 forecast_Nh(=KMA 예보).
class RadarAnchor {
  const RadarAnchor({
    required this.slot,
    required this.kind,
    required this.anchorMin,
    required this.tm,
    required this.url,
    required this.bounds,
  });

  /// 'current' | 'forecast_2h' | 'forecast_4h' | 'forecast_6h'
  final String slot;

  /// 'obs' (실측) | 'fcst' (예보)
  final String kind;

  /// 이 anchor가 가리키는 시각 (분 단위, 0/120/240/360).
  final int anchorMin;

  /// 시각 라벨 — current는 YYYYMMDDHHmm (분 포함), forecast는 YYYYMMDDHH.
  final String tm;

  final String url;
  final RadarBounds bounds;

  bool get isObservation => kind == 'obs';

  factory RadarAnchor.fromMap(Map<String, dynamic> m) => RadarAnchor(
        slot: m['slot'] as String,
        kind: m['kind'] as String,
        anchorMin: (m['anchor_min'] as num).toInt(),
        tm: m['tm'] as String,
        url: m['url'] as String,
        bounds: RadarBounds.fromMap(m['bounds'] as Map<String, dynamic>),
      );
}

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

/// 시간당 위경도 이동량 — anchor 사이의 부드러운 motion shift용.
class RadarMotionDeg {
  const RadarMotionDeg({required this.dlat, required this.dlon});
  final double dlat;
  final double dlon;

  factory RadarMotionDeg.fromMap(Map<String, dynamic> m) => RadarMotionDeg(
        dlat: (m['dlat'] as num).toDouble(),
        dlon: (m['dlon'] as num).toDouble(),
      );
}

/// 데이터 종류 라벨용 — 슬라이더 포지션별로 셋 중 하나.
enum RadarKind {
  observation, // offset=0: 진짜 실측 레이더
  extrapolation, // offset>0 & anchor=current: 실측 + motion shift
  forecast, // anchor=forecast_Nh: KMA 예보
}

/// 슬라이더 한 포지션의 표시 정보 — 클라이언트가 anchor + motion으로 계산.
class RadarSliderFrame {
  const RadarSliderFrame({
    required this.offsetMin,
    required this.anchor,
    required this.bounds,
    required this.tm,
  });

  final int offsetMin; // 0 ~ 360
  final RadarAnchor anchor; // 어느 anchor의 PNG를 쓰는가
  final RadarBounds bounds; // motion shift 적용된 실제 bounds
  final String tm; // 이 슬라이더 포지션이 가리키는 절대시각 (YYYYMMDDHHmm)

  RadarKind get kind {
    if (offsetMin == 0 && anchor.isObservation) {
      return RadarKind.observation;
    }
    if (anchor.isObservation) {
      // current 앵커 + 음수가 아닌 offset → 실측을 motion으로 외삽
      return RadarKind.extrapolation;
    }
    return RadarKind.forecast;
  }
}

/// 전체 상태 — manifest + 클라이언트가 계산한 37 슬라이더 frame.
class RadarState {
  RadarState({
    required this.baseTm,
    required this.anchors,
    required this.motionDeg,
  }) : frames = _buildFrames(baseTm, anchors, motionDeg);

  final String baseTm; // YYYYMMDDHHmm — anchor 0(=current)의 시각
  final List<RadarAnchor> anchors;
  final RadarMotionDeg motionDeg;
  final List<RadarSliderFrame> frames; // 37 포지션 (0, 10, 20, ..., 360분)

  static List<RadarSliderFrame> _buildFrames(
    String baseTm,
    List<RadarAnchor> anchors,
    RadarMotionDeg motion,
  ) {
    if (anchors.isEmpty) return const [];
    // anchor를 시간순 정렬 + 슬라이더 0~360분.
    final sorted = [...anchors]
      ..sort((a, b) => a.anchorMin.compareTo(b.anchorMin));
    final base = _parseTm(baseTm);
    final out = <RadarSliderFrame>[];
    for (var off = 0; off <= 360; off += 10) {
      // off보다 작거나 같은 anchor 중 가장 가까운 것.
      RadarAnchor chosen = sorted.first;
      for (final a in sorted) {
        if (a.anchorMin <= off) {
          chosen = a;
        } else {
          break;
        }
      }
      // 그 anchor의 시각 기준으로 motion 적용.
      final deltaMin = off - chosen.anchorMin;
      final hours = deltaMin / 60.0;
      final bounds = chosen.bounds.shifted(
        dlat: motion.dlat * hours,
        dlon: motion.dlon * hours,
      );
      final tm = _formatTm(base.add(Duration(minutes: off)));
      out.add(RadarSliderFrame(
        offsetMin: off,
        anchor: chosen,
        bounds: bounds,
        tm: tm,
      ));
    }
    return out;
  }

  static DateTime _parseTm(String tm) {
    // YYYYMMDDHHmm
    return DateTime(
      int.parse(tm.substring(0, 4)),
      int.parse(tm.substring(4, 6)),
      int.parse(tm.substring(6, 8)),
      int.parse(tm.substring(8, 10)),
      int.parse(tm.substring(10, 12)),
    );
  }

  static String _formatTm(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}${two(t.hour)}${two(t.minute)}';
  }
}

final radarStateProvider = FutureProvider<RadarState?>((ref) async {
  final fs = FirebaseFirestore.instance;
  final doc = await fs.collection('kma_radar').doc('latest').get();
  if (!doc.exists) return null;
  final data = doc.data()!;

  final anchors = ((data['anchors'] as List?) ?? const [])
      .cast<Map<String, dynamic>>()
      .map(RadarAnchor.fromMap)
      .toList();
  if (anchors.isEmpty) return null;

  final motionMap =
      (data['motion_per_hour_deg'] as Map<String, dynamic>? ?? const {});
  return RadarState(
    baseTm: data['base_tm'] as String,
    anchors: anchors,
    motionDeg: RadarMotionDeg.fromMap(motionMap),
  );
});
