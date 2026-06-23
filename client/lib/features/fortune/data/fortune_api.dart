import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:saju/saju.dart' as saju;
import 'package:timezone/timezone.dart' as tz;
import 'package:weather_friend/features/fortune/data/fortune_report.dart';
import 'package:weather_friend/features/fortune/data/fortune_score_history.dart';
import 'package:weather_friend/features/fortune/data/saju_profile.dart';

/// Cloud Run (Seoul region) Gemini proxy URL.
const _kFortuneEndpoint =
    'https://weather-friend-llm-89382148867.asia-northeast3.run.app';
const fortunePromptVersion = 'concise-weather-v11';

/// LLM 응답 — 운세 텍스트 + 점수 (현재 산식은 20~100).
class FortuneResult {
  const FortuneResult({
    required this.text,
    required this.score,
    this.promptVersion = fortunePromptVersion,
  });
  final String text;
  final int score;
  final String promptVersion;
}

class FortuneApi {
  const FortuneApi();

  Future<FortuneResult> fetch({
    required SajuProfile profile,
    required saju.SajuResult result,
    required DateTime date,
  }) async {
    final payload = buildFortuneRequestPayload(
      profile: profile,
      result: result,
      date: date,
    );

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
    final promptVersion =
        data['promptVersion'] as String? ?? fortunePromptVersion;
    if (text.isEmpty) throw const FortuneApiException('빈 응답');
    return FortuneResult(
      text: text,
      score: score.clamp(0, 100),
      promptVersion: promptVersion,
    );
  }
}

Map<String, dynamic> buildFortuneRequestPayload({
  required SajuProfile profile,
  required saju.SajuResult result,
  required DateTime date,
}) {
  final location = tz.getLocation('Asia/Seoul');
  final targetDate = tz.TZDateTime(
    location,
    date.year,
    date.month,
    date.day,
    12,
  );
  final currentPillars = saju.getFourPillars(targetDate).pillars;
  final koreanAge = date.year - profile.year + 1;
  final currentMajorLuck = saju.getCurrentMajorLuck(
    result.majorLuck,
    koreanAge,
  );
  final elementCounts = saju.countElements(result.pillars);
  final tenGodCounts = saju.countTenGods(result.tenGods);

  return {
    'pillars': {
      'year': result.pillars.year.hanja,
      'month': result.pillars.month.hanja,
      'day': result.pillars.day.hanja,
      // 서버가 이 값을 프롬프트의 "사주 4기둥" 줄에 그대로 넣는다.
      // 시간 모름이면 placeholder(12:00)로 계산된 시주 대신 '모름'을 보내
      // LLM이 세 기둥 기준으로 풀이하게 한다.
      'hour': profile.timeUnknown ? '모름(시주 제외)' : result.pillars.hour.hanja,
    },
    'dayMaster': result.pillars.dayMaster.hanja,
    'element': result.pillars.dayMaster.element.key,
    'strength': {
      'level': result.strength.level.korean,
      'score': result.strength.score,
    },
    'yongShen': {
      'primary': result.yongShen.primary.korean,
      'secondary': result.yongShen.secondary?.korean,
      'method': result.yongShen.method.korean,
      'johuAdjustment': result.yongShen.johuAdjustment?.korean,
    },
    'elementCounts': {
      for (final entry in elementCounts.entries) entry.key.korean: entry.value,
    },
    'tenGodCounts': {
      for (final entry in tenGodCounts.entries) entry.key.korean: entry.value,
    },
    'natalRelations': {
      'stemCombinations': result.relations.stemCombinations.length,
      'sixCombinations': result.relations.sixCombinations.length,
      'tripleCombinations': result.relations.tripleCombinations.length,
      'clashes': result.relations.clashes.length,
      'harms': result.relations.harms.length,
      'punishments': result.relations.punishments.length,
      'destructions': result.relations.destructions.length,
    },
    'currentFlow': {
      if (currentMajorLuck != null)
        'majorLuck': _flowPillar(
          currentMajorLuck.pillar,
          result: result,
          label: '대운',
        ),
      'year': _flowPillar(currentPillars.year, result: result, label: '세운'),
      'month': _flowPillar(currentPillars.month, result: result, label: '월운'),
      'day': _flowPillar(currentPillars.day, result: result, label: '일운'),
    },
    'gender': profile.gender == SajuGender.male ? 'male' : 'female',
    'birthYear': profile.year,
    'birthTime': profile.timeUnknown
        ? '모름'
        : '${profile.hour.toString().padLeft(2, '0')}:'
              '${profile.minute.toString().padLeft(2, '0')}',
    'birthTimeUnknown': profile.timeUnknown,
    'date':
        '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
    'promptVersion': fortunePromptVersion,
  };
}

Map<String, dynamic> _flowPillar(
  saju.Pillar pillar, {
  required saju.SajuResult result,
  required String label,
}) {
  final dayMaster = result.pillars.dayMaster;
  final stemElement = pillar.stem.element;
  final branchElement = pillar.branch.element;

  return {
    'label': label,
    'pillar': pillar.hanja,
    'korean': pillar.korean,
    'tenGod': saju.getTenGodKey(dayMaster, pillar.stem).korean,
    'stemElement': stemElement.korean,
    'stemRole': _elementRole(stemElement, result.yongShen),
    'branchElement': branchElement.korean,
    'branchRole': _elementRole(branchElement, result.yongShen),
    'relationsToNatal': _relationsToNatal(pillar, result.pillars),
  };
}

