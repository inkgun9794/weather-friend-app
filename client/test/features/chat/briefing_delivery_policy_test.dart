import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/chat/domain/briefing_delivery_policy.dart';
import 'package:weather_friend/features/chat/domain/chat_message.dart';

void main() {
  final now = DateTime(2026, 6, 8, 14);

  ChatMessage conversationMessage({
    required ChatSender sender,
    required DateTime createdAt,
  }) => ChatMessage(
    id: '${sender.name}-${createdAt.microsecondsSinceEpoch}',
    sender: sender,
    text: sender == ChatSender.user ? '오늘 산책 갈까?' : '좋지. 어디로 갈래?',
    createdAt: createdAt,
  );

  Briefing briefing({
    BriefingType type = BriefingType.hourly,
    String condition = '맑음',
    int precipitationProb = 10,
    double feelsLikeC = 25,
    double windSpeedKmh = 8,
  }) => Briefing(
    city: 'seoul',
    date: '2026-06-08',
    hour: 14,
    characterId: 'jiyoung',
    type: type,
    transcript: '오후에는 맑고 따뜻할 거야.',
    weatherSnapshot: WeatherSnapshot(
      temperatureC: 24,
      feelsLikeC: feelsLikeC,
      condition: condition,
      precipitationProb: precipitationProb,
      windSpeedKmh: windSpeedKmh,
      humidity: 55,
    ),
  );

  test('delivers normally when the conversation is inactive', () {
    final delivery = decideBriefingDelivery(
      briefing: briefing(),
      messages: [
        conversationMessage(
          sender: ChatSender.user,
          createdAt: now.subtract(const Duration(minutes: 11)),
        ),
      ],
      now: now,
    );

    expect(delivery, BriefingDelivery.deliverNow);
  });

  test('skips casual briefing during an active conversation', () {
    final delivery = decideBriefingDelivery(
      briefing: briefing(type: BriefingType.casual),
      messages: [
        conversationMessage(
          sender: ChatSender.character,
          createdAt: now.subtract(const Duration(minutes: 2)),
        ),
      ],
      now: now,
    );

    expect(delivery, BriefingDelivery.skip);
  });

  test('defers ordinary weather during an active conversation', () {
    final delivery = decideBriefingDelivery(
      briefing: briefing(),
      messages: [
        conversationMessage(
          sender: ChatSender.user,
          createdAt: now.subtract(const Duration(minutes: 2)),
        ),
      ],
      now: now,
    );

    expect(delivery, BriefingDelivery.defer);
  });

  test('interrupts naturally for important weather', () {
    final delivery = decideBriefingDelivery(
      briefing: briefing(condition: '강한 비'),
      messages: [
        conversationMessage(
          sender: ChatSender.character,
          createdAt: now.subtract(const Duration(minutes: 2)),
        ),
      ],
      now: now,
    );

    expect(delivery, BriefingDelivery.deliverWithTransition);
  });

  test('only reply-inviting messages start an unanswered sequence', () {
    expect(messageInvitesReply('오늘 날씨 좋더라.'), isFalse);
    expect(messageInvitesReply('오늘 산책 가봤어?'), isTrue);
    expect(messageInvitesReply('나중에라도 말해줘.'), isTrue);
  });
}
