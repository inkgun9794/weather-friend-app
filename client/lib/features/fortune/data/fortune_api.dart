import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:saju/saju.dart' as saju;
import 'package:weather_friend/features/fortune/data/fortune_report.dart';
import 'package:weather_friend/features/fortune/data/fortune_score_history.dart';
import 'package:weather_friend/features/fortune/data/saju_profile.dart';

/// Cloud Run (Seoul region) Gemini proxy URL.
const _kFortuneEndpoint =
    'https://weather-friend-llm-89382148867.asia-northeast3.run.app';

/// LLM 응답 — 운세 텍스트 + 점수 (0~100).
class FortuneResult {
  const FortuneResult({required this.text, required this.score});
  final String text;
  final int score;
}

class FortuneApi {
  const FortuneApi();

  Future<FortuneResult> fetch({
    required SajuProfile profile,
    required saju.SajuResult result,
    required DateTime date,
  }) async {
    final payload = {
      'pillars': {
        'year': result.pillars.year.hanja,
        'month': result.pillars.month.hanja,
        'day': result.pillars.day.hanja,
        'hour': result.pillars.hour.hanja,
      },
      'dayMaster': result.pillars.dayMaster.hanja,
      'element': result.pillars.dayMaster.element.key,
      'strength': result.strength.level.korean,
      'yongShen': result.yongShen.primary.korean,
      'gender': profile.gender == SajuGender.male ? 'male' : 'female',
      'birthYear': profile.year,
      'birthTime': '${profile.hour.toString().padLeft(2, '0')}:'
          '${profile.minute.toString().padLeft(2, '0')}',
      'date': '${date.year}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}',
    };

    final res = await http
        .post(
          Uri.parse(_kFortuneEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw FortuneApiException('Fortune API ${res.statusCode}: ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final text = data['text'] as String? ?? '';
    final score = (data['score'] as num?)?.toInt() ?? 50;
    if (text.isEmpty) throw const FortuneApiException('빈 응답');
    return FortuneResult(text: text, score: score.clamp(0, 100));
  }
}

class FortuneApiException implements Exception {
  const FortuneApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

final fortuneApiProvider = Provider<FortuneApi>((_) => const FortuneApi());

/// 임의 프로필의 오늘 운세를 fetch. 캐시 → LLM → 캐시 저장 순서.
/// 내 프로필이면 점수 시계열에도 add.
final fortuneForProfileProvider =
    FutureProvider.family<FortuneResult, SajuProfile>((ref, profile) async {
  // 1) 캐시 hit?
  await ref.watch(fortuneReportsProvider.future);
  final reportsNotifier = ref.read(fortuneReportsProvider.notifier);
  final cached = reportsNotifier.findByProfile(profile);
  if (cached != null) {
    return FortuneResult(text: cached.fortuneText, score: cached.score);
  }

  // 2) 사주 계산
  final sajuResult = computeSajuFor(profile);
  if (sajuResult == null) {
    throw const FortuneApiException('사주 계산에 실패했습니다');
  }

  // 3) LLM 호출
  final api = ref.read(fortuneApiProvider);
  final result = await api.fetch(
    profile: profile,
    result: sajuResult,
    date: DateTime.now(),
  );

  // 4) 당일 리포트에 추가
  await reportsNotifier.add(FortuneReport(
    profile: profile,
    fortuneText: result.text,
    score: result.score,
    viewedAt: DateTime.now(),
  ));

  // 5) 모든 프로필의 점수 시계열에 추가 (cacheKey별)
  final scoreRepo = await ref.read(scoreHistoryRepositoryProvider.future);
  await scoreRepo.addForProfile(profile.cacheKey, result.score);
  ref.invalidate(scoreHistoryProvider(profile.cacheKey));

  return result;
});
