import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/shared/widgets/weather_icons.dart';

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
    final sunrise =
        bundleAsync.whenOrNull(data: (b) => b.sunriseToday);
    final sunset =
        bundleAsync.whenOrNull(data: (b) => b.sunsetToday);

    if (ultra == null || ultra.hours.isEmpty) {
      return const SizedBox.shrink();
    }

    // 발효시각 기준으로 "이미 지나간" 슬롯 제외.
    // Worker cron이 dropped되어 stale 데이터를 받게 되더라도
    // UI 자체에서 항상 현재~미래만 노출 — Firestore 데이터 신뢰도와 무관하게 일관된 UX.
    final now = DateTime.now();
    final visible = <_SlotData>[];
    for (var i = 0; i < ultra.hours.length; i++) {
      // hours[i]는 baseTime + (i+1) hours 시점의 예보.
      final slotTime = ultra.baseTime.add(Duration(hours: i + 1));
      // 슬롯이 끝나는 시각(다음 정시)이 현재보다 미래여야 표시.
      // → 8:32에 "8시" 슬롯은 9:00까지 유효하므로 표시, "7시" 슬롯은 8:00에 끝나 제외.
      if (slotTime.add(const Duration(hours: 1)).isAfter(now)) {
        visible.add(_SlotData(hour: ultra.hours[i], slotTime: slotTime));
      }
    }

    if (visible.isEmpty) {
      // 모든 슬롯이 지나간 경우 — stale 한참 — 카드 자체 숨김.
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter.grouped(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: Colors.white.withValues(alpha: 0.15),
            child: InkWell(
              // 카드 전체가 버튼 — 누르면 비구름 지도로.
              onTap: () => context.push('/radar'),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
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
                          Icon(
                            Icons.chevron_right_rounded,
                            color: sky.ink.withValues(alpha: 0.6),
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '비구름 이동 예측 보기 · 매 30분 갱신',
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
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 14),
                          itemBuilder: (_, i) => _UltraSlot(
                            hour: visible[i].hour,
                            slotTime: visible[i].slotTime,
                            now: now,
                            sky: sky,
                            sunrise: sunrise,
                            sunset: sunset,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotData {
  const _SlotData({required this.hour, required this.slotTime});
  final HourlyWeather hour;
  final DateTime slotTime;
}

/// 일출/일몰 비교로 낮/밤 판정. 둘 다 null이면 6시~19시 휴리스틱.
bool _isDaytime(DateTime t, DateTime? sunrise, DateTime? sunset) {
  if (sunrise == null || sunset == null) {
    return t.hour >= 6 && t.hour < 19;
  }
  // 같은 날짜 기준 시각 비교 — sunrise/sunset이 오늘 시각, t가 미래 슬롯이면
  // 시각만 일치시켜 비교.
  final cmp = DateTime(sunrise.year, sunrise.month, sunrise.day,
      t.hour, t.minute);
  return cmp.isAfter(sunrise) && cmp.isBefore(sunset);
}

class _UltraSlot extends StatelessWidget {
  const _UltraSlot({
    required this.hour,
    required this.slotTime,
    required this.now,
    required this.sky,
    this.sunrise,
    this.sunset,
  });

  final HourlyWeather hour;
  final DateTime slotTime;
  final DateTime now;
  final SkyPalette sky;
  final DateTime? sunrise;
  final DateTime? sunset;

  @override
  Widget build(BuildContext context) {
    // Flaticon Premium 카와이 PNG 아이콘. 낮/밤은 일출/일몰 시각 기반 (대략적
    // 6시~19시 fallback).
    final isDay = _isDaytime(slotTime, sunrise, sunset);
    final asset = weatherGlyphAsset(weatherGlyphFor(
      condition: hour.condition,
      isDay: isDay,
      weatherCode: hour.weatherCode,
    ));

    // 슬롯이 현재 시간대인지 ("지금")
    final isNow = slotTime.year == now.year &&
        slotTime.month == now.month &&
        slotTime.day == now.day &&
        slotTime.hour == now.hour;

    final label = isNow ? '지금' : '${slotTime.hour}시';

    return SizedBox(
      width: 48,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isNow ? sky.ink : sky.ink.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: isNow ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Image.asset(
            asset,
            width: 26,
            height: 26,
            filterQuality: FilterQuality.medium,
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
