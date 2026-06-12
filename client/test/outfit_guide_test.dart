import 'dart:io';

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
      '더운 날씨가 이어지겠습니다. 통풍이 잘되는 옷을 입고 얇은 겉옷도 준비해 주세요.',
    );
    expect(
      outfitMessageForCharacter(CharacterId.jihoon, guide),
      '아가씨, 통풍이 잘되는 옷이 알맞겠습니다. 실내 냉방에 대비해 얇은 겉옷도 챙기십시오.',
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

  test('every guide maps wear cells with short labels and real images', () {
    for (final guide in outfitGuides) {
      expect(guide.wear, isNotEmpty, reason: guide.key);
      expect(
        guide.wear.length,
        lessThanOrEqualTo(5),
        reason: '${guide.key}: 셀은 5칸까지(비 오면 우산까지 6칸)가 한계',
      );
      final labels = guide.wear.map((w) => w.label).toList();
      expect(labels.toSet(), hasLength(labels.length), reason: guide.key);
      for (final item in guide.wear) {
        expect(item.label, isNotEmpty, reason: guide.key);
        expect(
          item.label.length,
          lessThanOrEqualTo(5),
          reason: '${guide.key}: "${item.label}" — 라벨은 수식어 없이 짧게',
        );
        expect(
          File(item.asset).existsSync(),
          isTrue,
          reason: '${guide.key}: ${item.asset} 에셋이 없다',
        );
      }
    }
    expect(File(kUmbrellaAsset).existsSync(), isTrue);
  });

  test('appends umbrella cell only on rainy days', () {
    final guide = outfitGuideFor(10);
    expect(outfitWearFor(guide), guide.wear);
    expect(outfitWearFor(guide, rainy: true), [...guide.wear, kUmbrellaItem]);
  });

  test('umbrellaNeeded follows rainy conditions and precipitation odds', () {
    expect(umbrellaNeeded(condition: '비'), isTrue);
    expect(umbrellaNeeded(condition: '약한 이슬비'), isTrue);
    expect(umbrellaNeeded(condition: '강한 소나기'), isTrue);
    expect(umbrellaNeeded(condition: '천둥번개'), isTrue);
    expect(umbrellaNeeded(condition: '눈'), isFalse);
    expect(umbrellaNeeded(condition: '맑음'), isFalse);
    expect(umbrellaNeeded(condition: null), isFalse);
    expect(umbrellaNeeded(condition: '맑음', precipitationProb: 60), isTrue);
    expect(umbrellaNeeded(condition: '흐림', precipitationProb: 59), isFalse);
  });
}
