import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';

class BriefingRepository {
  BriefingRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('briefings');

  Future<Briefing?> fetchOne({
    required String city,
    required String date,
    required int hour,
    required String characterId,
  }) async {
    final id = briefingDocId(
      city: city,
      date: date,
      hour: hour,
      characterId: characterId,
    );
    final snap = await _col.doc(id).get();
    final data = snap.data();
    if (data == null) return null;
    return Briefing.fromJson(data);
  }

  Future<Map<int, Briefing>> fetchDay({
    required String city,
    required String date,
    required String characterId,
  }) async {
    final sw = Stopwatch()..start();
    // 24개 doc 병렬 fetch — 첫 cold start에서 큰 병목 후보.
    // 추후 where 쿼리 1번으로 통합 검토.
    final futures = List.generate(
      24,
      (h) => fetchOne(
        city: city,
        date: date,
        hour: h,
        characterId: characterId,
      ),
    );
    final results = await Future.wait(futures);
    sw.stop();
    debugPrint(
      '[briefing_repo] ⏱ fetchDay($characterId) '
      '${sw.elapsedMilliseconds}ms — ${results.whereType<Briefing>().length}/24 hit',
    );
    return {
      for (var h = 0; h < 24; h++)
        if (results[h] != null) h: results[h]!,
    };
  }
}

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final briefingRepositoryProvider = Provider<BriefingRepository>((ref) {
  return BriefingRepository(ref.watch(firestoreProvider));
});
