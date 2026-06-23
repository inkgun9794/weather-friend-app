import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/features/fortune/data/saju_profile.dart';

/// 한 번 본 운세 = { 프로필, 결과 텍스트, 점수, 본 시각 }.
/// 같은 사주(cacheKey) 중복 add → 업데이트.
class FortuneReport {
  const FortuneReport({
    required this.profile,
    required this.fortuneText,
    required this.score,
    required this.viewedAt,
    this.promptVersion = '',
  });

  final SajuProfile profile;
  final String fortuneText;
  final int score; // 현재 산식은 20~100
  final DateTime viewedAt;
  final String promptVersion;

  Map<String, dynamic> toJson() => {
    'profile': profile.toJson(),
    'fortuneText': fortuneText,
    'score': score,
    'viewedAt': viewedAt.toIso8601String(),
    'promptVersion': promptVersion,
  };

  factory FortuneReport.fromJson(Map<String, dynamic> json) => FortuneReport(
    profile: SajuProfile.fromJson(json['profile'] as Map<String, dynamic>),
    fortuneText: json['fortuneText'] as String,
    score: (json['score'] as num?)?.toInt() ?? 50, // 마이그레이션 default
    viewedAt: DateTime.parse(json['viewedAt'] as String),
    promptVersion: json['promptVersion'] as String? ?? '',
  );
}

/// 당일 본 리포트만 유지. 자정 넘어가 날짜 키 다르면 자동 비움.
class FortuneReportRepository {
  FortuneReportRepository(this._prefs);

  static const _key = 'fortune_reports_v1';

  final SharedPreferences _prefs;

  List<FortuneReport> loadToday() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    try {
      final data = json.decode(raw) as Map<String, dynamic>;
      final dateKey = data['dateKey'] as String? ?? '';
      if (dateKey != _todayKey()) return const []; // 다른 날짜 = 만료
      final list = (data['reports'] as List? ?? [])
          .map((r) => FortuneReport.fromJson(r as Map<String, dynamic>))
          .toList();
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveAll(List<FortuneReport> reports) async {
    await _prefs.setString(
      _key,
      json.encode({
        'dateKey': _todayKey(),
        'reports': reports.map((r) => r.toJson()).toList(),
      }),
    );
  }

  Future<List<FortuneReport>> add(FortuneReport report) async {
    final current = loadToday();
    final mutable = List<FortuneReport>.from(current);
    final idx = mutable.indexWhere(
      (r) => r.profile.cacheKey == report.profile.cacheKey,
    );
    if (idx >= 0) {
      mutable[idx] = report;
    } else {
      mutable.add(report);
    }
    await saveAll(mutable);
    return mutable;
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }
}

final fortuneReportRepositoryProvider = FutureProvider<FortuneReportRepository>(
  (ref) async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return FortuneReportRepository(prefs);
  },
);

/// 오늘 본 리포트 리스트 — 화면에서 watch하고, 새 운세 보면 add() 호출.
class FortuneReportsNotifier extends AsyncNotifier<List<FortuneReport>> {
  @override
  Future<List<FortuneReport>> build() async {
    final repo = await ref.watch(fortuneReportRepositoryProvider.future);
    return repo.loadToday();
  }

  Future<void> add(FortuneReport report) async {
    final repo = await ref.read(fortuneReportRepositoryProvider.future);
    final updated = await repo.add(report);
    state = AsyncValue.data(updated);
  }

  /// 캐시 조회 — 같은 사주 있으면 그 리포트 반환.
  FortuneReport? findByProfile(SajuProfile profile) {
    final list = state.value ?? const [];
    for (final r in list) {
      if (r.profile.cacheKey == profile.cacheKey) return r;
    }
    return null;
  }
}

final fortuneReportsProvider =
    AsyncNotifierProvider<FortuneReportsNotifier, List<FortuneReport>>(
      FortuneReportsNotifier.new,
    );
