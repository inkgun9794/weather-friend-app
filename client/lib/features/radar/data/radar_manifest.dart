import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// 한 프레임 메타 — bytes는 별도 doc에서 lazy fetch.
class RadarFrame {
  const RadarFrame({
    required this.slot,
    required this.kind,
    required this.tm,
    required this.offsetMin,
  });

  /// 'past_0' ~ 'past_5' / 'current' / 'future_1' ~ 'future_6'
  final String slot;

  /// 'obs' (실측) | 'fcst' (외삽 예측)
  final String kind;

  /// YYYYMMDDHHmm (KST)
  final String tm;

  /// 현재 기준 분 단위 오프셋. 과거는 음수, 미래는 양수.
  final int offsetMin;

  bool get isObservation => kind == 'obs';

  factory RadarFrame.fromMap(Map<String, dynamic> m) => RadarFrame(
        slot: m['slot'] as String,
        kind: m['kind'] as String,
        tm: m['tm'] as String,
        offsetMin: (m['offset_min'] as num).toInt(),
      );
}

/// 레이더 PNG가 차지하는 위경도 영역. flutter_map OverlayImage에 그대로 전달.
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

  factory RadarBounds.fromMap(Map<String, dynamic> m) => RadarBounds(
        south: (m['south'] as num).toDouble(),
        west: (m['west'] as num).toDouble(),
        north: (m['north'] as num).toDouble(),
        east: (m['east'] as num).toDouble(),
      );
}

/// manifest + 모든 프레임 bytes를 한 묶음으로 — 한 번에 prefetch해 슬라이더 부드럽게.
class RadarState {
  const RadarState({
    required this.baseTm,
    required this.bounds,
    required this.frames,
    required this.bytesBySlot,
  });

  final String baseTm;
  final RadarBounds bounds;
  final List<RadarFrame> frames; // 시간순 (과거 → 현재 → 미래)
  final Map<String, Uint8List> bytesBySlot;
}

/// 1) `kma_radar/latest` manifest doc 1번
/// 2) `kma_radar/latest/frames/{slot}` 프레임 doc 13개를 병렬 fetch
/// 3) bytes를 메모리에 캐시한 채로 [RadarState] 반환 → 슬라이더 즉시 전환
final radarStateProvider = FutureProvider<RadarState?>((ref) async {
  final fs = FirebaseFirestore.instance;
  final manifestDoc = await fs.collection('kma_radar').doc('latest').get();
  if (!manifestDoc.exists) return null;
  final data = manifestDoc.data()!;

  final frames = ((data['frames'] as List?) ?? const [])
      .cast<Map<String, dynamic>>()
      .map(RadarFrame.fromMap)
      .toList()
    ..sort((a, b) => a.offsetMin.compareTo(b.offsetMin));

  final framesRef =
      fs.collection('kma_radar').doc('latest').collection('frames');
  final fetched = await Future.wait(
    frames.map((f) async {
      final doc = await framesRef.doc(f.slot).get();
      if (!doc.exists) return null;
      final raw = doc.data()?['png'];
      if (raw is Blob) return MapEntry(f.slot, raw.bytes);
      return null;
    }),
  );
  final bytesBySlot = <String, Uint8List>{
    for (final entry in fetched)
      if (entry != null) entry.key: entry.value,
  };

  return RadarState(
    baseTm: data['base_tm'] as String,
    bounds: RadarBounds.fromMap(data['bounds'] as Map<String, dynamic>),
    frames: frames.where((f) => bytesBySlot.containsKey(f.slot)).toList(),
    bytesBySlot: bytesBySlot,
  );
});
