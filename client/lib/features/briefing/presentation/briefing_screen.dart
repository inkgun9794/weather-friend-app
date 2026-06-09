import 'dart:ui';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:weather_friend/app/router/main_shell.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/features/briefing/data/weather_providers.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/briefing/domain/outfit_guide.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/briefing/presentation/current_weather_display.dart';
import 'package:weather_friend/features/briefing/presentation/widgets/outfit_recommendation_section.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/features/location/data/selected_city_provider.dart';
import 'package:weather_friend/shared/widgets/audio_bubble.dart';
import 'package:weather_friend/shared/widgets/character_portrait.dart';
import 'package:weather_friend/shared/widgets/weather_bg.dart';
import 'package:weather_friend/shared/widgets/weather_icons.dart';

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
    final asyncHourly = ref.watch(todayHourlyWeatherProvider);
    final briefings = asyncBriefings.value ?? const <int, Briefing>{};

    return Scaffold(
      body: WeatherBg(
        hour: currentHour,
        condition: _conditionForCurrent(
          asyncBriefings,
          asyncHourly,
          currentHour,
        ),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => Future.wait([
              ref.read(todayBriefingsProvider.notifier).refresh(),
              ref.read(weatherBundleProvider.notifier).refresh(),
            ]),
            // 화면 안 글래스 카드 4종(circle button, hero, timeline, weekly)을
            // 같은 backdrop key로 묶어 백그라운드 샘플링을 1회로 합친다.
            // 네비바(MainShell)는 스크롤 시 카드와 겹치므로 같은 그룹에 넣지
            // 않는다 — 같은 key 공유 영역이 겹치면 한 번만 필터된 것처럼 보임.
            child: BackdropGroup(
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
                  // 초단기 섹션(UltraShortSection)·라디오 진입 제거 — 24h strip에
                  // 이미 초단기 데이터가 머지되어 있어 정보 손실 X.
                  SliverToBoxAdapter(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final todayAsync = ref.watch(
                          todayHourlyWeatherProvider,
                        );
                        final todaySummaryAsync = ref.watch(
                          todayDailySummaryProvider,
                        );
                        final sunAsync = ref.watch(todaySunriseSunsetProvider);
                        final today = switch (todayAsync) {
                          AsyncData(:final value) => value,
                          _ => const <int, HourlyWeather>{},
                        };
                        final todaySummary = switch (todaySummaryAsync) {
                          AsyncData(:final value) => value,
                          _ => null,
                        };
                        final (sunrise, sunset) = switch (sunAsync) {
                          AsyncData(:final value) => value,
                          _ => (null, null),
                        };
                        return _TimelineSection(
                          dateLabel: _todayLabel(),
                          label: '오늘 날씨',
                          summary: todaySummary?.shortLine(),
                          sky: sky,
                          briefings: briefings,
                          hourlyWeather: today,
                          currentHour: currentHour,
                          sunrise: sunrise,
                          sunset: sunset,
                        );
                      },
                    ),
                  ),
                  SliverToBoxAdapter(child: _WeeklyForecastCard(sky: sky)),
                  // 글래스 하단바 뒤로 컨텐츠가 흘러가도록 — 마지막 항목이 가려지지 않게
                  // 바 높이 + 시스템 safe area + 약간의 숨 공간.
                  SliverPadding(
                    padding: EdgeInsets.only(
                      bottom:
                          kGlassNavBarHeight +
                          MediaQuery.paddingOf(context).bottom +
                          12,
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

WeatherCondition _conditionFromString(String s) {
  if (s.contains('비') || s.contains('소나기')) return WeatherCondition.rain;
  if (s.contains('눈')) return WeatherCondition.snow;
  if (s.contains('흐') || s.contains('구름')) return WeatherCondition.cloudy;
  return WeatherCondition.clear;
}

/// `hour:00` (정시)이 [t]에서 ±[minutes]분 이내인지.
/// 일출/일몰이 가운데 시각인 한 시간 슬롯에만 sunrise/sunset 아이콘 표시.
bool _isWithinHourWindow(int hour, DateTime t, int minutes) {
  final base = DateTime(t.year, t.month, t.day, hour);
  return base.difference(t).inMinutes.abs() <= minutes;
}

/// 일출/일몰 시각이 있으면 그걸로 비교, 없으면 단순 6시~19시 휴리스틱.
bool _isDaytime(int hour, DateTime? sunrise, DateTime? sunset) {
  if (sunrise == null || sunset == null) {
    return hour >= 6 && hour < 19;
  }
  final today = DateTime(sunrise.year, sunrise.month, sunrise.day, hour);
  return today.isAfter(sunrise) && today.isBefore(sunset);
}

WeatherCondition _conditionForCurrent(
  AsyncValue<Map<int, Briefing>> briefingsAsync,
  AsyncValue<Map<int, HourlyWeather>> hourlyAsync,
  int hour,
) {
  final display = resolveCurrentWeatherDisplay(
    hourly: hourlyAsync.value?[hour],
    exactBriefing: briefingsAsync.value?[hour],
  );
  final condition = display.condition;
  return condition == null
      ? WeatherCondition.clear
      : _conditionFromString(condition);
}

/// 메인 Hero에 띄울 brief 목록 (시간순).
/// 메인 Hero에 노출되는 알람 카드 하나.
/// - 6시~20시: 6시 카드 (음성 + 아침 안부)
/// - 21시~익일 5시: 21시 카드 (텍스트 + 잘자) — 6시 카드 자리를 교체
/// 9~20시 hourly는 메인이 아니라 대화 화면에서 누적.
/// kst.todayKstIso()가 0~5시엔 어제 사이클을 반환하므로 어제 21시 카드가 자연스럽게 보임.
List<Briefing> _mainHeroBriefings(Map<int, Briefing> briefings, int hour) {
  final isEveningWindow = hour >= 21 || hour < 6;
  if (isEveningWindow && briefings[21] != null) {
    return [briefings[21]!];
  }
  if (hour >= 6 && briefings[6] != null) {
    return [briefings[6]!];
  }
  return [];
}

String _todayLabel() => _formatDate(nowKst());

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
  if (hour == 6) return '아침 인사';
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
                city.label,
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
      child: BackdropFilter.grouped(
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
    final hourlyAsync = ref.watch(todayHourlyWeatherProvider);
    final hourly = switch (hourlyAsync) {
      AsyncData(:final value) => value[currentHour],
      _ => null,
    };
    final display = resolveCurrentWeatherDisplay(
      hourly: hourly,
      exactBriefing: briefings[currentHour],
    );
    final temp = display.temperatureC?.round();
    final feels = display.feelsLikeC?.round();
    final cond = display.condition ?? '—';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
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
                    if (display.precipitationProb != null ||
                        display.humidity != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (display.precipitationProb != null)
                            '강수 ${display.precipitationProb}%',
                          if (display.humidity != null)
                            '습도 ${display.humidity}%',
                        ].join(' · '),
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

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.briefings, required this.currentHour});

  final Map<int, Briefing> briefings;
  final int currentHour;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroes = _mainHeroBriefings(briefings, currentHour);
    if (heroes.isEmpty) {
      return const SizedBox.shrink();
    }
    final hourlyAsync = ref.watch(todayHourlyWeatherProvider);
    final hourly = switch (hourlyAsync) {
      AsyncData(:final value) => value[currentHour],
      _ => null,
    };
    final display = resolveCurrentWeatherDisplay(
      hourly: hourly,
      exactBriefing: briefings[currentHour],
    );
    final outfitTemp = display.feelsLikeC ?? display.temperatureC;
    final outfitGuide = outfitTemp != null
        ? outfitGuideFor(outfitTemp.round())
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          for (var i = 0; i < heroes.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _HeroBriefingCard(briefing: heroes[i], outfitGuide: outfitGuide),
          ],
        ],
      ),
    );
  }
}

