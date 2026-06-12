import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/app/router/main_shell.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/briefing/presentation/conversation_screen.dart';

class _FakeTodayBriefings extends TodayBriefingsNotifier {
  @override
  Future<Map<int, Briefing>> build() async => const {};

  @override
  Future<void> refresh() async {}
}

void main() {
  testWidgets('shows local history without a messages title', (tester) async {
    const previousBriefing = Briefing(
      city: 'seoul',
      date: '2025-01-01',
      hour: 11,
      characterId: 'jiyoung',
      type: BriefingType.hourly,
      transcript: '로컬에 남아 있던 이전 메시지',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kstHourProvider.overrideWith((ref) => Stream.value(12)),
          todayBriefingsProvider.overrideWith(_FakeTodayBriefings.new),
          briefingHistoryProvider.overrideWithValue([previousBriefing]),
        ],
        child: const MaterialApp(home: ConversationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('메세지'), findsNothing);
    expect(find.text(previousBriefing.transcript), findsOneWidget);
    expect(find.text('1월 1일 수요일'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(ListView)).dy,
      lessThan(kToolbarHeight),
    );
  });

  testWidgets('message tab selection scrolls history to the latest item', (
    tester,
  ) async {
    final history = List.generate(
      24,
      (index) => Briefing(
        city: 'seoul',
        date: '2025-01-01',
        hour: index,
        characterId: 'jiyoung',
        type: BriefingType.hourly,
        transcript: '메시지 $index',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kstHourProvider.overrideWith((ref) => Stream.value(12)),
          todayBriefingsProvider.overrideWith(_FakeTodayBriefings.new),
          briefingHistoryProvider.overrideWithValue(history),
        ],
        child: const MaterialApp(home: ConversationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(
      scrollable.position.pixels,
      moreOrLessEquals(scrollable.position.maxScrollExtent),
    );

    scrollable.position.jumpTo(0);
    await tester.pump();
    expect(scrollable.position.pixels, 0);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ConversationScreen)),
    );
    container.read(messageTabSelectionProvider.notifier).select();
    await tester.pumpAndSettle();

    expect(
      scrollable.position.pixels,
      moreOrLessEquals(scrollable.position.maxScrollExtent),
    );
  });
}
