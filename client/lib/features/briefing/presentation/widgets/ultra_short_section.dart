import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';

/// "초단기 6시간" 카드 — 오늘 날씨 섹션 위에 표시.
///
/// 데이터 출처는 KMA 초단기예보 (kma_ultra Firestore 캐시, 매 30분 갱신).
/// OpenMeteo 폴백 시엔 [WeatherBundle.ultraShort] 가 null이라 자동 숨김.
class UltraShortSection extends ConsumerWidget {
  const UltraShortSection({super.key, required this.sky});

  final SkyPalette sky;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleAsync = ref.watch(weatherBundleProvider);
    final ultra = bundleAsync.whenOrNull(data: (b) => b.ultraShort);

    if (ultra == null || ultra.hours.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter.grouped(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: sky.ink, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '초단기 6시간',
                        style: TextStyle(
                          color: sky.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '매 30분 갱신',
                        style: TextStyle(
                          color: sky.ink.withValues(alpha: 0.55),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '기상청 초단기 예보로 다음 6시간을 더 정밀하게',
                    style: TextStyle(
                      color: sky.ink.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: ultra.hours.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (_, i) =>
                          _UltraSlot(hour: ultra.hours[i], sky: sky),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UltraSlot extends StatelessWidget {
  const _UltraSlot({required this.hour, required this.sky});

  final HourlyWeather hour;
  final SkyPalette sky;

  @override
  Widget build(BuildContext context) {
    final isRain = hour.precipitationProb > 0;
    final icon = switch (hour.condition) {
      '비' || '소나기' => Icons.umbrella_rounded,
      '비/눈' => Icons.ac_unit_rounded,
      '눈' => Icons.ac_unit_rounded,
      '흐림' => Icons.cloud_rounded,
      '구름많음' => Icons.cloud_queue_rounded,
      _ => Icons.wb_sunny_rounded,
    };

    return SizedBox(
      width: 48,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${hour.hour}시',
            style: TextStyle(
              color: sky.ink.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Icon(
            icon,
            color: isRain
                ? sky.ink
                : sky.ink.withValues(alpha: 0.85),
            size: 22,
          ),
          const SizedBox(height: 8),
          Text(
            '${hour.temperatureC.round()}°',
            style: TextStyle(
              color: sky.ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