String _elementRole(saju.Element element, saju.YongShenResult yongShen) {
  final status = yongShen.allElements[element];
  if (status?.isYongShen == true) return '도움';
  if (status?.isKiShen == true) return '주의';
  return '중립';
}

List<String> _relationsToNatal(saju.Pillar flow, saju.FourPillars natal) {
  final relations = <String>[];
  final natalPillars = {
    '년주': natal.year,
    '월주': natal.month,
    '일주': natal.day,
    '시주': natal.hour,
  };

  for (final entry in natalPillars.entries) {
    final stemRelation = _stemRelation(flow.stem, entry.value.stem);
    if (stemRelation != null) relations.add('${entry.key} 천간 $stemRelation');

    final branchRelations = _branchRelations(flow.branch, entry.value.branch);
    for (final relation in branchRelations) {
      relations.add('${entry.key} 지지 $relation');
    }
  }

  return relations;
}

String? _stemRelation(saju.Stem first, saju.Stem second) {
  const combinations = [
    {saju.Stem.jia, saju.Stem.ji},
    {saju.Stem.yi, saju.Stem.geng},
    {saju.Stem.bing, saju.Stem.xin},
    {saju.Stem.ding, saju.Stem.ren},
    {saju.Stem.wu, saju.Stem.gui},
  ];
  return combinations.any(
        (pair) => pair.contains(first) && pair.contains(second),
      )
      ? '합'
      : null;
}

List<String> _branchRelations(saju.Branch first, saju.Branch second) {
  final relations = <String>[];
  const combinations = [
    {saju.Branch.zi, saju.Branch.chou},
    {saju.Branch.yin, saju.Branch.hai},
    {saju.Branch.mao, saju.Branch.xu},
    {saju.Branch.chen, saju.Branch.you},
    {saju.Branch.si, saju.Branch.shen},
    {saju.Branch.wu, saju.Branch.wei},
  ];
  const clashes = [
    {saju.Branch.zi, saju.Branch.wu},
    {saju.Branch.chou, saju.Branch.wei},
    {saju.Branch.yin, saju.Branch.shen},
    {saju.Branch.mao, saju.Branch.you},
    {saju.Branch.chen, saju.Branch.xu},
    {saju.Branch.si, saju.Branch.hai},
  ];
  const harms = [
    {saju.Branch.zi, saju.Branch.wei},
    {saju.Branch.chou, saju.Branch.wu},
    {saju.Branch.yin, saju.Branch.si},
    {saju.Branch.mao, saju.Branch.chen},
    {saju.Branch.shen, saju.Branch.hai},
    {saju.Branch.you, saju.Branch.xu},
  ];
  const destructions = [
    {saju.Branch.zi, saju.Branch.you},
    {saju.Branch.chou, saju.Branch.chen},
    {saju.Branch.yin, saju.Branch.hai},
    {saju.Branch.mao, saju.Branch.wu},
    {saju.Branch.si, saju.Branch.shen},
    {saju.Branch.wei, saju.Branch.xu},
  ];

  bool matches(List<Set<saju.Branch>> pairs) =>
      pairs.any((pair) => pair.contains(first) && pair.contains(second));

  if (matches(combinations)) relations.add('합');
  if (matches(clashes)) relations.add('충');
  if (matches(harms)) relations.add('해');
  if (matches(destructions)) relations.add('파');
  if (_isPunishment(first, second)) relations.add('형');

  return relations;
}

bool _isPunishment(saju.Branch first, saju.Branch second) {
  if (first == second) {
    return const {
      saju.Branch.chen,
      saju.Branch.wu,
      saju.Branch.you,
      saju.Branch.hai,
    }.contains(first);
  }

  const pairs = [
    {saju.Branch.zi, saju.Branch.mao},
    {saju.Branch.yin, saju.Branch.si},
    {saju.Branch.si, saju.Branch.shen},
    {saju.Branch.shen, saju.Branch.yin},
    {saju.Branch.chou, saju.Branch.xu},
    {saju.Branch.xu, saju.Branch.wei},
    {saju.Branch.wei, saju.Branch.chou},
  ];
  return pairs.any((pair) => pair.contains(first) && pair.contains(second));
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
      // 리포트 저장은 이 provider 내부에서 일어난다. 여기서 watch하면
      // 저장된 목록 변경이 다시 fetch를 시작해 재호출 순환이 생긴다.
      await ref.read(fortuneReportsProvider.future);
      final reportsNotifier = ref.read(fortuneReportsProvider.notifier);
      final cached = reportsNotifier.findByProfile(profile);
      // 점수 산식이 바뀐 리포트는 같은 날이어도 다시 생성한다.
      if (cached != null && cached.promptVersion == fortunePromptVersion) {
        return FortuneResult(
          text: cached.fortuneText,
          score: cached.score,
          promptVersion: cached.promptVersion,
        );
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
      await reportsNotifier.add(
        FortuneReport(
          profile: profile,
          fortuneText: result.text,
          score: result.score,
          viewedAt: DateTime.now(),
          promptVersion: result.promptVersion,
        ),
      );

      // 5) 모든 프로필의 점수 시계열에 추가 (cacheKey별)
      final scoreRepo = await ref.read(scoreHistoryRepositoryProvider.future);
      await scoreRepo.addForProfile(profile.cacheKey, result.score);
      ref.invalidate(scoreHistoryProvider(profile.cacheKey));

      return result;
    });
