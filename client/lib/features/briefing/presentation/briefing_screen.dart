import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/shared/widgets/audio_bubble.dart';
import 'package:weather_friend/shared/widgets/char_avatar.dart';
import 'package:weather_friend/shared/widgets/weather_bg.dart';

class BriefingScreen extends ConsumerWidget {
  const BriefingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBriefings = ref.watch(todayBriefingsProvider);
    final currentHour = currentHourKst();
    final sky = skyFor(currentHour);

    return Scaffold(
      body: WeatherBg(
        hour: currentHour,
        condition: _conditionForCurrent(asyncBriefings, currentHour),
        child: asyncBriefings.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: sky.ink),
          ),
          error: (e, _) => Center(
            child: Text('오류: $e', style: TextStyle(color: sky.ink)),
          ),
          data: (briefings) => SafeArea(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(todayBriefingsProvider),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _TopBar(sky: sky)),
                  SliverToBoxAdapter(
                    child: _BigTemp(
                      sky: sky,
                      briefings: briefings,
                      currentHour: currentHour,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _HeroCard(
                      briefings: briefings,
                      currentHour: currentHour,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _ConversationLink(sky: sky),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '오늘의 24시간',
                            style: TextStyle(
                              color: sky.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: -0.1,
                            ),
                          ),
                          Text(
                            _todayLabel(),
                            style: TextStyle(
                              color: sky.inkSoft,
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _TimelineChips(
                      briefings: briefings,
                      currentHour: currentHour,
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 28)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

WeatherCondition _conditionFromString(String s) {
  if (s.contains('비') || s.contains('소나기')) return WeatherCondition.rain;
  if (s.contains('눈')) return WeatherCondition.snow;
  if (s.contains('흐') || s.contains('구름')) return WeatherCondition.cloudy;
  return WeatherCondition.clear;
}

WeatherCondition _conditionForCurrent(
  AsyncValue<Map<int, Briefing>> async,
  int hour,
) {
  final data = async.value;
  if (data == null) return WeatherCondition.clear;
  final b = data[hour] ?? _nearestPast(data, hour);
  if (b == null) return WeatherCondition.clear;
  return _conditionFromString(b.weatherSnapshot.condition);
}

Briefing? _nearestPast(Map<int, Briefing> briefings, int hour) {
  for (var h = hour; h >= 0; h--) {
    if (briefings[h] != null) return briefings[h];
  }
  return null;
}

/// 메인 Hero에 띄울 brief 목록 (시간순).
/// 메인 Hero에 노출되는 알람 카드 하나.
/// - 5시~20시: 5시 카드 (음성 + 아침 안부)
/// - 21시~익일 4시: 21시 카드 (음성 + 잘자) — 5시 카드 자리를 교체
/// 9~20시 hourly는 메인이 아니라 대화 화면에서 누적.
/// kst.todayKstIso()가 0~4시엔 어제 사이클을 반환하므로 어제 21시 카드가 자연스럽게 보임.
List<Briefing> _mainHeroBriefings(Map<int, Briefing> briefings, int hour) {
  final isEveningWindow = hour >= 21 || hour < 5;
  if (isEveningWindow && briefings[21] != null) {
    return [briefings[21]!];
  }
  if (hour >= 5 && briefings[5] != null) {
    return [briefings[5]!];
  }
  return [];
}

String _todayLabel() {
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  final n = nowKst();
  return '${n.month}월 ${n.day}일 ${days[n.weekday - 1]}요일';
}

String _hourLabel(int hour) {
  if (hour == 0) return '오전 12';
  if (hour < 12) return '오전 $hour';
  if (hour == 12) return '낮 12';
  return '오후 ${hour - 12}';
}

String _alarmLabel(int hour) {
  if (hour == 5) return '아침 인사';
  if (hour == 9) return '오늘 시작';
  if (hour == 21) return '저녁 인사';
  return '';
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.sky});

  final SkyPalette sky;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: sky.ink, size: 14),
              const SizedBox(width: 6),
              Text(
                '서울',
                style: TextStyle(
                  color: sky.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          _GlassCircleButton(
            onTap: () => context.push('/settings'),
            child: Icon(Icons.notifications_outlined, color: sky.ink, size: 15),
          ),
        ],
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha: 0.25),
          shape: CircleBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(width: 36, height: 36, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}

class _BigTemp extends StatelessWidget {
  const _BigTemp({
    required this.sky,
    required this.briefings,
    required this.currentHour,
  });

  final SkyPalette sky;
  final Map<int, Briefing> briefings;
  final int currentHour;

  @override
  Widget build(BuildContext context) {
    final b = briefings[currentHour] ?? _nearestPast(briefings, currentHour);
    final temp = b?.weatherSnapshot.temperatureC.round();
    final feels = b?.weatherSnapshot.feelsLikeC.round();
    final cond = b?.weatherSnapshot.condition ?? '—';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '지금',
            style: TextStyle(
              color: sky.inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                temp != null ? '$temp' : '—',
                style: TextStyle(
                  color: sky.ink,
                  fontSize: 76,
                  fontWeight: FontWeight.w300,
                  height: 0.95,
                  letterSpacing: -3.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  '°',
                  style: TextStyle(
                    color: sky.ink,
                    fontSize: 36,
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feels != null ? '$cond · 체감 $feels°' : cond,
                      style: TextStyle(
                        color: sky.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (b != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '강수 ${b.weatherSnapshot.precipitationProb}% · 습도 ${b.weatherSnapshot.humidity}%',
                        style: TextStyle(
                          color: sky.inkSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.briefings, required this.currentHour});

  final Map<int, Briefing> briefings;
  final int currentHour;

  @override
  Widget build(BuildContext context) {
    final heroes = _mainHeroBriefings(briefings, currentHour);
    if (heroes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          for (var i = 0; i < heroes.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _HeroBriefingCard(briefing: heroes[i]),
          ],
        ],
      ),
    );
  }
}

class _HeroBriefingCard extends StatelessWidget {
  const _HeroBriefingCard({required this.briefing});

  final Briefing briefing;

  @override
  Widget build(BuildContext context) {
    final charId = Character.parseId(briefing.characterId);
    if (charId == null) return const SizedBox.shrink();
    final v = visualFor(charId);
    final character = Character.byId(charId);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CharAvatar(
                    charId: charId,
                    size: 36,
                    variant: CharAvatarVariant.photo,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          character.displayName.split(' ').last,
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                        Text(
                          '${character.displayName.split(' ').first} · 오전 ${briefing.hour}:00 전송',
                          style: TextStyle(
                            color: AppColors.inkMute,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: v.colorSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _alarmLabel(briefing.hour),
                      style: TextStyle(
                        color: v.colorDeep,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                briefing.transcript,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 14.5,
                  height: 1.55,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.1,
                ),
              ),
              if (briefing.audioUrl != null) ...[
                const SizedBox(height: 14),
                AudioBubble(charId: charId, audioUrl: briefing.audioUrl!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationLink extends StatelessWidget {
  const _ConversationLink({required this.sky});

  final SkyPalette sky;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Material(
        color: Colors.white.withValues(alpha: 0.28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/conversation'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: sky.ink, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '이전 메시지 보기',
                    style: TextStyle(
                      color: sky.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: sky.inkSoft, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineChips extends StatelessWidget {
  const _TimelineChips({required this.briefings, required this.currentHour});

  final Map<int, Briefing> briefings;
  final int currentHour;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 24,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, hour) => _HourChip(
          hour: hour,
          briefing: briefings[hour],
          isNow: hour == currentHour,
          isPast: hour < currentHour,
        ),
      ),
    );
  }
}

class _HourChip extends ConsumerWidget {
  const _HourChip({
    required this.hour,
    required this.briefing,
    required this.isNow,
    required this.isPast,
  });

  final int hour;
  final Briefing? briefing;
  final bool isNow;
  final bool isPast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sky = skyFor(hour);
    final hasAudio = briefing?.audioUrl != null;
    final charId = briefing != null
        ? Character.parseId(briefing!.characterId)
        : null;
    // Briefing 데이터(메시지 있는 hour) 우선, 없으면 Open-Meteo 직접 호출 결과로 fallback
    final hourly = switch (ref.watch(todayHourlyWeatherProvider)) {
      AsyncData(:final value) => value[hour],
      _ => null,
    };
    final conditionStr = briefing?.weatherSnapshot.condition ?? hourly?.condition;
    final cond = conditionStr != null
        ? _conditionFromString(conditionStr)
        : WeatherCondition.clear;
    final temp = briefing?.weatherSnapshot.temperatureC.round()
        ?? hourly?.temperatureC.round();

    return Opacity(
      opacity: isPast ? 0.7 : 1.0,
      child: Container(
        width: 86,
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [sky.top, sky.bot],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          boxShadow: isNow
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.95),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _hourLabel(hour),
                  style: TextStyle(
                    color: sky.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Icon(_iconFor(cond), color: sky.ink, size: 22),
                const SizedBox(height: 4),
                Text(
                  temp != null ? '$temp°' : '—',
                  style: TextStyle(
                    color: sky.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            if (hasAudio && charId != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: visualFor(charId).color,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(WeatherCondition c) {
    switch (c) {
      case WeatherCondition.clear:
        return Icons.wb_sunny;
      case WeatherCondition.cloudy:
        return Icons.cloud;
      case WeatherCondition.rain:
        return Icons.umbrella;
      case WeatherCondition.snow:
        return Icons.ac_unit;
    }
  }
}
