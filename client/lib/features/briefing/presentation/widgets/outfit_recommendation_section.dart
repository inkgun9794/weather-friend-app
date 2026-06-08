import 'package:flutter/material.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/briefing/domain/outfit_guide.dart';

class OutfitRecommendationSection extends StatelessWidget {
  const OutfitRecommendationSection({
    required this.guide,
    required this.sky,
    super.key,
  });

  final OutfitGuide guide;
  final SkyPalette sky;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: sky.ink.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.checkroom_rounded, color: sky.ink, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guide.items.join(' · '),
                  style: TextStyle(
                    color: sky.ink,
                    fontSize: 13.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  guide.message,
                  style: TextStyle(
                    color: sky.inkSoft,
                    fontSize: 11.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
