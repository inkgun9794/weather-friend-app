import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:saju/saju.dart' as saju;
import 'package:weather_friend/features/fortune/presentation/widgets/birth_wheel_pickers.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('sijinFor', () {
    test('정각 경계 — 23시 자시 시작, 2시간 단위', () {
      expect(sijinFor(23).name, '자시');
      expect(sijinFor(0).name, '자시');
      expect(sijinFor(1).name, '축시');
      expect(sijinFor(7).name, '진시');
      expect(sijinFor(11).name, '오시');
      expect(sijinFor(12).name, '오시');
      expect(sijinFor(13).name, '미시');
      expect(sijinFor(22).name, '해시');
      expect(sijinFor(7).range, '07:00~08:59');
    });

    test('saju 엔진의 시주 지지와 24시간 전부 일치', () {
      final loc = tz.getLocation('Asia/Seoul');
      for (var hour = 0; hour < 24; hour++) {
        final birth = tz.TZDateTime(loc, 1990, 1, 15, hour);
        final result = saju.getSaju(birth, gender: saju.Gender.male);
        expect(
          sijinFor(hour).name[0],
          result.pillars.hour.branch.korean,
          reason: '$hour시의 시진 라벨이 엔진 시주와 다름',
        );
      }
    });
  });

  group('생년월일 휠 시트', () {
    testWidgets('음력 토글 후 확인 → isLunar 반환', (tester) async {
      BirthDateSelection? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showBirthDateWheelSheet(
                      context,
                      initial: DateTime(1990, 1, 15),
                      initialIsLunar: false,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('생년월일'), findsOneWidget);
      expect(find.text('1990년'), findsWidgets);

      await tester.tap(find.text('음력'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.isLunar, true);
      expect(result!.date, DateTime(1990, 1, 15));
    });

    testWidgets('1월 31일에서 2월로 넘기면 28일로 클램프', (tester) async {
      BirthDateSelection? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showBirthDateWheelSheet(
                      context,
                      initial: DateTime(1990, 1, 31),
                      initialIsLunar: false,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 월 휠을 한 칸 위로 → 2월
      await tester.drag(
        find.byKey(const Key('birth-month-wheel')),
        const Offset(0, -44),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.date, DateTime(1990, 2, 28));
      expect(result!.isLunar, false);
    });

    testWidgets('변경 없이 확인 → 초기값 그대로 반환', (tester) async {
      BirthDateSelection? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showBirthDateWheelSheet(
                      context,
                      initial: DateTime(1994, 8, 10),
                      initialIsLunar: true,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.date, DateTime(1994, 8, 10));
      expect(result!.isLunar, true);
    });
  });

  group('태어난 시간 휠 시트', () {
    Future<void> pumpOpener(
      WidgetTester tester,
      void Function(BirthTimeSelection?) onResult, {
      int hour = 7,
      int minute = 30,
      bool unknown = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    onResult(
                      await showBirthTimeWheelSheet(
                        context,
                        initialHour: hour,
                        initialMinute: minute,
                        initialUnknown: unknown,
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('시진 캡션이 실시간 표시 — 07:30은 진시', (tester) async {
      await pumpOpener(tester, (_) {});
      expect(find.text('진시 (07:00~08:59)'), findsOneWidget);

      // 시 휠 두 칸 위로 → 09시 → 사시
      await tester.drag(
        find.byKey(const Key('birth-hour-wheel')),
        const Offset(0, -88),
      );
      await tester.pumpAndSettle();
      expect(find.text('사시 (09:00~10:59)'), findsOneWidget);
    });

    testWidgets('시간 몰라요 선택 → unknown 반환', (tester) async {
      BirthTimeSelection? result;
      await pumpOpener(tester, (r) => result = r);

      await tester.tap(find.byKey(const Key('birth-time-unknown')));
      await tester.pumpAndSettle();
      expect(find.text('시(時)를 빼고 세 기둥으로 풀이해요'), findsOneWidget);

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.unknown, true);
    });

    testWidgets('시간 변경 후 확인 → 새 시각 반환', (tester) async {
      BirthTimeSelection? result;
      await pumpOpener(tester, (r) => result = r);

      await tester.drag(
        find.byKey(const Key('birth-minute-wheel')),
        const Offset(0, 44), // 30분 → 29분
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.unknown, false);
      expect(result!.hour, 7);
      expect(result!.minute, 29);
    });
  });
}
