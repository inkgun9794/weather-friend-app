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
import 'package:weather_friend/features/location/data/selected_city_provider.dart';
import 'package:weather_friend/shared/widgets/audio_bubble.dart';
import 'package:weather_friend/shared/widgets/character_portrait.dart';
import 'package:weather_friend/shared/widgets/weather_bg.dart';

class BriefingScreen extends ConsumerWidget {
  const BriefingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBriefings = ref.watch(todayBriefingsProvider);
    final hourAsync = ref.watch(kstHourProvider);
    final currentHour = switch (hourAsync) {
      AsyncData(:final value) => value,
      _ => currentHourKst(),
    };
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
                  // "이전 메시지 보기" 버튼 — 오늘 사이클에 메시지가 하나라도 있을 때만.
                  if (briefings.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _ConversationLink(sky: sky),
                    ),
                  SliverToBoxAdapter(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final todayAsync = ref.watch(todayHourlyWeatherProvider);
                        final tomorrowAsync = ref.watch(tomorrowHourlyWeatherProvider);
                        final todaySummaryAsync = ref.watch(todayDailySummaryProvider);
                        final tomorrowSummaryAsync = ref.watch(tomorrowDailySummaryProvider);
                        final today = switch (todayAsync) {
                          AsyncData(:final value) => value,
                          _ => const <int, HourlyWeather>{},
                        };
                        final tomorrow = switch (tomorrowAsync) {
                          AsyncData(:final value) => value,
                          _ => const <int, HourlyWeather>{},
                        };
                        final todaySummary = switch (todaySummaryAsync) {
                          AsyncData(:final value) => value,
                          _ => null,
                        };
                        final tomorrowSummary = switch (tomorrowSummaryAsync) {
                          AsyncData(:final value) => value,
                          _ => null,
                        };
                        return Column(
                          children: [
                            _TimelineSection(
                              dateLabel: _todayLabel(),
                              label: '오늘 날씨',
                              summary: todaySummary?.shortLine(),
                              sky: sky,
                              briefings: briefings,
                              hourlyWeather: today,
                              currentHour: currentHour,
                              scrollHour: currentHour,
                              dimNonCurrent: true,
                            ),
                            _TimelineSection(
                              dateLabel: _tomorrowLabel(),
                              label: '내일 날씨',
                              summary: tomorrowSummary?.shortLine(),
                              sky: sky,
                              briefings: const <int, Briefing>{},
                              hourlyWeather: tomorrow,
                              currentHour: -1,
                              scrollHour: currentHour,
                              dimNonCurrent: false,
                            ),
                          ],
                        );
                      },
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

String _todayLabel() => _formatDate(nowKst());

String _tomorrowLabel() =>
    _formatDate(nowKst().add(const Duration(days: 1)));

String _formatDate(DateTime d) {
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  return '${d.month}월 ${d.day}일 ${days[d.weekday - 1]}요일';
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

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.sky});

  final SkyPalette sky;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(selectedCityProvider);
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
                city,
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
            child: Icon(Icons.menu_rounded, color: sky.ink, size: 18),
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

class _BigTemp extends ConsumerWidget {
  const _BigTemp({
    required this.sky,
    required this.briefings,
    required this.currentHour,
  });

  final SkyPalette sky;
  final Map<int, Briefing> briefings;
  final int currentHour;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Briefing(메시지 있는 hour) 우선, 없으면 Open-Meteo hourly 데이터로 fallback.
    final b = briefings[currentHour] ?? _nearestPast(briefings, currentHour);
    final hourlyAsync = ref.watch(todayHourlyWeatherProvider);
    final hourly = switch (hourlyAsync) {
      AsyncData(:final value) => value[currentHour],
      _ => null,
    };
    final temp = b?.weatherSnapshot.temperatureC.round()
        ?? hourly?.temperatureC.round();
    final feels = b?.weatherSnapshot.feelsLikeC.round();
    final cond = b?.weatherSnapshot.condition ?? hourly?.condition ?? '—';

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
                  CharacterPortrait(charId: charId, size: 36),
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
                          '${character.displayName.split(' ').first} · ${_hourLabel(briefing.hour)}:00 전송',
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

class _TimelineSection extends StatefulWidget {
  const _TimelineSection({
    required this.dateLabel,
    required this.label,
    required this.summary,
    required this.sky,
    required this.briefings,
    required this.hourlyWeather,
    required this.currentHour,
    required this.scrollHour,
    required this.dimNonCurrent,
  });

  final String dateLabel;
  final String label;
  final String? summary;
  final SkyPalette sky;
  final Map<int, Briefing> briefings;
  final Map<int, HourlyWeather> hourlyWeather;
  final int currentHour; // 칩 'now' 강조용. 내일 섹션은 -1로 비활성.
  final int scrollHour;  // 초기 스크롤 위치. 오늘/내일 모두 현재 hour로 맞춤.
  final bool dimNonCurrent;

  @override
  State<_TimelineSection> createState() => _TimelineSectionState();
}

class _TimelineSectionState extends State<_TimelineSection> {
  // _HourChip width(86) + separator(8) = 94px / chip
  static const double _chipPitch = 94.0;
  static const double _listLeftPad = 20.0;

  final ScrollController _controller = ScrollController();
  bool _didInitialJump = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrent());
  }

  void _jumpToCurrent() {
    if (_didInitialJump || !_controller.hasClients) return;
    final screenW = MediaQuery.of(context).size.width;
    final hour = widget.scrollHour.clamp(0, 23);
    // 칩이 화면 중앙에 오도록.
    final raw = _listLeftPad + hour * _chipPitch - (screenW - _chipPitch) / 2;
    final maxScroll = _controller.position.maxScrollExtent;
    _controller.jumpTo(raw.clamp(0.0, maxScroll));
    _didInitialJump = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 2),
          child: Text(
            widget.dateLabel,
            style: TextStyle(
              color: widget.sky.inkSoft,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.sky.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              if (widget.summary != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.summary!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: widget.sky.inkSoft,
                      letterSpacing: -0.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 130,
          child: ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: _listLeftPad),
            itemCount: 24,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, hour) => _HourChip(
              hour: hour,
              briefing: widget.briefings[hour],
              hourly: widget.hourlyWeather[hour],
              isNow: hour == widget.currentHour,
              isPast: widget.dimNonCurrent && hour < widget.currentHour,
            ),
          ),
        ),
      ],
    );
  }
}

class _HourChip extends StatelessWidget {
  const _HourChip({
    required this.hour,
    required this.briefing,
    required this.hourly,
    required this.isNow,
    required this.isPast,
  });

  final int hour;
  final Briefing? briefing;
  final HourlyWeather? hourly;
  final bool isNow;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final sky = skyFor(hour);
    final hasAudio = briefing?.audioUrl != null;
    final charId = briefing != null
        ? Character.parseId(briefing!.characterId)
        : null;
    // Briefing 데이터(메시지 있는 hour) 우선, 없으면 Open-Meteo hourly로 fallback
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
