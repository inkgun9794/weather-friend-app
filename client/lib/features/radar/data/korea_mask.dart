import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 한반도 영역 격자 셀 — KMA가 관측하는 영역 (비관측영역 -99 제외).
/// 한 번 생성해서 Firestore에 저장된 정적 데이터. 시간이 지나도 변하지 않음.
class KoreaMaskCell {
  const KoreaMaskCell({required this.nx, required this.ny});
  final int nx;
  final int ny;
}

class KoreaMask {
  const KoreaMask({
    required this.nx,
    required this.ny,
    required this.cells,
  });
  final int nx;
  final int ny;
  final List<KoreaMaskCell> cells;

  factory KoreaMask.fromFirestore(Map<String, dynamic> data) {
    return KoreaMask(
      nx: (data['nx'] as num).toInt(),
      ny: (data['ny'] as num).toInt(),
      cells: ((data['cells'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (c) => KoreaMaskCell(
              nx: (c['nx'] as num).toInt(),
              ny: (c['ny'] as num).toInt(),
            ),
          )
          .toList(),
    );
  }
}

/// 한 번 fetch하면 앱 생명주기 동안 캐시 — `keepAlive: true`.
final koreaMaskProvider = FutureProvider<KoreaMask?>((ref) async {
  ref.keepAlive();
  final doc = await FirebaseFirestore.instance
      .collection('kma_grid_mask')
      .doc('korea')
      .get();
  if (!doc.exists) return null;
  return KoreaMask.fromFirestore(doc.data()!);
});
