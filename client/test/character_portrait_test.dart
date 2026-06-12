import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/shared/widgets/character_portrait.dart';

void main() {
  testWidgets('uses the bundled character portrait without an initial', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CharacterPortrait(
            charId: CharacterId.jihoon,
            enableTapToExpand: false,
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      image.image,
      const AssetImage('assets/characters/jihoon/portrait.png'),
    );
    final portraitBytes = await rootBundle.load(
      'assets/characters/jihoon/portrait.png',
    );
    expect(portraitBytes.lengthInBytes, greaterThan(0));
    expect(find.text('ㅈ'), findsNothing);
  });
}
