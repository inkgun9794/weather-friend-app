import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';

class BriefingRepository {
  BriefingRepository(this._firestore, this._prefs);

  final FirebaseFirestore _firestore;
  final SharedPreferences _prefs;

  static const _activeHours = <int>[
    6,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
  ];

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
    final futures = [
      for (final hour in _activeHours)
        fetchOne(city: city, date: date, hour: hour, characterId: characterId),
    ];
    final results = await Future.wait(futures);
    sw.stop();
    debugPrint(
      '[briefing_repo] ⏱ fetchDay($characterId) '
      '${sw.elapsedMilliseconds}ms — '
      '${results.whereType<Briefing>().length}/${_activeHours.length} hit',
    );
    final briefings = {
      for (var i = 0; i < _activeHours.length; i++)
        if (results[i] != null) _activeHours[i]: results[i]!,
    };
    await _writeCachedDay(
      city: city,
      date: date,
      characterId: characterId,
      briefings: briefings,
    );
    return briefings;
  }

  Map<int, Briefing>? readCachedDay({
    required String city,
    required String date,
    required String characterId,
  }) {
    final raw = _prefs.getString(_cacheKey(city, date, characterId));
    if (raw == null) return null;
    try {
      final items = (json.decode(raw) as List).cast<Map<String, dynamic>>();
      return {
        for (final item in items)
          (item['hour'] as num).toInt(): Briefing.fromJson(item),
      };
    } catch (_) {
      return null;
    }
  }

  String _cacheKey(String city, String date, String characterId) {
    return 'briefings_v1:$city:$date:$characterId';
  }

  Future<void> _writeCachedDay({
    required String city,
    required String date,
    required String characterId,
    required Map<int, Briefing> briefings,
  }) {
    final values = briefings.values.toList()
      ..sort((a, b) => a.hour.compareTo(b.hour));
    return _prefs.setString(
      _cacheKey(city, date, characterId),
      json.encode(values.map((value) => value.toJson()).toList()),
    );
  }
}

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final briefingRepositoryProvider = Provider<BriefingRepository>((ref) {
  return BriefingRepository(
    ref.watch(firestoreProvider),
    ref.watch(sharedPreferencesProvider),
  );
});
