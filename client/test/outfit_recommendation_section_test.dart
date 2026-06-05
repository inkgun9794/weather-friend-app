import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/briefing/domain/outfit_guide.dart';
import 'package:weather_friend/features/briefing/presentation/widgets/outfit_recommendation_section.dart';

void main() {
  testWidgets('outfit gallery renders without overlapping on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final guide = outfitGuideFor(25);
    final recommendation = guide.options[1];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OutfitRecommendationSection(
            temperature: 25,
            guide: guide,
            recommendation: recommendation,
            sky: skyFor(14),
          ),
        ),
      ),
    );

    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();

    expect(find.text('체감 25° 옷차림'), findsOneWidget);
    expect(find.text('화이트 셔츠 데님'), findsOneWidget);
    expect(find.text('세이지 니트 클린 룩'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
