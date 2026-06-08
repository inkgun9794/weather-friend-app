import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/features/briefing/domain/outfit_guide.dart';
import 'package:weather_friend/features/character/domain/character.dart';

void main() {
  test('maps every temperature boundary to the expected guide', () {
    expect(outfitGuideFor(-20).key, 'minus5');
    expect(outfitGuideFor(-5).key, 'minus5');
    expect(outfitGuideFor(-4).key, 'minus4_0');
    expect(outfitGuideFor(0).key, 'minus4_0');
    expect(outfitGuideFor(1).key, '1_4');
    expect(outfitGuideFor(4).key, '1_4');
    expect(outfitGuideFor(5).key, '5_8');
    expect(outfitGuideFor(8).key, '5_8');
    expect(outfitGuideFor(9).key, '9_11');
    expect(outfitGuideFor(11).key, '9_11');
    expect(outfitGuideFor(12).key, '12_16');
    expect(outfitGuideFor(16).key, '12_16');
    expect(outfitGuideFor(17).key, '17_19');
    expect(outfitGuideFor(19).key, '17_19');
    expect(outfitGuideFor(20).key, '20_22');
    expect(outfitGuideFor(22).key, '20_22');
    expect(outfitGuideFor(23).key, '23_26');
    expect(outfitGuideFor(26).key, '23_26');
    expect(outfitGuideFor(27).key, '27_plus');
    expect(outfitGuideFor(40).key, '27_plus');
  });

  test('every guide contains concise text recommendations', () {
    for (final guide in outfitGuides) {
      expect(guide.items, isNotEmpty);
      expect(guide.message, isNotEmpty);
    }
  });

  test('uses each character tone for hot-weather recommendations', () {
    final guide = outfitGuideFor(28);

    expect(
      outfitMessageForCharacter(CharacterId.jiyoung, guide),
      '통풍이 잘 되는 옷을 입고, 실내에선 에어컨을 대비해 겉옷을 챙겨봐.',
    );
    expect(
      outfitMessageForCharacter(CharacterId.sohee, guide),
      '통풍 잘되는 거 입고, 에어컨 대비해 얇은 겉옷 챙겨.',
    );
    expect(
      outfitMessageForCharacter(CharacterId.jihoon, guide),
      '통풍이 잘 되는 옷이 적당해. 실내 냉방에 대비해 얇은 겉옷도 챙겨.',
    );
    expect(
      outfitMessageForCharacter(CharacterId.siwon, guide),
      '오늘은 시원한 옷이 딱이야. 얇은 겉옷 하나 챙기면 실내에서도 편하겠어.',
    );
  });

  test('defines a character-specific message for every temperature guide', () {
    for (final guide in outfitGuides) {
      final messages = CharacterId.values
          .map((id) => outfitMessageForCharacter(id, guide))
          .toSet();
      expect(messages, hasLength(CharacterId.values.length));
      expect(messages, isNot(contains(guide.message)));
    }
  });
}
