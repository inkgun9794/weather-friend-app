import 'package:flutter/material.dart';
import 'package:weather_friend/app/theme/app_dimens.dart';
import 'package:weather_friend/app/theme/app_type.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/briefing/domain/outfit_guide.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/shared/widgets/weather_icons.dart';

class OutfitRecommendationSection extends StatelessWidget {
  const OutfitRecommendationSection({
    required this.guide,
    required this.characterId,
    this.rainPhase = RainPhase.none,
    super.key,
  });

  final OutfitGuide guide;
  final CharacterId characterId;

  /// 비 소식 + 시간대 — none이 아니면 옷 셀 끝에 우산이 붙고,
  /// day=해 / night=달 배지가 우산 위에 얹힌다 (allDay는 우산만).
  final RainPhase rainPhase;

  @override
  Widget build(BuildContext context) {
    final wearItems = outfitWearFor(guide, rainy: rainPhase != RainPhase.none);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('오늘의 옷 추천', style: AppType.label.copyWith(color: AppColors.ink)),
        const SizedBox(height: AppSpace.md),
        // 아이콘과 라벨이 한 셀 — 글·그림이 따로 놀지 않도록 항목당 하나로 묶는다.
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final item in wearItems)
              _WearCell(
                item: item,
                // 우산 셀에만 시간대 배지(해/달)를 얹는다.
                badge: identical(item, kUmbrellaItem) ? rainPhase : RainPhase.none,
              ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          // 문장 단위로 줄을 끊는다 — 한 줄로 흘리면 칼럼 폭에 따라
          // "준비하시지/요." 같은 고아 글자가 생긴다.
          outfitMessageForCharacter(characterId, guide).replaceAll('. ', '.\n'),
          style: AppType.caption.copyWith(color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

/// 옷 추천 한 셀 — 배경 없이 아이콘 + 그 아래 옷 이름 라벨.
class _WearCell extends StatelessWidget {
  const _WearCell({required this.item, this.badge = RainPhase.none});

  final OutfitItem item;

  /// 우산 셀이면 시간대 배지(day=해, night=달). 그 외엔 none.
  final RainPhase badge;

  @override
  Widget build(BuildContext context) {
    // 우산 셀의 시간대 배지 — 기존 날씨 아이콘 에셋(해/달)을 그대로 쓴다.
    final badgeGlyph = switch (badge) {
      RainPhase.day => WeatherGlyph.sunny,
      RainPhase.night => WeatherGlyph.night,
      _ => null,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          // 배지가 우산 모서리 밖으로 살짝 걸치도록 clip 해제.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Image.asset(item.asset, fit: BoxFit.contain),
              ),
              if (badgeGlyph != null)
                Positioned(
                  top: -2,
                  right: -2,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: Image.asset(
                      weatherGlyphAsset(badgeGlyph),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          item.label,
          style: AppType.micro2.copyWith(color: AppColors.inkMute),
        ),
      ],
    );
  }
}
