import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// 7 anchor 중 하나 — current(=0분 실측 레이더) 또는 forecast_Nh(=KMA 매시 예보).
class RadarAnchor {
  const RadarAnchor({
    required this.slot,
    required this.kind,
    required this.anchorMin,
    required this.tm,
    required this.url,
    required this.bounds,
    this.motionFromPrev,
  });

  /// 'current' | 'forecast_1h' ~ 'forecast_6h'
  final String slot;

  /// 'obs' (실측) | 'fcst' (예보)
  final String kind;

  /// 이 anchor가 가리키는 시각 (분 단위, 0/60/120/.../360).
  final int anchorMin;

  /// 시각 라벨 — current는 YYYYMMDDHHmm (분 포함), forecast는 YYYYMMDDHH.
  final String tm;

  final String url;
  final RadarBounds bounds;

  /// 직전 anchor에서 이 anchor로 1시간 동안 비구름이 이동한 양 (lat/lon 도).
  /// motion-aware cross-fade의 방향 vector. null이면 ETA 추정 실패 or current anchor.
  final RadarMotionDeg? motionFromPrev;

  bool get isObservation => kind == 'obs';

  factory RadarAnchor.fromMap(Map<String, dynamic> m) {
    final motionMap = m['motion_from_prev_deg'] as Map<String, dynamic>?;
    return RadarAnchor(
      slot: m['slot'] as String,
      kind: m['kind'] as String,
      anchorMin: (m['anchor_min'] as num).toInt(),
      tm: m['tm'] as String,
      url: m['url'] as String,
      bounds: RadarBounds.fromMap(m['bounds'] as Map<String, dynamic>),
      motionFromPrev: motionMap != null ? RadarMotionDeg.fromMap(motionMap) : null,
    );
  }
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

  /// 빠진 키는 0으로 — 옛 manifest 호환 + 비 안 와서 motion 없는 경우 둘 다 안전.
  factory RadarMotionDeg.fromMap(Map<String, dynamic> m) => RadarMotionDeg(
        dlat: (m['dlat'] as num?)?.toDouble() ?? 0.0,
        dlon: (m['dlon'] as num?)?.toDouble() ?? 0.0,
      );
}

/// 데이터 종류 라벨용 — 슬라이더 포지션별로 셋 중 하나.
enum RadarKind {
  observation, // offset=0: 진짜 실측 레이더
  extrapolation, // offset>0 & anchor=current: 실측 + motion shift
  forecast, // anchor=forecast_Nh: KMA 예보
}

/// 슬라이더 한 포지션의 표시 정보 — 두 인접 anchor의 motion-aware cross-fade.
///
/// 슬라이더가 anchor 위면 blend=0, [next]는 null. 사이면 blend = 0~1로 opacity 가중치.
/// motion이 있으면 각 anchor의 bounds를 시간에 따라 점진 이동시켜 "그 자리 fade"가
/// 아니라 "흘러가며 morph" 되는 시각.
class RadarSliderFrame {
  const RadarSliderFrame({
    required this.offsetMin,
    required this.tm,
    required this.anchor,
    required this.anchorBounds,
    this.next,
    this.nextBounds,
    this.blend = 0.0,
  });

  final int offsetMin; // 0 ~ 360
  final String tm; // 이 슬라이더 포지션이 가리키는 절대시각 (YYYYMMDDHHmm)
  final RadarAnchor anchor; // primary (offset 이하 가장 가까운 anchor)
  final RadarBounds anchorBounds; // motion 적용 후 bounds (anchor를 forward shift)
  final RadarAnchor? next; // secondary (offset 초과 다음 anchor). null이면 정확히 anchor
  final RadarBounds? nextBounds; // motion 적용 후 bounds (next를 backward shift)
  final double blend; // 0.0 = pure anchor, 1.0 = pure next

  RadarKind get kind {
    if (offsetMin == 0 && anchor.isObservation) {
      return RadarKind.observation;
    }
    if (anchor.isObservation) {
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
  }) : frames = _buildFrames(baseTm, anchors);

  final String baseTm; // YYYYMMDDHHmm — anchor 0(=current)의 시각
  final List<RadarAnchor> anchors;
  final List<RadarSliderFrame> frames; // 37 포지션 (0, 10, 20, ..., 360분)

  static List<RadarSliderFrame> _buildFrames(
    String baseTm,
    List<RadarAnchor> anchors,
  ) {
    if (anchors.isEmpty) return const [];
    final sorted = [...anchors]
      ..sort((a, b) => a.anchorMin.compareTo(b.anchorMin));
    final base = _parseTm(baseTm);
    final out = <RadarSliderFrame>[];
    for (var off = 0; off <= 360; off += 10) {
      RadarAnchor primary = sorted.first;
      RadarAnchor? secondary;
      for (var i = 0; i < sorted.length; i++) {
        final a = sorted[i];
        if (a.anchorMin <= off) {
          primary = a;
          secondary = i + 1 < sorted.length ? sorted[i + 1] : null;
        } else {
          break;
        }
      }
      double blend = 0.0;
      if (secondary != null && primary.anchorMin < off) {
        blend = (off - primary.anchorMin) /
            (secondary.anchorMin - primary.anchorMin);
        blend = blend.clamp(0.0, 1.0);
      } else {
        secondary = null;
      }
      // motion-aware bounds — secondary.motionFromPrev가 primary→secondary 1시간 이동량.
      // anchor pair 간격(시간) × blend × motion = anchor가 forward shift할 양.
      // 반대로 secondary는 -(1-blend) × motion만큼 backward shift.
      RadarBounds anchorBounds = primary.bounds;
      RadarBounds? secondaryBounds = secondary?.bounds;
      if (secondary != null && secondary.motionFromPrev != null) {
        final hours = (secondary.anchorMin - primary.anchorMin) / 60.0;
        final m = secondary.motionFromPrev!;
        anchorBounds = primary.bounds.shifted(
          dlat: m.dlat * hours * blend,
          dlon: m.dlon * hours * blend,
        );
        secondaryBounds = secondary.bounds.shifted(
          dlat: -m.dlat * hours * (1.0 - blend),
          dlon: -m.dlon * hours * (1.0 - blend),
        );
      }
      out.add(RadarSliderFrame(
        offsetMin: off,
        tm: _formatTm(base.add(Duration(minutes: off))),
        anchor: primary,
        anchorBounds: anchorBounds,
        next: secondary,
        nextBounds: secondaryBounds,
        blend: blend,
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

  return RadarState(
    baseTm: data['base_tm'] as String,
    anchors: anchors,
  );
});
