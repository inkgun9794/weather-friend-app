import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:weather_friend/app/router/main_shell.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/briefing/presentation/widgets/ultra_short_section.dart';
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
          loading: () =>
              Center(child: CircularProgressIndicator(color: sky.ink)),
          error: (e, _) => Center(
            child: Text('오류: $e', style: TextStyle(color: sky.ink)),
          ),
          data: (briefings) => SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(todayBriefingsProvider),
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
                    // "이전 메시지 보기" 버튼 — 오늘 사이클에 메시지가 하나라도 있을 때만.
                    if (briefings.isNotEmpty)
                      SliverToBoxAdapter(child: _ConversationLink(sky: sky)),
                    // 초단기 6시간 — KMA 데이터 있을 때만 자동 표시. OpenMeteo 폴백 시 숨김.
                    SliverToBoxAdapter(child: UltraShortSection(sky: sky)),
                    SliverToBoxAdapter(
                      child: Consumer(
                        builder: (context, ref, _) {
                          final todayAsync = ref.watch(
                            todayHourlyWeatherProvider,
                          );
                          final todaySummaryAsync = ref.watch(
                            todayDailySummaryProvider,
                          );
                          final sunAsync = ref.watch(
                            todaySunriseSunsetProvider,
                          );
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

/// Flaticon Premium 카와이 날씨 아이콘 (PNG).
///
/// 우선순위 (KMA가 절대 우선):
/// 1. KMA condition (c)이 비/눈/흐림이면 그 카테고리 그대로 — Open-Meteo 강도 보강만
///    (예: KMA "비" + Open-Meteo WMO 95(천둥번개) → thunder.png)
///    (예: KMA "맑음" + Open-Meteo WMO 95 → 천둥 무시, 그냥 맑음 아이콘)
/// 2. KMA "맑음"일 때만 일출/일몰 윈도우 (±30분) 검사 → sunrise/sunset.png
/// 3. 그 외 맑음 → 낮/밤 (일출~일몰 사이) → sun/moon.png
String _weatherAsset(
  WeatherCondition c,
  int hour, {
  int? weatherCode,
  DateTime? sunrise,
  DateTime? sunset,
}) {
  // 1. KMA condition 우선 — 비/눈/흐림 카테고리 결정
  switch (c) {
    case WeatherCondition.rain:
      // KMA가 비라면 비 계열 안에서 Open-Meteo로 강도 보강
      if (weatherCode != null) {
        if (weatherCode >= 95) return 'assets/icons/weather/thunder.png';
        if (weatherCode == 65 || weatherCode == 82) {
          return 'assets/icons/weather/heavy_rain.png';
        }
        if (weatherCode == 81) return 'assets/icons/weather/shower.png';
      }
      return 'assets/icons/weather/rain.png';
    case WeatherCondition.snow:
      if (weatherCode == 75 || weatherCode == 86) {
        return 'assets/icons/weather/blizzard.png';
      }
      return 'assets/icons/weather/snow.png';
    case WeatherCondition.cloudy:
      return 'assets/icons/weather/cloud.png';
    case WeatherCondition.clear:
      break; // 아래 일출/일몰/낮/밤 처리로 진행
  }

  // 2. KMA "맑음"일 때만 일출/일몰 윈도우 (±30분) → sunrise/sunset.png
  if (sunrise != null && _isWithinHourWindow(hour, sunrise, 30)) {
    return 'assets/icons/weather/sunrise.png';
  }
  if (sunset != null && _isWithinHourWindow(hour, sunset, 30)) {
    return 'assets/icons/weather/sunset.png';
  }

  // 3. 평소 맑음 — 낮/밤 결정
  final isDay = _isDaytime(hour, sunrise, sunset);
  return isDay
      ? 'assets/icons/weather/sun.png'
      : 'assets/icons/weather/moon.png';
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
  AsyncValue<Map<int, Briefing>> async,
  int hour,
) {
  final data = async.value;
  if (data == null) return WeatherCondition.clear;
  final b = data[hour] ?? _nearestPast(data, hour);
  // casual은 날씨 데이터 없음 → 직전 날씨 슬롯에서 condition을 끌어와야 하지만
  // 일단은 clear로 fallback. 실제 표시에선 weather 영역을 숨기는 게 자연.
  if (b == null || b.weatherSnapshot == null) return WeatherCondition.clear;
  return _conditionFromString(b.weatherSnapshot!.condition);
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
    // Briefing(메시지 있는 hour) 우선, 없으면 Open-Meteo hourly 데이터로 fallback.
    final b = briefings[currentHour] ?? _nearestPast(briefings, currentHour);
    final hourlyAsync = ref.watch(todayHourlyWeatherProvider);
    final hourly = switch (hourlyAsync) {
      AsyncData(:final value) => value[currentHour],
      _ => null,
    };
    final temp =
        b?.weatherSnapshot?.temperatureC.round() ?? hourly?.temperatureC.round();
    final feels = b?.weatherSnapshot?.feelsLikeC.round();
    final cond = b?.weatherSnapshot?.condition ?? hourly?.condition ?? '—';

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
                    if (b != null && b.weatherSnapshot != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '강수 ${b.weatherSnapshot!.precipitationProb}% · 습도 ${b.weatherSnapshot!.humidity}%',
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
      child: BackdropFilter.grouped(
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
          onTap: () => context.go('/messages'),
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
                // 헤더와 strip을 가르는 얇은 디바이더 (잉크 8% — 거의 안 보이지만
                // 시각적 구분은 됨).
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: sky.ink.withValues(alpha: 0.08),
                ),
                // 24시간 가로 strip — 슬롯 사이엔 보더 없이 2px 갭만.
                // 높이는 isNow 슬롯(아이콘 24 + 폰트 19 + 알약 패딩)을 여유 있게
                // 수용할 만큼.
                SizedBox(
                  height: 132,
                  child: ListView.builder(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: _stripHPad,
                      vertical: 8,
                    ),
                    itemCount: 24,
                    itemBuilder: (context, hour) => _HourSlot(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    final hasAudio = briefing?.audioUrl != null;
    final charId = briefing != null
        ? Character.parseId(briefing!.characterId)
        : null;
    // Briefing 데이터(메시지 있는 hour) 우선, 없으면 Open-Meteo hourly로 fallback.
    // casual 타입은 weatherSnapshot이 null이라 그땐 hourly fallback 사용.
    final conditionStr =
        briefing?.weatherSnapshot?.condition ?? hourly?.condition;
    final cond = conditionStr != null
        ? _conditionFromString(conditionStr)
        : WeatherCondition.clear;
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
      child: Column(
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
            _weatherAsset(
              cond,
              hour,
              weatherCode: hourly?.weatherCode,
              sunrise: sunrise,
              sunset: sunset,
            ),
            width: isNow ? 28 : 26,
            height: isNow ? 28 : 26,
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
          const SizedBox(height: 4),
          // 음성 보유 표시 — 작은 점으로. 슬롯 높이를 일정하게 유지하려고
          // 점이 없어도 같은 크기 영역을 차지.
          SizedBox(
            height: 6,
            child: hasAudio && charId != null
                ? Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: visualFor(charId).color,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(right: rightGap),
      // 지난 시간은 살짝 디밍. 현재(isNow)는 알약 강조가 우선이라 디밍 X.
      child: Opacity(opacity: isPast && !isNow ? 0.55 : 1.0, child: slot),
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
  // _weatherAsset에 sunrise/sunset 안 넘기고 6시~19시 휴리스틱으로 fallback.
  final int partHour;

  @override
  Widget build(BuildContext context) {
    final cond = _conditionFromString(summary.condition);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          _weatherAsset(cond, partHour),
          width: 20,
          height: 20,
          filterQuality: FilterQuality.medium,
        ),
        const SizedBox(width: 6),
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
