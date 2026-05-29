/// saju 패키지 검증 — 사용자 케이스(1994-08-10 11:00 KST) 결과 확인.
///
/// 기대값 (사용자가 받은 명리학 분석 답변 기준):
///   연주: 甲戌
///   월주: 壬申
///   일주: 戊辰
///   시주: 戊午
///
/// 실행: flutter test test/saju_verify_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:saju/saju.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
  });

  test('1994-08-10 11:00 KST → 甲戌 壬申 戊辰 戊午 검증', () {
    final loc = tz.getLocation('Asia/Seoul');
    final birth = tz.TZDateTime(loc, 1994, 8, 10, 11, 0);

    final pillars = getFourPillars(birth);

    final year = pillars.pillars.year.hanja;
    final month = pillars.pillars.month.hanja;
    final day = pillars.pillars.day.hanja;
    final hour = pillars.pillars.hour.hanja;
    final dayMaster = pillars.pillars.dayMaster.hanja;

    // 출력 (test runner stdout)
    // ignore: avoid_print
    print('--- saju 결과 ---');
    // ignore: avoid_print
    print('연주: $year (기대: 甲戌)');
    // ignore: avoid_print
    print('월주: $month (기대: 壬申)');
    // ignore: avoid_print
    print('일주: $day (기대: 戊辰)');
    // ignore: avoid_print
    print('시주: $hour (기대: 戊午)');
    // ignore: avoid_print
    print('일간: $dayMaster (기대: 戊)');

    expect(year, equals('甲戌'));
    expect(month, equals('壬申'));
    expect(day, equals('戊辰'));
    expect(hour, equals('戊午'));
    expect(dayMaster, equals('戊'));
  });

  test('1994-08-10 11:00 KST 추가 정보 (십성/십이운성/완전분석)', () {
    final loc = tz.getLocation('Asia/Seoul');
    final birth = tz.TZDateTime(loc, 1994, 8, 10, 11, 0);

    final pillars = getFourPillars(birth);

    // 십성
    try {
      final tenGods = analyzeTenGods(pillars.pillars);
      // ignore: avoid_print
      print('--- 십성 ---');
      // ignore: avoid_print
      print('일간: ${tenGods.dayMaster.hanja}');
      // ignore: avoid_print
      print('연간 천간 십성: ${tenGods.year.stem.tenGod.korean}');
      // ignore: avoid_print
      print('월간 천간 십성: ${tenGods.month.stem.tenGod.korean}');
      // ignore: avoid_print
      print('시간 천간 십성: ${tenGods.hour.stem.tenGod.korean}');
    } catch (e) {
      // ignore: avoid_print
      print('analyzeTenGods 호출 실패: $e');
    }

    // 십이운성
    try {
      final stages = analyzeTwelveStages(pillars.pillars);
      // ignore: avoid_print
      print('--- 십이운성 ---');
      // ignore: avoid_print
      print('연지: ${stages.year.korean}');
      // ignore: avoid_print
      print('월지: ${stages.month.korean}');
      // ignore: avoid_print
      print('일지: ${stages.day.korean}');
      // ignore: avoid_print
      print('시지: ${stages.hour.korean}');
    } catch (e) {
      // ignore: avoid_print
      print('analyzeTwelveStages 호출 실패: $e');
    }

    // 완전 분석 (강약·용신 등)
    try {
      final full = getSaju(birth, gender: Gender.male);
      // ignore: avoid_print
      print('--- 완전 분석 ---');
      // ignore: avoid_print
      print('신강신약: ${full.strength.level.korean}');
      // ignore: avoid_print
      print('용신: ${full.yongShen.primary.korean}');
    } catch (e) {
      // ignore: avoid_print
      print('getSaju 호출 실패: $e');
    }
  });
}
