import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/core/services/fcm_service.dart';

void main() {
  test('parses an audio briefing data payload', () {
    final notification = RemoteBriefingNotification.fromData({
      'kind': 'audio_briefing',
      'title': '지훈',
      'body': '아가씨, 오늘은 우산을 챙기셔야 합니다.',
      'audio_url': 'https://example.com/jihoon.mp3',
    });

    expect(notification?.title, '지훈');
    expect(notification?.audioUrl, 'https://example.com/jihoon.mp3');
  });

  test('rejects incomplete or unrelated payloads', () {
    expect(
      RemoteBriefingNotification.fromData({
        'kind': 'text_briefing',
        'title': '지훈',
        'body': '본문',
        'audio_url': 'https://example.com/jihoon.mp3',
      }),
      isNull,
    );
    expect(
      RemoteBriefingNotification.fromData({
        'kind': 'audio_briefing',
        'title': '지훈',
        'body': '본문',
      }),
      isNull,
    );
  });
}
