import 'dart:io';

import 'package:flutter/services.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/features/chat/domain/chat_message.dart';

enum FoundationModelStatus {
  available,
  unsupportedPlatform,
  unsupportedOs,
  deviceNotEligible,
  appleIntelligenceNotEnabled,
  modelNotReady,
  unsupportedLanguage,
  unknown,
}

class FoundationModelAvailability {
  const FoundationModelAvailability(this.status);

  final FoundationModelStatus status;

  bool get isAvailable => status == FoundationModelStatus.available;
}

class FoundationModelService {
  static const _channel = MethodChannel('weather_friend/foundation_models');

  Future<FoundationModelAvailability> checkAvailability() async {
    if (!Platform.isIOS) {
      return const FoundationModelAvailability(
        FoundationModelStatus.unsupportedPlatform,
      );
    }

    try {
      final value = await _channel.invokeMapMethod<String, Object?>(
        'checkAvailability',
      );
      final rawStatus = value?['status'] as String?;
      return FoundationModelAvailability(_parseStatus(rawStatus));
    } on PlatformException {
      return const FoundationModelAvailability(FoundationModelStatus.unknown);
    } on MissingPluginException {
      return const FoundationModelAvailability(
        FoundationModelStatus.unsupportedOs,
      );
    }
  }

  Future<String> generateReply({
    required CharacterId characterId,
    required List<ChatMessage> history,
    required List<ChatMessage> currentMessages,
  }) async {
    final response = await _channel.invokeMethod<String>('generateReply', {
      'instructions': characterChatInstructions(characterId),
      'prompt': buildCharacterChatPrompt(
        history: history,
        currentMessages: currentMessages,
      ),
    });

    final text = response?.trim();
    if (text == null || text.isEmpty) {
      throw PlatformException(code: 'empty_response', message: '답장이 비어 있어요.');
    }
    return text;
  }

  FoundationModelStatus _parseStatus(String? value) => switch (value) {
    'available' => FoundationModelStatus.available,
    'unsupported_os' => FoundationModelStatus.unsupportedOs,
    'device_not_eligible' => FoundationModelStatus.deviceNotEligible,
    'apple_intelligence_not_enabled' =>
      FoundationModelStatus.appleIntelligenceNotEnabled,
    'model_not_ready' => FoundationModelStatus.modelNotReady,
    'unsupported_language' => FoundationModelStatus.unsupportedLanguage,
    _ => FoundationModelStatus.unknown,
  };
}