class _HeroBriefingCard extends StatelessWidget {
  const _HeroBriefingCard({required this.briefing, required this.outfitGuide});

  final Briefing briefing;
  final OutfitGuide? outfitGuide;

  @override
  Widget build(BuildContext context) {
    final charId = Character.parseId(briefing.characterId);
    if (charId == null) return const SizedBox.shrink();
    final v = visualFor(charId);
    final character = Character.byId(charId);
    final hasAudio = briefing.audioUrl != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(14),
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
                  CharacterPortrait(charId: charId, size: 34),
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
                          '${_hourLabel(briefing.hour)}:00 전송',
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
              if (hasAudio) ...[
                const SizedBox(height: 12),
                AudioBubble(charId: charId, audioUrl: briefing.audioUrl!),
                if (outfitGuide != null) ...[
                  const SizedBox(height: 13),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.ink.withValues(alpha: 0.07),
                  ),
                  const SizedBox(height: 12),
                  OutfitRecommendationSection(
                    guide: outfitGuide!,
                    characterId: charId,
                  ),
                ],
              ] else ...[
                const SizedBox(height: 12),
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 아이폰 날씨앱 스타일 — 단일 글래스 컨테이너 안에 24시간이 가로로 흐름.
/// 시간마다 따로 카드를 두지 않고, 현재 hour는 세로 알약(pill) 배경 + "지금"
/// 라벨로 강조한다. (이전엔 시간마다 86px 라운드 카드 + 박스섀도우 halo였음.)
class _TimelineSection extends StatefulWidget {
  const _TimelineSection({
    required this.dateLabel,
    required this.label,
    required this.summary,
    required this.sky,
    required this.briefings,
    required this.hourlyWeather,
    required this.currentHour,
    this.sunrise,
    this.sunset,
  });

  final String dateLabel;
  final String label;
  final String? summary;
  final SkyPalette sky;
  final Map<int, Briefing> briefings;
  final Map<int, HourlyWeather> hourlyWeather;
  final int currentHour;
  final DateTime? sunrise;
  final DateTime? sunset;

  @override
  State<_TimelineSection> createState() => _TimelineSectionState();
}

class _TimelineSectionState extends State<_TimelineSection> {
  // 슬롯 폭(56) + 갭(2) = 58px / slot. 슬롯엔 개별 보더가 없어서
  // 카드형(86px)보다 좁아도 시각적으로 답답하지 않다.
  static const double _slotWidth = 56.0;
  static const double _slotGap = 2.0;
  static const double _slotPitch = _slotWidth + _slotGap;
  static const double _stripHPad = 10.0;
  static const double _graphHeight = 82.0;
  static const double _slotsHeight = 118.0;
  static const double _stripHeightWithGraph = 220.0;
  static const double _stripContentWidth = _slotPitch * 24;
  // 컨테이너 좌우 마진 16씩 → strip viewport = screenW - 32.
  static const double _containerHMargin = 16.0;

  final ScrollController _controller = ScrollController();
  bool _didInitialJump = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrent());
  }

