import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 한 격자 셀의 강수량.
class RainCell {
  const RainCell({required this.nx, required this.ny, required this.rn1});
  final int nx;
  final int ny;
  final double rn1; // mm/h
}

/// 한 시간 슬롯의 강수 격자 (sparse — 강수 있는 셀만).
class RainHour {
  const RainHour({
    required this.offset,
    required this.tmef,
    required this.cells,
  });
  final int offset; // 1..6 (발표시각 + offset 시간)
  final String tmef; // YYYYMMDDHH
  final List<RainCell> cells;
}

/// 비구름 지도용 전체 데이터. 한반도 격자 + 6시간치 강수 셀.
class RainGrid {
  const RainGrid({
    required this.baseTime,
    required this.nx,
    required this.ny,
    required this.hours,
  });
  final String baseTime; // YYYYMMDDHHMM (발표시각)
  final int nx; // 149
  final int ny; // 253
  final List<RainHour> hours;

  factory RainGrid.fromFirestore(Map<String, dynamic> data) {
    return RainGrid(
      baseTime: data['base_time'] as String,
      nx: (data['nx'] as num).toInt(),
      ny: (data['ny'] as num).toInt(),
      hours: ((data['hours'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (h) => RainHour(
              offset: (h['offset'] as num).toInt(),
              tmef: h['tmef'] as String,
              cells: ((h['cells'] as List?) ?? const [])
                  .cast<Map<String, dynamic>>()
                  .map(
                    (c) => RainCell(
                      nx: (c['nx'] as num).toInt(),
                      ny: (c['ny'] as num).toInt(),
                      rn1: (c['rn1'] as num).toDouble(),
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }
}

final rainGridProvider = FutureProvider<RainGrid?>((ref) async {
  final doc = await FirebaseFirestore.instance
      .collection('kma_grid_rain')
      .doc('latest')
      .get();
  if (!doc.exists) return null;
  return RainGrid.fromFirestore(doc.data()!);
});
