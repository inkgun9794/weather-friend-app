import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/features/chat/data/chat_repository.dart';
import 'package:weather_friend/features/chat/domain/chat_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists a pending unanswered nudge', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ChatRepository(prefs);
    final dueAt = DateTime(2026, 6, 8, 14, 45);

    await repository.savePendingNudge(
      CharacterId.sohee,
      PendingChatNudge(messageId: 'reply-1', dueAt: dueAt),
    );

    final restored = repository.loadPendingNudge(CharacterId.sohee);
    expect(restored, isNotNull);
    expect(restored!.messageId, 'reply-1');
    expect(restored.dueAt, dueAt);

    await repository.clearPendingNudge(CharacterId.sohee);
    expect(repository.loadPendingNudge(CharacterId.sohee), isNull);
  });

  test('persists deferred briefings', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ChatRepository(prefs);
    final dueAt = DateTime(2026, 6, 8, 14, 10);
    final message = ChatMessage(
      id: 'briefing-1',
      sender: ChatSender.character,
      text: '오후에는 조금 더워질 거야.',
      createdAt: DateTime(2026, 6, 8, 14),
      kind: ChatMessageKind.briefing,
    );

    await repository.saveDeferredBriefings(CharacterId.jiyoung, [
      DeferredChatBriefing(message: message, dueAt: dueAt),
    ]);

    final restored = repository.loadDeferredBriefings(CharacterId.jiyoung);
    expect(restored, hasLength(1));
    expect(restored.single.message.id, message.id);
    expect(restored.single.message.text, message.text);
    expect(restored.single.dueAt, dueAt);

    await repository.saveDeferredBriefings(CharacterId.jiyoung, const []);
    expect(repository.loadDeferredBriefings(CharacterId.jiyoung), isEmpty);
  });

  test('persists suppressed briefing ids', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ChatRepository(prefs);

    await repository.saveSuppressedBriefingIds(CharacterId.siwon, {
      'briefing-1',
      'briefing-2',
    });

    expect(repository.loadSuppressedBriefingIds(CharacterId.siwon), {
      'briefing-1',
      'briefing-2',
    });
  });
}
