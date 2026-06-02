import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/features/fortune/data/saju_profile.dart';

/// 점수 시계열 한 entry — 차트 vertex.
class ScoreEntry {
  const ScoreEntry({required this.date, required this.score});

  final DateTime date;
  final int score; // 0~100

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'score': score,
      };

  factory ScoreEntry.fromJson(Map<String, dynamic> j) => ScoreEntry(
        date: DateTime.parse(j['date'] as String),
        score: (j['score'] as num).toInt(),
      );

  String get dayKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// 프로필별(cacheKey 단위) 점수 시계열을 SharedPreferences에 영구 저장.
/// 저장 형식: `{ cacheKey1: [...entries], cacheKey2: [...] }` — 한 키에 다 저장.
/// 최근 60일 유지.
class ScoreHistoryRepository {
  ScoreHistoryRepository(this._prefs);

  static const _key = 'score_history_v2'; // v1은 글로벌 1개였음 — 호환 X (덮어씀)
  static const _retainDays = 60;

  final SharedPreferences _prefs;

  Map<String, List<ScoreEntry>> _loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return {};
    try {
      final data = json.decode(raw) as Map<String, dynamic>;
      return data.map((cacheKey, list) {
        final entries = (list as List)
            .map((e) => ScoreEntry.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        return MapEntry(cacheKey, entries);
      });
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveAll(Map<String, List<ScoreEntry>> all) async {
    final json0 = all.map(
      (k, entries) => MapEntry(k, entries.map((e) => e.toJson()).toList()),
    );
    await _prefs.setString(_key, json.encode(json0));
  }

  List<ScoreEntry> loadForProfile(String cacheKey) {
    return _loadAll()[cacheKey] ?? const [];
  }

  /// 오늘 entry upsert. 같은 날 여러 번 보면 마지막 점수로 덮어씀.
  /// 60일 넘은 오래된 entry는 제거.
  Future<List<ScoreEntry>> addForProfile(String cacheKey, int score) async {
    final all = _loadAll();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    final entries = List<ScoreEntry>.from(all[cacheKey] ?? const []);
    final idx = entries.indexWhere((e) => e.dayKey == todayKey);
    if (idx >= 0) {
      entries[idx] = ScoreEntry(date: today, score: score);
    } else {
      entries.add(ScoreEntry(date: today, score: score));
    }

    // 보존 기간 넘은 거 제거
    final cutoff = today.subtract(const Duration(days: _retainDays));
    entries.removeWhere((e) => e.date.isBefore(cutoff));
    entries.sort((a, b) => a.date.compareTo(b.date));

    all[cacheKey] = entries;
    await _saveAll(all);
    return entries;
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}

final scoreHistoryRepositoryProvider =
    FutureProvider<ScoreHistoryRepository>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return ScoreHistoryRepository(prefs);
});

/// 특정 프로필(cacheKey)의 점수 시계열. add는 외부에서 호출 후 invalidate.
final scoreHistoryProvider =
    FutureProvider.family<List<ScoreEntry>, String>((ref, cacheKey) async {
  final repo = await ref.watch(scoreHistoryRepositoryProvider.future);
  return repo.loadForProfile(cacheKey);
});
