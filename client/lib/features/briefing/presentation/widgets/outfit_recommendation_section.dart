import 'package:flutter/material.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/briefing/domain/outfit_guide.dart';
import 'package:weather_friend/features/character/domain/character.dart';

class OutfitRecommendationSection extends StatelessWidget {
  const OutfitRecommendationSection({
    required this.guide,
    required this.characterId,
    this.rainy = false,
    super.key,
  });

  final OutfitGuide guide;
  final CharacterId characterId;

  /// 비 소식 여부 — true면 옷 셀 끝에 우산이 추가된다.
  final bool rainy;

  @override
  Widget build(BuildContext context) {
    final visual = visualFor(characterId);
    final wearItems = outfitWearFor(guide, rainy: rainy);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '오늘의 옷 추천',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 11),
        // 아이콘과 라벨이 한 셀 — 글·그림이 따로 놀지 않도록 항목당 하나로 묶는다.
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (final item in wearItems)
              _WearCell(item: item, tint: visual.colorSoft),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          // 문장 단위로 줄을 끊는다 — 한 줄로 흘리면 칼럼 폭에 따라
          // "준비하시지/요." 같은 고아 글자가 생긴다.
          outfitMessageForCharacter(
            characterId,
            guide,
          ).replaceAll('. ', '.\n'),
          style: TextStyle(
            color: AppColors.inkSoft,
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

/// 옷 추천 한 셀 — 아이콘 타일 아래 옷 이름 라벨.
/// 우산 셀만 옅은 하늘색 배경으로 비 소식임을 드러낸다.
class _WearCell extends StatelessWidget {
  const _WearCell({required this.item, required this.tint});

  final OutfitItem item;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final isUmbrella = item.asset == kUmbrellaAsset;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isUmbrella ? const Color(0xFFE4EFFC) : tint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.asset(item.asset, fit: BoxFit.contain),
        ),
        const SizedBox(height: 4),
        Text(
          item.label,
          style: TextStyle(
            color: AppColors.inkMute,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}
