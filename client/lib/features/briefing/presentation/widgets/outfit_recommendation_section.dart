import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/briefing/domain/outfit_guide.dart';

class OutfitRecommendationSection extends StatelessWidget {
  const OutfitRecommendationSection({
    required this.temperature,
    required this.guide,
    required this.sky,
    super.key,
  });

  final int temperature;
  final OutfitGuide guide;
  final SkyPalette sky;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter.grouped(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: sky.ink.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.checkroom_rounded,
                    color: sky.ink,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘의 옷 추천',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '체감 $temperature° · ${guide.title}',
                        style: TextStyle(
                          color: AppColors.inkMute,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        guide.items.join(' · '),
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        guide.message,
                        style: TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 12,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
