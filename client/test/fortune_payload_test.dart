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

    expect(payload['promptVersion'], 'concise-weather-v3');
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
  });
}
