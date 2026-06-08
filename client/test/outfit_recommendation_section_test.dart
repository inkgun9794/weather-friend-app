import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/features/briefing/domain/outfit_guide.dart';
import 'package:weather_friend/features/briefing/presentation/widgets/outfit_recommendation_section.dart';
import 'package:weather_friend/features/character/domain/character.dart';

void main() {
  testWidgets('renders an inline text-only outfit recommendation', (
    tester,
  ) async {
    final guide = outfitGuideFor(27);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OutfitRecommendationSection(
            guide: guide,
            characterId: CharacterId.jiyoung,
          ),
        ),
      ),
    );

    expect(find.text('오늘의 옷 추천'), findsOneWidget);
    expect(find.byIcon(Icons.checkroom_rounded), findsOneWidget);
    expect(find.text('반팔 · 민소매 · 반바지 · 린넨'), findsOneWidget);
    expect(find.text('통풍이 잘 되는 옷을 입고, 실내에선 에어컨을 대비해 겉옷을 챙겨봐.'), findsOneWidget);
    expect(find.textContaining('체감 27°'), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.text('더보기'), findsNothing);
  });
}
