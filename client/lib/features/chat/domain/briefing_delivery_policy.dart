import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/chat/domain/chat_message.dart';

const activeConversationWindow = Duration(minutes: 10);

enum BriefingDelivery { deliverNow, deliverWithTransition, defer, skip }

BriefingDelivery decideBriefingDelivery({
  required Briefing briefing,
  required List<ChatMessage> messages,
  required DateTime now,
}) {
  if (!isConversationActive(messages, now)) {
    return BriefingDelivery.deliverNow;
  }
  if (briefing.type == BriefingType.casual) {
    return BriefingDelivery.skip;
  }
  if (isImportantWeatherBriefing(briefing)) {
    return BriefingDelivery.deliverWithTransition;
  }
  return BriefingDelivery.defer;
}

bool isConversationActive(List<ChatMessage> messages, DateTime now) {
  final latest = messages
      .where(
        (message) =>
            message.kind == ChatMessageKind.conversation &&
            (message.sender == ChatSender.user ||
                message.sender == ChatSender.character),
      )
      .lastOrNull;
  if (latest == null) return false;

  final elapsed = now.difference(latest.createdAt);
  return !elapsed.isNegative && elapsed < activeConversationWindow;
}

DateTime? latestConversationActivity(List<ChatMessage> messages) => messages
    .where((message) => message.kind == ChatMessageKind.conversation)
    .lastOrNull
    ?.createdAt;

bool isImportantWeatherBriefing(Briefing briefing) {
  final weather = briefing.weatherSnapshot;
  if (weather == null) return false;

  final condition = weather.condition;
  final severeCondition = const [
    '비',
    '눈',
    '폭우',
    '폭설',
    '소나기',
    '뇌우',
    '태풍',
    '우박',
  ].any(condition.contains);

  return severeCondition ||
      weather.precipitationProb >= 70 ||
      weather.feelsLikeC <= -5 ||
      weather.feelsLikeC >= 33 ||
      weather.windSpeedKmh >= 35;
}

bool messageInvitesReply(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) return false;
  if (normalized.contains('?')) return true;

  return const [
    '뭐 해',
    '뭐해',
    '먹었어',
    '봤어',
    '가봤어',
    '해봤어',
    '어때',
    '어땠어',
    '괜찮아',
    '무슨 일 있어',
    '답해줘',
    '말해줘',
  ].any(normalized.contains);
}
