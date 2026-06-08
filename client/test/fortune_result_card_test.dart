import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/features/fortune/data/fortune_api.dart';
import 'package:weather_friend/features/fortune/data/saju_profile.dart';
import 'package:weather_friend/features/fortune/presentation/widgets/fortune_result_card.dart';

void main() {
  testWidgets('shows only the three concise fortune sections', (tester) async {
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
    const legacyResponse = '''
## 총평
오늘은 서두르지 않을수록 흐름이 좋아져.

## 관계/대인
가까운 사람과 대화가 잘 풀려.

## 일/공부
집중력이 좋아지는 날이야.

## 재물
작은 지출을 조심해.

## 건강
가볍게 몸을 움직여.

## 챙길점
중요한 일정은 한 번 더 확인해.

## 한줄 조언
천천히 가도 충분해.
''';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fortuneForProfileProvider.overrideWith(
            (ref, profile) async =>
                const FortuneResult(text: legacyResponse, score: 72),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FortuneTodayCards(profile: profile),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('오늘의 운세'), findsOneWidget);
    expect(find.text('챙길 점'), findsOneWidget);
    expect(find.text('한 줄 조언'), findsOneWidget);
    expect(find.text('관계/대인'), findsNothing);
    expect(find.text('일/공부'), findsNothing);
    expect(find.text('재물'), findsNothing);
    expect(find.text('건강'), findsNothing);
  });
}
