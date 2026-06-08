import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/features/briefing/domain/outfit_guide.dart';

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
}