  void _jumpToCurrent() {
    if (_didInitialJump || !_controller.hasClients) return;
    final viewportW =
        MediaQuery.of(context).size.width - (_containerHMargin * 2);
    final hour = widget.currentHour.clamp(0, 23);
    // 슬롯이 strip viewport 중앙에 오도록.
    final raw = _stripHPad + hour * _slotPitch - (viewportW - _slotWidth) / 2;
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
    final sky = widget.sky;
    final temperatures = <int, double>{};
    for (var hour = 0; hour < 24; hour++) {
      final temperature =
          widget.briefings[hour]?.weatherSnapshot?.temperatureC ??
          widget.hourlyWeather[hour]?.temperatureC;
      if (temperature != null) {
        temperatures[hour] = temperature;
      }
    }
    final hasGraph = temperatures.length >= 2;
    final stripHeight = hasGraph ? _stripHeightWithGraph : 140.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _containerHMargin,
        18,
        _containerHMargin,
        0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter.grouped(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더: 날짜 + 라벨 + 요약. 컨테이너 안쪽 패딩.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.dateLabel,
                        style: TextStyle(
                          color: sky.inkSoft,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            widget.label,
                            style: TextStyle(
                              color: sky.ink,
                              fontSize: 15,
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
                                  color: sky.inkSoft,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.1,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // 실제 시간별 기온 곡선과 24시간 슬롯이 같은 가로축을 공유한다.
                // 구분선부터 카드 하단까지 그라데이션이 빈틈없이 이어진다.
                SizedBox(
                  height: stripHeight,
                  child: SingleChildScrollView(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      width: _stripContentWidth + (_stripHPad * 2),
                      height: stripHeight,
                      decoration: BoxDecoration(
                        gradient: _hourGradient(
                          sunrise: widget.sunrise,
                          sunset: widget.sunset,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 1,
                              color: sky.ink.withValues(alpha: 0.08),
                            ),
                          ),
                          Positioned(
                            top: 1,
                            bottom: 0,
                            left: _stripHPad,
                            right: _stripHPad,
                            child: Stack(
                              children: [
                                if (hasGraph)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 3,
                                    height: _graphHeight,
                                    child: Semantics(
                                      image: true,
                                      label: '시간별 기온 변화 그래프',
                                      child: CustomPaint(
                                        key: const Key('temperature-curve'),
                                        painter: _TemperatureCurvePainter(
                                          temperatures: temperatures,
                                          currentHour: widget.currentHour,
                                          slotPitch: _slotPitch,
                                          slotWidth: _slotWidth,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: 0,
                                  height: _slotsHeight,
                                  child: Row(
                                    children: List.generate(
                                      24,
                                      (hour) => _HourSlot(
                                        hour: hour,
                                        briefing: widget.briefings[hour],
                                        hourly: widget.hourlyWeather[hour],
                                        sky: sky,
                                        isNow: hour == widget.currentHour,
                                        isPast: hour < widget.currentHour,
                                        width: _slotWidth,
                                        rightGap: _slotGap,
                                        sunrise: widget.sunrise,
                                        sunset: widget.sunset,
                                      ),
                                    ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TemperatureCurvePainter extends CustomPainter {
  const _TemperatureCurvePainter({
    required this.temperatures,
    required this.currentHour,
    required this.slotPitch,
    required this.slotWidth,
  });

  final Map<int, double> temperatures;
  final int currentHour;
  final double slotPitch;
  final double slotWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (temperatures.length < 2) return;

    final values = temperatures.values.toList(growable: false);
    var minTemp = values.first;
    var maxTemp = values.first;
    for (final value in values.skip(1)) {
      if (value < minTemp) minTemp = value;
      if (value > maxTemp) maxTemp = value;
    }

    final rawRange = maxTemp - minTemp;
    final range = rawRange < 4 ? 4.0 : rawRange;
    final center = (maxTemp + minTemp) / 2;
    final low = center - range / 2;
    const graphTop = 19.0;
    final graphBottom = size.height - 12;
    final graphRange = graphBottom - graphTop;

    Offset pointFor(MapEntry<int, double> entry) {
      final x = entry.key * slotPitch + slotWidth / 2;
      final normalized = (entry.value - low) / range;
      final y = graphBottom - normalized.clamp(0.0, 1.0) * graphRange;
      return Offset(x, y);
    }

    final entries = temperatures.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final points = entries.map(pointFor).toList(growable: false);

    final curve = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final point = points[i];
      final controlX = (previous.dx + point.dx) / 2;
      curve.cubicTo(
        controlX,
        previous.dy,
        controlX,
        point.dy,
        point.dx,
        point.dy,
      );
    }

    final fill = Path.from(curve)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x339DEBFF), Color(0x009DEBFF)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      curve,
      Paint()
        ..color = const Color(0xFFE1F8FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final point = points[i];
      final isCurrent = entry.key == currentHour;

      if (isCurrent) {
        canvas.drawCircle(
          point,
          6,
          Paint()..color = Colors.white.withValues(alpha: 0.96),
        );
        canvas.drawCircle(point, 4, Paint()..color = const Color(0xFFFF5E73));
      } else {
        canvas.drawCircle(
          point,
          2.25,
          Paint()..color = Colors.white.withValues(alpha: 0.92),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TemperatureCurvePainter oldDelegate) {
    return !mapEquals(oldDelegate.temperatures, temperatures) ||
        oldDelegate.currentHour != currentHour ||
        oldDelegate.slotPitch != slotPitch ||
        oldDelegate.slotWidth != slotWidth;
  }
}

/// 24h strip 그라데이션 — 실제 일출/일몰 시각에 따라 오렌지 피크 위치가 동적 이동.
/// 겨울(일몰 17:00)·여름(일몰 19:30) 모두 자연스러운 표현.
/// Open-Meteo daily의 sunrise/sunset을 받아서 stop 위치 계산.
LinearGradient _hourGradient({DateTime? sunrise, DateTime? sunset}) {
  // 시각 → 24h 분수 (0.0 ~ 1.0)
  double frac(DateTime t) => (t.hour * 60 + t.minute) / (24 * 60);
  // fallback (sun data 없을 때 — 약 8월 한국 기준)
  final sr = sunrise != null ? frac(sunrise) : 6 / 24;
  final ss = sunset != null ? frac(sunset) : 19 / 24;
  // 색 anchor 8개. 일출/일몰 시각이 좌우로 이동하면 오렌지 피크도 같이 이동.
  return LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: const [
      Color(0x991A2358), // 0시           깊은 네이비
      Color(0xAA6B6E8E), // 일출 -1h      분홍보라 (여명)
      Color(0xCCFFA68A), // 일출           오렌지 핑크
      Color(0xBBFFD791), // 일출 +2h      아침 노랑
      Color(0xAA7EC0EE), // 정오           파스텔 블루
      Color(0xCCFFB27E), // 일몰 -30min   따뜻한 톤
      Color(0xCCFF7E6B), // 일몰           오렌지 (sunset)
      Color(0xAA6B4A6E), // 일몰 +1h      보라
      Color(0x991A2358), // 23시          깊은 네이비
    ],
    stops: [
      0.0,
      (sr - 1 / 24).clamp(0.0, 1.0),
      sr.clamp(0.01, 0.99),
      (sr + 2 / 24).clamp(0.0, 1.0),
      0.5,
      (ss - 0.5 / 24).clamp(0.0, 1.0),
      ss.clamp(0.01, 0.99),
      (ss + 1 / 24).clamp(0.0, 1.0),
      1.0,
    ],
  );
}

/// 연결형 strip의 한 시간 칸. 개별 카드 보더 없이 부모 글래스 위에 그냥 얹힌다.
/// 현재 hour만 알약(pill) 배경 + "지금" 라벨 + 굵은 텍스트로 확실히 튀게.
class _HourSlot extends StatelessWidget {
  const _HourSlot({
    required this.hour,
    required this.briefing,
    required this.hourly,
    required this.sky,
    required this.isNow,
    required this.isPast,
    required this.width,
    required this.rightGap,
    this.sunrise,
    this.sunset,
  });

  final int hour;
  final Briefing? briefing;
  final HourlyWeather? hourly;
  final SkyPalette sky;
  final bool isNow;
  final bool isPast;
  final double width;
  final double rightGap;
  final DateTime? sunrise;
  final DateTime? sunset;

  @override
  Widget build(BuildContext context) {
    // Briefing 데이터(메시지 있는 hour) 우선, 없으면 Open-Meteo hourly로 fallback.
    // casual 타입은 weatherSnapshot이 null이라 그땐 hourly fallback 사용.
    final conditionStr =
        briefing?.weatherSnapshot?.condition ?? hourly?.condition;
    final temp =
        briefing?.weatherSnapshot?.temperatureC.round() ??
        hourly?.temperatureC.round();

    final ink = sky.ink;
    final label = isNow ? '지금' : _hourLabel(hour);

    // 슬롯 본체. isNow면 알약 배경 + 보더로 감싼다.
    final slot = Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: isNow
          ? BoxDecoration(
              color: Colors.white.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            )
          : null,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: width - 4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: ink,
                  fontSize: isNow ? 11.5 : 11,
                  fontWeight: isNow ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 8),
              Image.asset(
                weatherGlyphAsset(weatherGlyphFor(
                  condition: conditionStr ?? '',
                  isDay: _isDaytime(hour, sunrise, sunset),
                  weatherCode: hourly?.weatherCode,
                  isSunrise:
                      sunrise != null && _isWithinHourWindow(hour, sunrise!, 30),
                  isSunset:
                      sunset != null && _isWithinHourWindow(hour, sunset!, 30),
                )),
                width: isNow ? 26 : 24,
                height: isNow ? 26 : 24,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(height: 6),
              Text(
                temp != null ? '$temp°' : '—',
                style: TextStyle(
                  color: ink,
                  fontSize: isNow ? 19 : 17,
                  fontWeight: isNow ? FontWeight.w800 : FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(right: rightGap),
      child: slot,
    );
  }
}

/// 주간 카드 — 오늘부터 다음 주 월요일까지를 한 행 한 일로 보여준다.
/// 각 행은 [요일 라벨 | 오전 (아이콘+기온) | 오후 (아이콘+기온)] 구성.
/// 오늘 행은 라벨 "오늘" + bolder weight로 살짝 강조.
class _WeeklyForecastCard extends ConsumerWidget {
  const _WeeklyForecastCard({required this.sky});

  final SkyPalette sky;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weekDaysProvider);
    final days = switch (async) {
      AsyncData(:final value) => value,
      _ => const <WeekDay>[],
    };
    if (days.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter.grouped(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더 — timeline section과 같은 톤.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text(
                    '주간 날씨',
                    style: TextStyle(
                      color: sky.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                // 컬럼 헤더 (오전/오후) — 한 번만 표시해서 각 행 의미 명확.
                _WeekColumnHeaders(sky: sky),
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: sky.ink.withValues(alpha: 0.08),
                ),
                for (var i = 0; i < days.length; i++) ...[
                  _WeekDayRow(day: days[i], sky: sky, isToday: i == 0),
                  // 행 사이 미세 디바이더 (마지막 행 뒤엔 없음).
                  if (i < days.length - 1)
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: sky.ink.withValues(alpha: 0.05),
                    ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekColumnHeaders extends StatelessWidget {
  const _WeekColumnHeaders({required this.sky});

  final SkyPalette sky;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: sky.inkSoft,
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          // 첫 칸 너비는 _WeekDayRow의 day label 칸과 맞춰서 정렬.
          const SizedBox(width: 44),
          Expanded(
            child: Center(child: Text('오전', style: style)),
          ),
          Expanded(
            child: Center(child: Text('오후', style: style)),
          ),
          Expanded(
            child: Center(child: Text('저녁', style: style)),
          ),
        ],
      ),
    );
  }
}

class _WeekDayRow extends StatelessWidget {
  const _WeekDayRow({
    required this.day,
    required this.sky,
    required this.isToday,
  });

  final WeekDay day;
  final SkyPalette sky;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final label = isToday ? '오늘' : _weekdayChar(day.weekday);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: TextStyle(
                color: sky.ink,
                fontSize: isToday ? 14 : 13.5,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ),
          Expanded(
            child: _PartCell(summary: day.morning, sky: sky, partHour: 9),
          ),
          Expanded(
            child: _PartCell(summary: day.afternoon, sky: sky, partHour: 14),
          ),
          Expanded(
            child: _PartCell(summary: day.evening, sky: sky, partHour: 20),
          ),
        ],
      ),
    );
  }

  static String _weekdayChar(int weekday) {
    // DateTime.weekday: 1=Mon … 7=Sun.
    const chars = ['월', '화', '수', '목', '금', '토', '일'];
    return chars[(weekday - 1) % 7];
  }
}

class _PartCell extends StatelessWidget {
  const _PartCell({
    required this.summary,
    required this.sky,
    this.partHour = 12,
  });

  final DayPartSummary summary;
  final SkyPalette sky;
  // morning ~9시 / afternoon ~14시 / evening ~20시.
  // weekly 카드는 day-level이라 sunrise/sunset 정확한 값을 알 수 없음 →
  // 일출/일몰 없이 6시~19시 휴리스틱으로 낮/밤만 판단.
  final int partHour;

  @override
  Widget build(BuildContext context) {
    // 아이콘(위) + 기온(아래) 세로 구조 — 각 요소가 칸 정중앙에 와서
    // 헤더(오전/오후/저녁)와 세로축이 정확히 맞는다.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          weatherGlyphAsset(weatherGlyphFor(
            condition: summary.condition,
            isDay: partHour >= 6 && partHour < 19,
          )),
          width: 36,
          height: 36,
          filterQuality: FilterQuality.medium,
        ),
        const SizedBox(height: 4),
        Text(
          '${summary.tempC}°',
          style: TextStyle(
            color: sky.ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}