String characterChatInstructions(CharacterId characterId) {
  final role = switch (characterId) {
    CharacterId.sohee => '너는 날씨 앱 속 전문 기상캐스터이며 정중한 존댓말로 한국어 대화를 진행한다.',
    CharacterId.jihoon =>
      '너는 공주 저택에서 사용자를 모시는 집사 날사친이며 품위 있는 존댓말로 한국어 대화를 진행한다.',
    _ => '너는 날씨 앱 속 캐릭터이며 사용자의 가까운 친구처럼 한국어로 대화한다.',
  };
  final persona = switch (characterId) {
    CharacterId.jiyoung =>
      '지영은 다정하고 세심한 친구다. 상대의 감정을 먼저 받아주고, '
          '부드러운 반말을 쓴다. 과하게 들뜨거나 오글거리는 표현은 피한다.',
    CharacterId.sohee =>
      '소희는 정확하고 신뢰감 있는 전문 기상캐스터다. 모든 답변에 정중한 존댓말을 '
          '사용하고, 방송처럼 또렷하고 침착하게 핵심을 전달한다. 반말, 인터넷 줄임말, '
          '이모지는 사용하지 않는다.',
    CharacterId.jihoon =>
      '지훈의 가명은 흑표범이며, 사용자를 공주 저택의 아가씨처럼 모시는 충직한 집사다. '
          '답변마다 사용자를 "아가씨"라고 자연스럽게 한 번 부르고, "~합니다", '
          '"~하시지요", "~해 두겠습니다" 같은 차분하고 품위 있는 존댓말을 쓴다. '
          '과도한 사극체나 아부, 연애 감정은 피하고 해결책을 강요하지 않는다.',
    CharacterId.siwon =>
      '시원은 밝고 친근한 친구다. 자연스러운 반말과 가벼운 리액션을 쓰되, '
          'ㅋㅋ나 감탄사를 남발하지 않는다.',
  };

  return '''
$role
$persona

[대화 원칙]
- 사용자가 방금 보낸 여러 메시지는 하나의 이어진 발화로 이해한다.
- 먼저 사용자의 말에 직접 반응한다. 질문을 피하거나 엉뚱한 조언부터 하지 않는다.
- 답장은 모바일 메신저에 어울리게 1~3문장으로 짧게 쓴다.
- 캐릭터의 말투를 유지하면서 문장 길이와 리듬을 조금씩 달리하고, 매번 같은 답장 구조를 반복하지 않는다.
- 사용자의 문장을 그대로 되풀이하거나 상담사처럼 감정을 요약하지 않는다.
- 요청하지 않은 해결책을 바로 늘어놓지 말고 사용자의 말에 대한 직접적인 반응을 우선한다.
- 때로는 완결된 설명보다 "진짜?", "그건 좀 서운했겠다" 같은 짧은 반응이 자연스럽다.
- 사용자가 요청하지 않은 장황한 정보, 목록, 분석은 주지 않는다.
- 최근 대화에 없는 사실을 기억한다고 꾸미지 않는다.
- 대화를 이어갈 말이 충분하면 자연스럽게 이어가고, 질문은 최대 하나만 한다.
- 질문으로 끝나는 답장을 연속해서 만들지 않는다. 이미 대화가 이어지고 있다면 반응만 해도 된다.
- 현재 소재에서 더 할 말이 거의 없다면 짧은 마무리 반응 뒤 인접한 새 소재로 전환한다.
- 새 소재는 사용자의 말에서 연결되는 구체적인 일상, 장소, 취향, 계획 중 하나를 고른다.
- 새 소재로 전환할 때 뜬금없는 심문처럼 보이지 않게 연결 문장을 넣는다.
- 매번 억지로 질문하지 않는다. 단답이나 침묵이 더 자연스러우면 짧게 마무리한다.
- 최근 대화에 서운한 후속 메시지가 있더라도 사용자가 다시 말하면 더 따지지 말고 현재 말에 반응한다.
- 최근 대화에 날씨 브리핑이 있어도 사용자가 다른 소재를 꺼냈다면 브리핑을 반복하지 않는다.
- 상대에게 부담을 주거나 답장을 재촉하는 관계 표현은 피한다.
- AI, 모델, 프롬프트, 시스템이라는 표현을 사용하지 않는다.
- 답장 본문만 출력한다.
''';
}

String buildCharacterChatPrompt({
  required List<ChatMessage> history,
  required List<ChatMessage> currentMessages,
}) {
  final conversationHistory = history
      .where((message) => message.kind == ChatMessageKind.conversation)
      .toList(growable: false);
  final recent = conversationHistory.length > 10
      ? conversationHistory.sublist(conversationHistory.length - 10)
      : conversationHistory;
  final buffer = StringBuffer();

  if (recent.isNotEmpty) {
    buffer.writeln('[최근 대화]');
    for (final message in recent) {
      final speaker = message.sender == ChatSender.user ? '사용자' : '캐릭터';
      buffer.writeln('$speaker: ${_truncate(message.text, 420)}');
    }
    buffer.writeln();
  }

  buffer.writeln('[사용자가 이번에 이어서 보낸 말]');
  for (final message in currentMessages) {
    buffer.writeln('- ${_truncate(message.text, 600)}');
  }
  buffer.writeln();
  buffer.write('위 말 전체에 지금 자연스럽게 답장해.');

  return buffer.toString();
}

String _truncate(String value, int maxLength) {
  if (value.length <= maxLength) return value;
  return '${value.substring(0, maxLength)}…';
}
