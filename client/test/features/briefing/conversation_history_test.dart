import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
