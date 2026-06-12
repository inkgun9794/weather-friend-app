import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/features/briefing/domain/outfit_guide.dart';
import 'package:weather_friend/features/briefing/presentation/widgets/outfit_recommendation_section.dart';
import 'package:weather_friend/features/character/domain/character.dart';

Finder _assetImage(String assetName) => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == assetName,
);

Widget _host(OutfitRecommendationSection section) {
  return MaterialApp(home: Scaffold(body: section));
}

void main() {
  testWidgets('renders one labelled icon cell per recommended garment', (
    tester,
  ) async {
    final guide = outfitGuideFor(27);

    await tester.pumpWidget(
      _host(
        OutfitRecommendationSection(
          guide: guide,
          characterId: CharacterId.jiyoung,
        ),
      ),
    );

    expect(find.text('오늘의 옷 추천'), findsOneWidget);
    expect(find.byIcon(Icons.checkroom_rounded), findsNothing);
    expect(find.byType(Image), findsNWidgets(guide.wear.length));
    // 아이콘마다 옷 이름 라벨이 한 쌍으로 붙는다.
    for (final item in guide.wear) {
      expect(find.text(item.label), findsOneWidget);
      expect(_assetImage(item.asset), findsOneWidget);
    }
    expect(find.text('통풍이 잘 되는 옷을 입고, 실내에선 에어컨을 대비해 겉옷을 챙겨봐.'), findsOneWidget);
    expect(find.text('우산'), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('breaks the message into one line per sentence', (tester) async {
    await tester.pumpWidget(
      _host(
        OutfitRecommendationSection(
          guide: outfitGuideFor(23),
          characterId: CharacterId.jihoon,
        ),
      ),
    );

    expect(
      find.text('아가씨, 따뜻한 날입니다.\n얇고 통풍이 잘되는 옷차림으로 준비하시지요.'),
      findsOneWidget,
    );
  });

  testWidgets('appends a labelled umbrella cell when it is rainy', (
    tester,
  ) async {
    final guide = outfitGuideFor(10);

    await tester.pumpWidget(
      _host(
        OutfitRecommendationSection(
          guide: guide,
          characterId: CharacterId.sohee,
          rainy: true,
        ),
      ),
    );

    expect(find.byType(Image), findsNWidgets(guide.wear.length + 1));
    expect(find.text('우산'), findsOneWidget);
    expect(_assetImage(kUmbrellaAsset), findsOneWidget);
  });
}
