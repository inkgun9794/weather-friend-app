import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/features/chat/domain/chat_message.dart';

void main() {
  test('ChatMessage round-trips through json', () {
    final original = ChatMessage(
      id: 'message-1',
      sender: ChatSender.character,
      text: '오늘은 산책하기 좋겠다.',
      createdAt: DateTime.utc(2026, 6, 8, 4, 30),
      kind: ChatMessageKind.briefing,
      audioUrl: 'https://example.com/audio.mp3',
      isAttentionNudge: true,
    );

    final restored = ChatMessage.fromJson(original.toJson());

    expect(restored, isNotNull);
    expect(restored!.id, original.id);
    expect(restored.sender, original.sender);
    expect(restored.text, original.text);
    expect(restored.createdAt, original.createdAt);
    expect(restored.kind, ChatMessageKind.briefing);
    expect(restored.audioUrl, original.audioUrl);
    expect(restored.isAttentionNudge, isTrue);
  });

  test('old json defaults to a conversation message', () {
    final restored = ChatMessage.fromJson({
      'id': 'legacy',
      'sender': 'user',
      'text': '예전 메시지',
      'createdAt': '2026-06-08T12:00:00.000',
    });

    expect(restored, isNotNull);
    expect(restored!.kind, ChatMessageKind.conversation);
    expect(restored.isAttentionNudge, isFalse);
  });
}
