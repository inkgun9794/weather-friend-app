import 'package:flutter/material.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/briefing/domain/outfit_guide.dart';
import 'package:weather_friend/features/character/domain/character.dart';

class OutfitRecommendationSection extends StatelessWidget {
  const OutfitRecommendationSection({
    required this.guide,
    required this.characterId,
    super.key,
  });

  final OutfitGuide guide;
  final CharacterId characterId;

  @override
  Widget build(BuildContext context) {
    final visual = visualFor(characterId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: visual.colorSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.checkroom_rounded,
                color: visual.colorDeep,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '오늘의 옷 추천',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          guide.items.join(' · '),
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          outfitMessageForCharacter(characterId, guide),
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
