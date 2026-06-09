import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/features/chat/data/foundation_model_service.dart';
import 'package:weather_friend/features/chat/domain/chat_message.dart';

void main() {
  group('characterChatInstructions', () {
    test('keeps each character tone distinct', () {
      expect(
        characterChatInstructions(CharacterId.jiyoung),
        contains('다정하고 세심한'),
      );
      expect(
        characterChatInstructions(CharacterId.sohee),
        contains('전문 기상캐스터'),
      );
      expect(characterChatInstructions(CharacterId.sohee), contains('정중한 존댓말'));
      expect(
        characterChatInstructions(CharacterId.jihoon),
        contains('가명은 흑표범'),
      );
      expect(characterChatInstructions(CharacterId.jihoon), contains('아가씨'));
      expect(
        characterChatInstructions(CharacterId.jihoon),
        contains('품위 있는 존댓말'),
      );
      expect(characterChatInstructions(CharacterId.siwon), contains('밝고 친근한'));
    });

    test('includes the natural topic transition rule', () {
      final instructions = characterChatInstructions(CharacterId.jiyoung);

      expect(instructions, contains('짧은 마무리 반응 뒤 인접한 새 소재로 전환'));
      expect(instructions, contains('질문은 최대 하나'));
      expect(instructions, contains('매번 같은 답장 구조를 반복하지 않는다'));
      expect(instructions, contains('질문으로 끝나는 답장을 연속해서 만들지 않는다'));
      expect(instructions, contains('상대에게 부담을 주거나 답장을 재촉'));
      expect(instructions, isNot(contains('위협')));
    });
  });

  test('buildCharacterChatPrompt groups split user messages', () {
    final now = DateTime(2026, 6, 8, 12);
    final prompt = buildCharacterChatPrompt(
      history: [
        ChatMessage(
          id: '1',
          sender: ChatSender.user,
          text: '어제는 비가 왔어.',
          createdAt: now,
        ),
        ChatMessage(
          id: '2',
          sender: ChatSender.character,
          text: '우산은 챙겼어?',
          createdAt: now,
        ),
      ],
      currentMessages: [
        ChatMessage(
          id: '3',
          sender: ChatSender.user,
          text: '오늘 날씨 정말 좋더라!',
          createdAt: now,
        ),
        ChatMessage(
          id: '4',
          sender: ChatSender.user,
          text: '퇴근하고 걸을까 봐.',
          createdAt: now,
        ),
      ],
    );

    expect(prompt, contains('[최근 대화]'));
    expect(prompt, contains('캐릭터: 우산은 챙겼어?'));
    expect(prompt, contains('- 오늘 날씨 정말 좋더라!'));
    expect(prompt, contains('- 퇴근하고 걸을까 봐.'));
  });

  test(
    'buildCharacterChatPrompt excludes briefings and nudges from history',
    () {
      final now = DateTime(2026, 6, 9, 9);
      final prompt = buildCharacterChatPrompt(
        history: [
          ChatMessage(
            id: 'briefing',
            sender: ChatSender.character,
            text: '오늘 브리핑 문구',
            createdAt: now,
            kind: ChatMessageKind.briefing,
          ),
          ChatMessage(
            id: 'nudge',
            sender: ChatSender.character,
            text: '답장을 재촉하는 후속 문구',
            createdAt: now,
            kind: ChatMessageKind.nudge,
          ),
          ChatMessage(
            id: 'conversation',
            sender: ChatSender.character,
            text: '영화 기대돼?',
            createdAt: now,
          ),
        ],
        currentMessages: [
          ChatMessage(
            id: 'user',
            sender: ChatSender.user,
            text: '조금 기대되긴 하네.',
            createdAt: now,
          ),
        ],
      );

      expect(prompt, contains('캐릭터: 영화 기대돼?'));
      expect(prompt, isNot(contains('오늘 브리핑 문구')));
      expect(prompt, isNot(contains('답장을 재촉하는 후속 문구')));
    },
  );
}
