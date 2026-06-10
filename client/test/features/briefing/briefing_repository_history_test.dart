import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/features/briefing/data/briefing_repository.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads locally cached briefing days in chronological order', () async {
    SharedPreferences.setMockInitialValues({
      'briefings_v1:seoul:2026-06-09:jiyoung': jsonEncode([
        _briefing(date: '2026-06-09', hour: 21).toJson(),
        _briefing(date: '2026-06-09', hour: 6).toJson(),
      ]),
      'briefings_v1:seoul:2026-06-08:jiyoung': jsonEncode([
        _briefing(date: '2026-06-08', hour: 11).toJson(),
      ]),
      'briefings_v1:seoul:2026-06-09:sohee': jsonEncode([
        _briefing(date: '2026-06-09', hour: 12, characterId: 'sohee').toJson(),
      ]),
      'briefings_v1:seoul:broken:jiyoung': 'not-json',
    });
    final prefs = await SharedPreferences.getInstance();
    final repository = BriefingRepository.cacheOnly(prefs);

    final history = repository.readCachedHistory(
      city: 'seoul',
      characterId: 'jiyoung',
    );

    expect(history.map((briefing) => '${briefing.date}/${briefing.hour}'), [
      '2026-06-08/11',
      '2026-06-09/6',
      '2026-06-09/21',
    ]);
  });
}

Briefing _briefing({
  required String date,
  required int hour,
  String characterId = 'jiyoung',
}) {
  return Briefing(
    city: 'seoul',
    date: date,
    hour: hour,
    characterId: characterId,
    type: BriefingType.hourly,
    transcript: '$date $hour시 메시지',
  );
}
