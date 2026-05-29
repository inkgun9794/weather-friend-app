import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/features/fortune/data/saju_profile.dart';

/// 내 운세 점수 시계열 한 entry. 차트 vertex용.
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

  /// 같은 날 판별용 키.
  String get dayKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// 내 프로필 운세 점수만 영구 저장. 최근 60일 유지.
class MyScoreHistoryRepository {
  MyScoreHistoryRepository(this._prefs);

  static const _key = 'my_score_history_v1';
  static const _retainDays = 60;

  final SharedPreferences _prefs;

  List<ScoreEntry> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    try {
      final list = (json.decode(raw) as List)
          .map((e) => ScoreEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveAll(List<ScoreEntry> entries) async {
    await _prefs.setString(
      _key,
      json.encode(entries.map((e) => e.toJson()).toList()),
    );
  }

  /// 오늘 entry upsert. 같은 날 여러 번 보면 최근 점수로 덮어씀.
  Future<List<ScoreEntry>> upsertToday(int score) async {
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    final entries = List<ScoreEntry>.from(load());
    final idx = entries.indexWhere((e) => e.dayKey == todayKey);
    if (idx >= 0) {
      entries[idx] = ScoreEntry(date: today, score: score);
    } else {
      entries.add(ScoreEntry(date: today, score: score));
    }

    // 보존 기간 넘은 오래된 entry 제거
    final cutoff = today.subtract(const Duration(days: _retainDays));
    entries.removeWhere((e) => e.date.isBefore(cutoff));
    entries.sort((a, b) => a.date.compareTo(b.date));

    await saveAll(entries);
    return entries;
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}

final myScoreHistoryRepositoryProvider =
    FutureProvider<MyScoreHistoryRepository>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return MyScoreHistoryRepository(prefs);
});

class MyScoreHistoryNotifier extends AsyncNotifier<List<ScoreEntry>> {
  @override
  Future<List<ScoreEntry>> build() async {
    final repo = await ref.watch(myScoreHistoryRepositoryProvider.future);
    return repo.load();
  }

  Future<void> addToday(int score) async {
    final repo = await ref.read(myScoreHistoryRepositoryProvider.future);
    final updated = await repo.upsertToday(score);
    state = AsyncValue.data(updated);
  }
}

final myScoreHistoryProvider = AsyncNotifierProvider<MyScoreHistoryNotifier,
    List<ScoreEntry>>(MyScoreHistoryNotifier.new);
