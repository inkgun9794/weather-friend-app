import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/briefing/domain/outfit_guide.dart';
import 'package:weather_friend/features/briefing/presentation/widgets/outfit_recommendation_section.dart';

void main() {
  testWidgets('renders a text-only outfit recommendation', (tester) async {
    final guide = outfitGuideFor(25);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OutfitRecommendationSection(
            temperature: 25,
            guide: guide,
            sky: skyFor(14),
          ),
        ),
      ),
    );

    expect(find.text('오늘의 옷 추천'), findsOneWidget);
    expect(find.text('체감 25° · 따뜻한 날씨'), findsOneWidget);
    expect(find.text(guide.items.join(' · ')), findsOneWidget);
    expect(find.text(guide.message), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.text('더보기'), findsNothing);
  });
}
