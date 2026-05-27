import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 라벨 단계.
/// - 0: 광역시·도 (17개) — 가장 먼저 표시
/// - 1: 시·군·구 (~252개) — 줌인 시 추가 표시
enum LabelLevel { metro, district }

class KoreaLabel {
  const KoreaLabel({
    required this.name,
    required this.level,
    required this.nx,
    required this.ny,
  });

  final String name;
  final LabelLevel level;
  final int nx;
  final int ny;

  factory KoreaLabel.fromJson(Map<String, dynamic> j) {
    return KoreaLabel(
      name: j['name'] as String,
      level: (j['level'] as int) == 0 ? LabelLevel.metro : LabelLevel.district,
      nx: j['nx'] as int,
      ny: j['ny'] as int,
    );
  }
}

/// 한 번 로드하면 앱 생명주기 동안 캐시.
final koreaLabelsProvider = FutureProvider<List<KoreaLabel>>((ref) async {
  ref.keepAlive();
  final raw = await rootBundle.loadString('assets/maps/korea_labels.json');
  final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  return list.map(KoreaLabel.fromJson).toList();
});
