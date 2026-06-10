import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/core/services/notification_service.dart';

void main() {
  test('defines morning and evening audio notification slots', () {
    expect(
      BriefingSlot.values.map((slot) => slot.hour),
      containsAll(<int>[6, 21]),
    );
  });

  test('resolves a scheduled briefing locator for the tapped date', () {
    final payload = briefingAudioNotificationPayload(
      city: 'seoul',
      hour: 6,
      characterId: 'jihoon',
    );

    expect(
      resolveAudioNotificationPayload(payload, date: '2026-06-10'),
      'https://inkgun9794.github.io/weather-friend-app/'
      'briefings/seoul/2026-06-10/06/jihoon.mp3',
    );
  });

  test('keeps a direct remote audio URL unchanged', () {
    const url = 'https://example.com/audio.mp3';
    expect(resolveAudioNotificationPayload(url, date: '2026-06-10'), url);
  });

  test('rejects malformed notification payloads', () {
    expect(
      resolveAudioNotificationPayload(
        'weather-friend://briefing-audio?city=seoul',
        date: '2026-06-10',
      ),
      isNull,
    );
  });
}
