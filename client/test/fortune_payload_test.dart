import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:weather_friend/features/fortune/data/fortune_api.dart';
import 'package:weather_friend/features/fortune/data/saju_profile.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('fortune payload contains natal analysis and current luck pillars', () {
    const profile = SajuProfile(
      name: '나',
      relation: SajuRelation.self,
      year: 1994,
      month: 8,
      day: 10,
      hour: 11,
      minute: 0,
      isLunar: false,
      gender: SajuGender.male,
    );
    final result = computeSajuFor(profile)!;
    final payload = buildFortuneRequestPayload(
      profile: profile,
      result: result,
      date: DateTime(2026, 6, 8),
    );

    expect(payload['promptVersion'], 'concise-weather-v5');
    expect(payload['pillars'], isA<Map<String, dynamic>>());
    expect(payload['elementCounts'], isA<Map<String, dynamic>>());
    expect(payload['tenGodCounts'], isA<Map<String, dynamic>>());

    final strength = payload['strength'] as Map<String, dynamic>;
    final yongShen = payload['yongShen'] as Map<String, dynamic>;
    final currentFlow = payload['currentFlow'] as Map<String, dynamic>;

    expect(strength['level'], isNotEmpty);
    expect(yongShen['primary'], isNotEmpty);
    expect(currentFlow['majorLuck'], isA<Map<String, dynamic>>());
    expect(currentFlow['year'], isA<Map<String, dynamic>>());
    expect(currentFlow['month'], isA<Map<String, dynamic>>());
    expect(currentFlow['day'], isA<Map<String, dynamic>>());

    final dayFlow = currentFlow['day'] as Map<String, dynamic>;
    expect(dayFlow['pillar'], hasLength(2));
    expect(dayFlow['tenGod'], isNotEmpty);
    expect(dayFlow['relationsToNatal'], isA<List<String>>());

    final pillars = payload['pillars'] as Map<String, dynamic>;
    expect(pillars['hour'], hasLength(2)); // 시간 알면 시주 간지 그대로
    expect(payload['birthTime'], '11:00');
    expect(payload['birthTimeUnknown'], false);
  });

  test('시간 모름 프로필 — 시주 대신 모름을 보내고 placeholder로 계산', () {
    const profile = SajuProfile(
      name: '엄마',
      relation: SajuRelation.family,
      year: 1965,
      month: 3,
      day: 21,
      hour: 12,
      minute: 0,
      isLunar: false,
      gender: SajuGender.female,
      timeUnknown: true,
    );
    final result = computeSajuFor(profile);
    expect(result, isNotNull); // 정오 placeholder로 계산은 가능해야 함

    final payload = buildFortuneRequestPayload(
      profile: profile,
      result: result!,
      date: DateTime(2026, 6, 11),
    );

    final pillars = payload['pillars'] as Map<String, dynamic>;
    expect(pillars['hour'], '모름(시주 제외)');
    expect(pillars['day'], hasLength(2)); // 나머지 기둥은 정상
    expect(payload['birthTime'], '모름');
    expect(payload['birthTimeUnknown'], true);
  });

  test('SajuProfile json 왕복 + 레거시 호환 + cacheKey 구분', () {
    const profile = SajuProfile(
      name: '나',
      relation: SajuRelation.self,
      year: 1994,
      month: 8,
      day: 10,
      hour: 11,
      minute: 30,
      isLunar: false,
      gender: SajuGender.male,
      timeUnknown: true,
    );
    final restored = SajuProfile.fromJson(profile.toJson());
    expect(restored.timeUnknown, true);
    expect(restored.cacheKey, profile.cacheKey);

    // 기존 저장 데이터(timeUnknown 키 없음) → false
    final legacyJson = profile.toJson()..remove('timeUnknown');
    expect(SajuProfile.fromJson(legacyJson).timeUnknown, false);

    // 시간 모름과 같은 시각 입력은 다른 캐시 키여야 함
    const known = SajuProfile(
      name: '나',
      relation: SajuRelation.self,
      year: 1994,
      month: 8,
      day: 10,
      hour: 11,
      minute: 30,
      isLunar: false,
      gender: SajuGender.male,
    );
    expect(profile.cacheKey, isNot(known.cacheKey));
    expect(profile.cacheKey, contains('UNKN'));

    expect(known.birthSummary, '양력 1994.08.10 11:30 · 남성');
    expect(profile.birthSummary, '양력 1994.08.10 시간모름 · 남성');
  });
}
