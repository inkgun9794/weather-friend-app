import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:weather_friend/app/router/main_shell.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/features/briefing/data/weather_providers.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/briefing/domain/outfit_guide.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/briefing/presentation/current_weather_display.dart';
import 'package:weather_friend/features/briefing/presentation/widgets/outfit_recommendation_section.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/features/location/data/city_catalog.dart';
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
    // 브리핑(멘트/음성)은 비용상 서울만 생성 — 카드 콘텐츠는 도시와 무관하게
    // 노출하되, 날씨 '수치'(온도/컨디션/옷 추천)에 서울 스냅샷이 섞이면 안 되므로
    // 비서울 도시에선 날씨 용도의 브리핑 맵을 비워서 선택 도시 데이터만 쓴다.
    final isSeoulCity =
        ref.watch(selectedCityProvider).cityId == WeatherCity.seoulCityId;
    final weatherBriefings = isSeoulCity ? briefings : const <int, Briefing>{};

    return Scaffold(
      body: WeatherBg(
        hour: currentHour,
        condition: _conditionForCurrent(
          weatherBriefings,
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
                      briefings: weatherBriefings,
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
                        final yesterdaySummaryAsync = ref.watch(
                          yesterdayDailySummaryProvider,
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
                        final yesterdaySummary =
                            switch (yesterdaySummaryAsync) {
                              AsyncData(:final value) => value,
                              _ => null,
                            };
                        final (sunrise, sunset) = switch (sunAsync) {
                          AsyncData(:final value) => value,
                          _ => (null, null),
                        };
                        return _TimelineSection(
                          summary: temperatureComparisonLine(
                            todaySummary,
                            yesterdaySummary,
                          ),
                          sky: sky,
                          briefings: weatherBriefings,
                          hourlyWeather: today,
                          currentHour: currentHour,
                          sunrise: sunrise,
                          sunset: sunset,
                        );
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _HeroCard(
                      briefings: briefings,
                      weatherBriefing: weatherBriefings[currentHour],
                      currentHour: currentHour,
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

WeatherCondition _conditionForCurrent(
  Map<int, Briefing> weatherBriefings,
  AsyncValue<Map<int, HourlyWeather>> hourlyAsync,
  int hour,
) {
  final display = resolveCurrentWeatherDisplay(
    hourly: hourlyAsync.value?[hour],
    exactBriefing: weatherBriefings[hour],
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
  const _HeroCard({
    required this.briefings,
    required this.weatherBriefing,
    required this.currentHour,
  });

  final Map<int, Briefing> briefings;

  /// 옷 추천 등 날씨 수치 해석용 — 비서울 도시에선 null (서울 스냅샷 차단).
  final Briefing? weatherBriefing;
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
      exactBriefing: weatherBriefing,
    );
    final outfitTemp = display.feelsLikeC ?? display.temperatureC;
    final outfitGuide = outfitTemp != null
        ? outfitGuideFor(outfitTemp.round())
        : null;
    final rainy = umbrellaNeeded(
      condition: display.condition,
      precipitationProb: display.precipitationProb,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          for (var i = 0; i < heroes.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _HeroBriefingCard(
              briefing: heroes[i],
              outfitGuide: outfitGuide,
              rainy: rainy,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroBriefingCard extends StatelessWidget {
  const _HeroBriefingCard({
    required this.briefing,
    required this.outfitGuide,
    required this.rainy,
  });

  final Briefing briefing;
  final OutfitGuide? outfitGuide;
  final bool rainy;

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
                    rainy: rainy,
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
class _TimelineSection extends ConsumerStatefulWidget {
  const _TimelineSection({
    required this.summary,
    required this.sky,
    required this.briefings,
    required this.hourlyWeather,
    required this.currentHour,
    this.sunrise,
    this.sunset,
  });

  final String summary;
  final SkyPalette sky;
  final Map<int, Briefing> briefings;
  final Map<int, HourlyWeather> hourlyWeather;
  final int currentHour;
  final DateTime? sunrise;
  final DateTime? sunset;

  @override
  ConsumerState<_TimelineSection> createState() => _TimelineSectionState();
}

class _TimelineSectionState extends ConsumerState<_TimelineSection> {
  // 슬롯 폭(56) + 갭(2) = 58px / slot. 슬롯엔 개별 보더가 없어서
  // 카드형(86px)보다 좁아도 시각적으로 답답하지 않다.
  static const double _slotWidth = 56.0;
  static const double _slotGap = 2.0;
  static const double _slotPitch = _slotWidth + _slotGap;
  static const double _stripHPad = 10.0;
  static const double _slotsHeight = 118.0;
  static const double _stripHeight = 140.0;
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
    final style = ref.watch(_stripStyleProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _containerHMargin,
        18,
        _containerHMargin,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카드 위 라벨 — 어제와 비교한 오늘 기온 안내.
          // 오른쪽 끝엔 배경 스타일 토글 (그림 ↔ 그라데이션).
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.summary,
                    style: TextStyle(
                      color: sky.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('timeline-style-toggle'),
                  tooltip: style == _StripStyle.doodle
                      ? '실사 하늘 배경으로 전환'
                      : '그림 배경으로 전환',
                  onPressed: () =>
                      ref.read(_stripStyleProvider.notifier).toggle(),
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(40),
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  icon: Icon(
                    style == _StripStyle.doodle
                        ? Icons.landscape_outlined
                        : Icons.brush,
                    size: 18,
                    color: sky.ink,
                  ),
                ),
              ],
            ),
          ),
          // 카드 = 24시간 스트립 그 자체. 색연필 배경이 불투명하게 꽉 채우므로
          // 글래스 블러 없이 클립 + 흰 테두리만 위에 얹는다.
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: SizedBox(
                height: _stripHeight,
                child: SingleChildScrollView(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  child: RepaintBoundary(
                    key: const Key('timeline-strip-boundary'),
                    child: SizedBox(
                      width: _stripContentWidth + (_stripHPad * 2),
                      height: _stripHeight,
                      child: Stack(
                        children: [
                          if (style == _StripStyle.gradient)
                            Positioned.fill(
                              child: Image.asset(
                                'assets/weather/timeline_sky_24h.jpg',
                                key: const Key('timeline-photo-panorama'),
                                fit: BoxFit.fill,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _CrayonSkyPainter(
                                wx: _hourlyWxKinds(
                                  widget.briefings,
                                  widget.hourlyWeather,
                                ),
                                style: style,
                                sunrise: widget.sunrise,
                                sunset: widget.sunset,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            left: _stripHPad,
                            right: _stripHPad,
                            height: _slotsHeight,
                            child: Row(
                              // 슬롯은 상단 54px만 사용하고, 아래는 파노라마와
                              // 날씨 전선이 숨 쉴 수 있도록 비워 둔다.
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List.generate(
                                24,
                                (hour) => _HourSlot(
                                  hour: hour,
                                  briefing: widget.briefings[hour],
                                  hourly: widget.hourlyWeather[hour],
                                  style: style,
                                  isNow: hour == widget.currentHour,
                                  isPast: hour < widget.currentHour,
                                  width: _slotWidth,
                                  rightGap: _slotGap,
                                ),
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
        ],
      ),
    );
  }
}

/// 색연필 strip 위 슬롯 글자색 — 잉크 본문 + 종이색 외곽선 조합이라
/// 어떤 시간대/날씨 배경 위에서도 같은 모습으로 읽힌다.
const _crayonInk = Color(0xFF2E3A55);
const _crayonPaper = Color(0xFFFBF7EE);

/// 24h strip 배경 스타일 — 색연필 그림 모드 ↔ 그라데이션 모드.
enum _StripStyle { doodle, gradient }

const _kStripStyleKey = 'hour_strip_style';

/// 라벨 줄의 토글 버튼으로 전환하고 prefs에 저장 — 재시작 후에도 유지.
class _StripStyleNotifier extends Notifier<_StripStyle> {
  @override
  _StripStyle build() {
    final saved = ref
        .read(sharedPreferencesProvider)
        .getString(_kStripStyleKey);
    return _StripStyle.values.firstWhere(
      (s) => s.name == saved,
      orElse: () => _StripStyle.doodle,
    );
  }

  Future<void> toggle() async {
    state = state == _StripStyle.doodle
        ? _StripStyle.gradient
        : _StripStyle.doodle;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kStripStyleKey, state.name);
  }
}

final _stripStyleProvider = NotifierProvider<_StripStyleNotifier, _StripStyle>(
  _StripStyleNotifier.new,
);

/// 페인터가 그릴 시간별 날씨 카테고리.
/// WeatherGlyph(아이콘용 의미 단위)를 배경 낙서용으로 한 번 더 묶은 것.
enum _WxKind {
  clear,
  partly,
  cloudy,
  rain,
  heavyRain,
  thunder,
  snow,
  heavySnow,
  sleet,
}

_WxKind _wxKindOf(WeatherGlyph glyph) => switch (glyph) {
  WeatherGlyph.sunny ||
  WeatherGlyph.night ||
  WeatherGlyph.sunrise ||
  WeatherGlyph.sunset => _WxKind.clear,
  WeatherGlyph.partlyCloudy || WeatherGlyph.partlyCloudyNight => _WxKind.partly,
  WeatherGlyph.overcast => _WxKind.cloudy,
  WeatherGlyph.rain || WeatherGlyph.shower => _WxKind.rain,
  WeatherGlyph.heavyRain => _WxKind.heavyRain,
  WeatherGlyph.rainThunder || WeatherGlyph.thunder => _WxKind.thunder,
  WeatherGlyph.snow => _WxKind.snow,
  WeatherGlyph.heavySnow => _WxKind.heavySnow,
  WeatherGlyph.sleet => _WxKind.sleet,
};

/// 시간별 날씨 → 카테고리 24개. 슬롯 아이콘이 쓰던 우선순위 그대로:
/// briefing weatherSnapshot 우선, 없으면 Open-Meteo hourly, 그것도 없으면 맑음.
List<_WxKind> _hourlyWxKinds(
  Map<int, Briefing> briefings,
  Map<int, HourlyWeather> hourly,
) {
  return List<_WxKind>.generate(24, (h) {
    final condition =
        briefings[h]?.weatherSnapshot?.condition ?? hourly[h]?.condition;
    if (condition == null) return _WxKind.clear;
    return _wxKindOf(
      weatherGlyphFor(
        condition: condition,
        isDay: true, // 카테고리 구분에만 사용 — 주/야 표현은 페인터가 직접.
        weatherCode: hourly[h]?.weatherCode,
      ),
    );
  });
}

/// 24h strip의 시간대 경계 (시간 단위, 0.0~24.0).
/// 일출/일몰 시각에 따라 경계가 좌우로 이동 — 겨울(일몰 17:00)·여름(19:30) 모두 대응.
/// Open-Meteo daily의 sunrise/sunset을 받고, 없으면 6시/19시 fallback.
class _SkyZones {
  _SkyZones({DateTime? sunrise, DateTime? sunset})
    : sr = sunrise != null ? _hourFrac(sunrise) : 6.0,
      ss = sunset != null ? _hourFrac(sunset) : 19.0;

  final double sr;
  final double ss;

  static double _hourFrac(DateTime t) => t.hour + t.minute / 60.0;

  double get dawnStart => sr - 1.3; // 밤 → 여명 보라
  double get sunriseStart => sr - 0.4; // 보라 → 일출 주황
  double get dayStart => sr + 0.8; // 주황 → 한낮 하늘색
  double get sunsetStart => ss - 1.4; // 하늘색 → 노을 주황
  double get sunsetPinkStart => ss - 0.3; // 주황 → 노을 분홍
  double get duskStart => ss + 0.5; // 분홍 → 땅거미 보라
  double get nightStart => ss + 1.3; // 보라 → 밤

  bool isNight(double hour) => hour < dawnStart || hour >= nightStart;
}

/// 색연필 한 색의 3단 셰이드 — 베이스 면 위에 밝은/어두운 빗금을 겹친다.
class _CrayonShade {
  const _CrayonShade(this.base, this.light, this.dark);

  final Color base;
  final Color light;
  final Color dark;

  static const night = _CrayonShade(
    Color(0xFF2E3868),
    Color(0xFF44549B),
    Color(0xFF232C54),
  );
  static const dawn = _CrayonShade(
    Color(0xFFA98BB5),
    Color(0xFFC0A3CB),
    Color(0xFF93729F),
  );
  static const sunriseOrange = _CrayonShade(
    Color(0xFFF7AE85),
    Color(0xFFFCC9A4),
    Color(0xFFEC9468),
  );
  static const day = _CrayonShade(
    Color(0xFFA8D2F0),
    Color(0xFFC6E4FA),
    Color(0xFF8FC0E6),
  );
  static const sunsetOrange = _CrayonShade(
    Color(0xFFF6AB77),
    Color(0xFFFBC18B),
    Color(0xFFEA8F5E),
  );
  static const sunsetPink = _CrayonShade(
    Color(0xFFEC8482),
    Color(0xFFF4A29C),
    Color(0xFFDE6C6F),
  );

  // 악천후 셰이드 — 같은 날씨라도 낮(밝은 회색 바탕)과 밤(어두운 바탕) 변형을
  // 따로 둔다. 빗줄·눈송이 색과 명도 차가 항상 나도록 하기 위함.
  static const cloudyDay = _CrayonShade(
    Color(0xFFB6C3CF),
    Color(0xFFCCD7E1),
    Color(0xFF9FB0BF),
  );
  static const cloudyNight = _CrayonShade(
    Color(0xFF3B4566),
    Color(0xFF4F5A82),
    Color(0xFF2E374F),
  );
  static const rainDay = _CrayonShade(
    Color(0xFF8EA3B6),
    Color(0xFFA6B9C9),
    Color(0xFF7A8EA1),
  );
  static const rainNight = _CrayonShade(
    Color(0xFF333E5C),
    Color(0xFF45517A),
    Color(0xFF273048),
  );
  static const snowDay = _CrayonShade(
    Color(0xFFC5D2DD),
    Color(0xFFDFE9F1),
    Color(0xFFAEBFCC),
  );
  static const snowNight = _CrayonShade(
    Color(0xFF46527A),
    Color(0xFF5A6692),
    Color(0xFF374060),
  );
}

/// 24h strip 배경 — 시간대 + 시간별 날씨를 두 가지 스타일로 표현.
/// 그림(doodle) 모드: 색연필 빗금 밴드, gradient 모드: 실사 하늘 파노라마.
/// 실사 모드는 한 장의 연속된 24시간 하늘 위에 넓은 구름 전선과 강수만
/// 합성한다. 시간마다 개별 아이콘을 놓지 않아 사진 콜라주처럼 끊기지 않는다.
class _CrayonSkyPainter extends CustomPainter {
  _CrayonSkyPainter({
    required this.wx,
    required this.style,
    this.sunrise,
    this.sunset,
  });

  /// 시간별 날씨 카테고리 24개 — 칠할 색과 낙서 종류를 결정.
  final List<_WxKind> wx;
  final _StripStyle style;
  final DateTime? sunrise;
  final DateTime? sunset;

  static const _paper = _crayonPaper;
  static const _starFill = Color(0xF2FFE9A3);
  static const _starEdge = Color(0xFFFFF3C8);
  static const _cloudEdge = Color(0xFFDCEDFA);
  static const _birdInk = Color(0xB36E3A3A);
  // 빗금 기울기 -17°. 회전 좌표계에서 밴드를 덮을 반폭 계산에 cos/sin 사용.
  static const _hatchTilt = -0.2967;
  static const _cosTilt = 0.9563;
  static const _sinTilt = 0.2924;
  // 슬롯 텍스트(시간+온도)가 차지하는 상단 영역 높이 — 낙서는 이 아래에만.
  static const _textBand = 54.0;

  @override
  void paint(Canvas canvas, Size size) {
    final zones = _SkyZones(sunrise: sunrise, sunset: sunset);
    final rng = _DoodleRng(20260611);

    switch (style) {
      case _StripStyle.doodle:
        _paintCrayonBase(canvas, size, zones, rng);
        _paintWeatherDoodles(canvas, size, zones, rng);
        // 노을 새 — 일몰 시각이 맑거나 구름 조금일 때만 (비 오면 안 날아다님).
        final sunsetKind = wx[zones.ss.floor().clamp(0, 23)];
        if (sunsetKind == _WxKind.clear || sunsetKind == _WxKind.partly) {
          _paintBirds(canvas, size, zones);
        }
      case _StripStyle.gradient:
        _paintGradientBase(canvas, size, zones);
        _paintAppleWeather(canvas, size, zones, rng);
    }
  }

  /// 색연필(그림) 모드 베이스 — 시간대/날씨 밴드 + 빗금 + 경계 스크리블 + 종이 결.
  void _paintCrayonBase(
    Canvas canvas,
    Size size,
    _SkyZones zones,
    _DoodleRng rng,
  ) {
    double hourX(double hour) => size.width * hour / 24.0;

    canvas.drawRect(Offset.zero & size, Paint()..color = _paper);

    // 1) 구간 나누기: 시간대 경계 ∪ 매시 정각. 구간별 셰이드를 정한 뒤
    //    같은 셰이드가 이어지면 병합 — 맑은 날엔 기존처럼 넓은 시간대 밴드,
    //    악천후 시간은 회색조가 시간대 색을 덮는다.
    final cuts = <double>[
      zones.dawnStart,
      zones.sunriseStart,
      zones.dayStart,
      zones.sunsetStart,
      zones.sunsetPinkStart,
      zones.duskStart,
      zones.nightStart,
      for (var h = 0; h <= 24; h++) h.toDouble(),
    ]..removeWhere((c) => c <= 0 || c >= 24);
    cuts
      ..add(0)
      ..add(24)
      ..sort();

    final segs = <(double, double, _CrayonShade)>[];
    for (var i = 0; i + 1 < cuts.length; i++) {
      final a = cuts[i];
      final b = cuts[i + 1];
      if (b - a < 1e-3) continue;
      final mid = (a + b) / 2;
      final kind = wx[mid.floor().clamp(0, 23)];
      final shade =
          _overlayShade(kind, dark: zones.isNight(mid)) ??
          _timeShade(zones, mid);
      if (segs.isNotEmpty && identical(segs.last.$3, shade)) {
        segs.last = (segs.last.$1, b, shade);
      } else {
        segs.add((a, b, shade));
      }
    }

    for (final (a, b, shade) in segs) {
      _paintBand(
        canvas,
        Rect.fromLTRB(hourX(a), 0, hourX(b), size.height),
        shade,
        rng,
      );
    }

    // 경계마다 오른쪽 밴드 색의 세로 물결 스트로크 — 손으로 문질러 섞은 느낌.
    for (var i = 1; i < segs.length; i++) {
      final bx = hourX(segs[i].$1);
      if (bx < 6 || bx > size.width - 6) continue;
      _paintBoundaryScribble(canvas, bx, size.height, segs[i].$3.base, rng);
    }

    _paintGrain(canvas, size, rng);
  }

  /// 실사 파노라마 위 분위기 레이어. 악천후 시간은 슬레이트 톤으로 가라앉히고,
  /// 상단 텍스트와 하단 수평선에는 얇은 비네트를 얹는다.
  void _paintGradientBase(Canvas canvas, Size size, _SkyZones zones) {
    final full = Offset.zero & size;

    // 악천후 워시 — 같은 날씨가 이어지는 구간을 묶어 부드럽게 덮는다.
    var start = 0;
    for (var h = 1; h <= 24; h++) {
      if (h < 24 &&
          identical(_appleWashColor(wx[h]), _appleWashColor(wx[start]))) {
        continue;
      }
      final wash = _appleWashColor(wx[start]);
      if (wash != null) {
        _paintGradientWash(
          canvas,
          size,
          left: size.width * start / 24,
          right: size.width * h / 24,
          color: wash,
        );
      }
      start = h;
    }

    // 흰 글자가 밝은 낮 하늘에서도 읽히고, 수평선은 영화처럼 가라앉는다.
    canvas.drawRect(
      full,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.24),
            Colors.black.withValues(alpha: 0.02),
            Colors.black.withValues(alpha: 0.04),
            Colors.black.withValues(alpha: 0.28),
          ],
          stops: const [0, 0.42, 0.68, 1],
        ).createShader(full),
    );
  }

  /// 애플 모드의 악천후 워시 색 (맑음/구름조금은 null — 그라데이션 유지).
  Color? _appleWashColor(_WxKind kind) => switch (kind) {
    _WxKind.clear || _WxKind.partly => null,
    _WxKind.cloudy => const Color(0xFF687888),
    _WxKind.snow || _WxKind.heavySnow => const Color(0xFF95A6BB),
    _ => const Color(0xFF4E5D70),
  };

  int _photoWeatherFamily(_WxKind kind) => switch (kind) {
    _WxKind.clear => 0,
    _WxKind.partly => 1,
    _WxKind.cloudy => 2,
    _WxKind.rain || _WxKind.heavyRain || _WxKind.thunder => 3,
    _WxKind.snow || _WxKind.heavySnow || _WxKind.sleet => 4,
  };

  /// 실사 모드 날씨 표현. 먼저 연속된 날씨 구간을 넓은 구름 전선으로 그리고,
  /// 별과 강수만 시간 단위로 얹는다. 구름이 매시간 반복되는 인상을 피한다.
  void _paintAppleWeather(
    Canvas canvas,
    Size size,
    _SkyZones zones,
    _DoodleRng rng,
  ) {
    final cellW = size.width / 24;

    var frontStart = 0;
    for (var h = 1; h <= 24; h++) {
      final family = _photoWeatherFamily(wx[frontStart]);
      if (h < 24 && _photoWeatherFamily(wx[h]) == family) continue;
      if (family != 0) {
        _paintPhotoCloudFront(
          canvas,
          size,
          left: frontStart * cellW,
          right: h * cellW,
          family: family,
          dark: zones.isNight((frontStart + h) / 2),
          rng: rng,
        );
      }
      frontStart = h;
    }

    for (var h = 0; h < 24; h++) {
      final kind = wx[h];
      final dark = zones.isNight(h + 0.5);
      final left = h * cellW;
      double jx() => left + cellW * (0.15 + rng.nextDouble() * 0.7);
      double dy(double pad) =>
          _textBand + rng.nextDouble() * (size.height - _textBand - pad);

      // 별 — 맑음/구름조금인 밤에만. 노란 낙서별 대신 흰 글로우 점.
      if (dark && (kind == _WxKind.clear || kind == _WxKind.partly)) {
        final count = kind == _WxKind.clear ? 2 : 1;
        for (var i = 0; i < count; i++) {
          _drawGlowStar(canvas, Offset(jx(), dy(14)), rng);
        }
      }

      // 강수 — 가는 흰 빗줄기 / 보드라운 눈송이 점.
      final streak = Colors.white.withValues(alpha: dark ? 0.6 : 0.66);
      double py() =>
          _textBand + 28 + rng.nextDouble() * (size.height - _textBand - 50);
      switch (kind) {
        case _WxKind.rain:
          _drawRainStreaks(canvas, Offset(jx(), py()), 4, streak, rng);
        case _WxKind.heavyRain:
          _drawRainStreaks(canvas, Offset(jx(), py()), 5, streak, rng);
          _drawRainStreaks(canvas, Offset(jx(), py()), 5, streak, rng);
        case _WxKind.thunder:
          _drawRainStreaks(canvas, Offset(jx(), py()), 4, streak, rng);
          if (h.isEven) {
            _drawGlowBolt(
              canvas,
              Offset(
                left + cellW * 0.5,
                _textBand + 34 + rng.nextDouble() * 12,
              ),
            );
          }
        case _WxKind.sleet:
          _drawRainStreaks(canvas, Offset(jx(), py()), 3, streak, rng);
          _drawSnowDots(canvas, Offset(jx(), py()), 2, rng);
        case _WxKind.snow:
          _drawSnowDots(canvas, Offset(jx(), py()), 3, rng);
        case _WxKind.heavySnow:
          _drawSnowDots(canvas, Offset(jx(), py()), 3, rng);
          _drawSnowDots(canvas, Offset(jx(), py()), 3, rng);
        case _WxKind.clear || _WxKind.partly || _WxKind.cloudy:
          break;
      }
    }
  }

  void _paintPhotoCloudFront(
    Canvas canvas,
    Size size, {
    required double left,
    required double right,
    required int family,
    required bool dark,
    required _DoodleRng rng,
  }) {
    final width = right - left;
    final partly = family == 1;
    final precipitation = family >= 3;
    final cloudCount = partly
        ? (width / 105).ceil().clamp(1, 4)
        : (width / 58).ceil().clamp(2, 18);
    final light = dark
        ? Colors.white.withValues(alpha: partly ? 0.11 : 0.16)
        : Colors.white.withValues(alpha: partly ? 0.34 : 0.44);
    final shadow = dark
        ? const Color(0x80404A5E)
        : Color(precipitation ? 0x9970808D : 0x66768591);

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        (left - 24).clamp(0, size.width),
        _textBand - 2,
        (right + 24).clamp(0, size.width),
        size.height,
      ),
    );
    for (var i = 0; i < cloudCount; i++) {
      final step = width / cloudCount;
      final x = left + step * (i + 0.5) + (rng.nextDouble() - 0.5) * step;
      final y = precipitation
          ? _textBand + 10 + rng.nextDouble() * 13
          : _textBand + 18 + rng.nextDouble() * 42;
      _drawSoftCloud(
        canvas,
        Offset(x, y),
        (partly ? 0.8 : 1.0) + rng.nextDouble() * 0.65,
        light,
        shadow,
      );
    }
    canvas.restore();
  }

  /// 흰 글로우 별 — 흐릿한 헤일로 + 또렷한 심.
  void _drawGlowStar(Canvas canvas, Offset o, _DoodleRng rng) {
    final r = 1.1 + rng.nextDouble() * 1.1;
    final a = 0.55 + rng.nextDouble() * 0.45;
    canvas.drawCircle(
      o,
      r * 2.4,
      Paint()
        ..color = Colors.white.withValues(alpha: a * 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawCircle(o, r, Paint()..color = Colors.white.withValues(alpha: a));
  }

  /// 사진 위에 얹는 저대비 구름. 어두운 밑면과 밝은 상단을 분리해
  /// 단색 흰 타원보다 실제 구름층처럼 보이게 한다.
  void _drawSoftCloud(
    Canvas canvas,
    Offset o,
    double s,
    Color light,
    Color shadow,
  ) {
    final shadowPaint = Paint()
      ..color = shadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    canvas.drawOval(
      Rect.fromCenter(
        center: o.translate(0, 6 * s),
        width: 66 * s,
        height: 21 * s,
      ),
      shadowPaint,
    );

    final lightPaint = Paint()
      ..color = light
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawOval(
      Rect.fromCenter(center: o, width: 58 * s, height: 19 * s),
      lightPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: o.translate(-15 * s, -5 * s),
        width: 34 * s,
        height: 21 * s,
      ),
      lightPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: o.translate(13 * s, -3 * s),
        width: 39 * s,
        height: 24 * s,
      ),
      lightPaint,
    );
  }

  /// 가는 빗줄기 다발.
  void _drawRainStreaks(
    Canvas canvas,
    Offset o,
    int count,
    Color color,
    _DoodleRng rng,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final x = o.dx + (i - count / 2) * (5 + rng.nextDouble() * 2);
      final y = o.dy + (rng.nextDouble() - 0.5) * 10;
      final len = 8 + rng.nextDouble() * 5;
      canvas.drawLine(Offset(x, y), Offset(x - len * 0.25, y + len), paint);
    }
  }

  /// 보드라운 눈송이 점.
  void _drawSnowDots(Canvas canvas, Offset o, int count, _DoodleRng rng) {
    for (var i = 0; i < count; i++) {
      final p = Offset(
        o.dx + (rng.nextDouble() - 0.5) * 26,
        o.dy + (rng.nextDouble() - 0.5) * 22,
      );
      final r = 1.4 + rng.nextDouble() * 1.1;
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
    }
  }

  /// 은은한 글로우 번개.
  void _drawGlowBolt(Canvas canvas, Offset o) {
    final bolt = Path()
      ..moveTo(o.dx + 3, o.dy - 10)
      ..lineTo(o.dx - 2.5, o.dy - 0.5)
      ..lineTo(o.dx + 1.5, o.dy - 1)
      ..lineTo(o.dx - 3, o.dy + 9);
    canvas.drawPath(
      bolt,
      Paint()
        ..color = const Color(0x99FFE9A8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      bolt,
      Paint()
        ..color = const Color(0xF2FFF2C2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// 좌우 가장자리가 투명하게 풀리는 세로 워시 한 장.
  void _paintGradientWash(
    Canvas canvas,
    Size size, {
    required double left,
    required double right,
    required Color color,
  }) {
    const feather = 18.0;
    final rect = Rect.fromLTRB(left - feather, 0, right + feather, size.height);
    final f = feather / rect.width;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0),
          ],
          stops: [0, f, 1 - f, 1],
        ).createShader(rect),
    );
  }

  /// 시간대(맑을 때) 셰이드.
  _CrayonShade _timeShade(_SkyZones z, double h) {
    if (h < z.dawnStart) return _CrayonShade.night;
    if (h < z.sunriseStart) return _CrayonShade.dawn;
    if (h < z.dayStart) return _CrayonShade.sunriseOrange;
    if (h < z.sunsetStart) return _CrayonShade.day;
    if (h < z.sunsetPinkStart) return _CrayonShade.sunsetOrange;
    if (h < z.duskStart) return _CrayonShade.sunsetPink;
    if (h < z.nightStart) return _CrayonShade.dawn;
    return _CrayonShade.night;
  }

  /// 악천후가 시간대 색을 덮을 때의 셰이드. 맑음/구름조금은 null(시간대 색 유지).
  _CrayonShade? _overlayShade(_WxKind kind, {required bool dark}) =>
      switch (kind) {
        _WxKind.clear || _WxKind.partly => null,
        _WxKind.cloudy =>
          dark ? _CrayonShade.cloudyNight : _CrayonShade.cloudyDay,
        _WxKind.rain ||
        _WxKind.heavyRain ||
        _WxKind.thunder ||
        _WxKind.sleet => dark ? _CrayonShade.rainNight : _CrayonShade.rainDay,
        _WxKind.snow || _WxKind.heavySnow =>
          dark ? _CrayonShade.snowNight : _CrayonShade.snowDay,
      };

  void _paintBand(
    Canvas canvas,
    Rect band,
    _CrayonShade shade,
    _DoodleRng rng,
  ) {
    canvas.drawRect(band, Paint()..color = shade.base);
    canvas.save();
    canvas.clipRect(band);
    canvas.translate(band.center.dx, band.center.dy);
    canvas.rotate(_hatchTilt);
    final halfW = (band.width * _cosTilt + band.height * _sinTilt) / 2 + 12;
    final halfH = (band.width * _sinTilt + band.height * _cosTilt) / 2 + 12;
    _dashRows(
      canvas,
      halfW: halfW,
      halfH: halfH,
      spacing: 4.7,
      strokeWidth: 2.6,
      color: shade.light.withValues(alpha: 0.75),
      rng: rng,
    );
    _dashRows(
      canvas,
      halfW: halfW,
      halfH: halfH,
      spacing: 6.9,
      phase: 2.3,
      strokeWidth: 1.6,
      color: shade.dark.withValues(alpha: 0.5),
      rng: rng,
    );
    canvas.restore();
  }

  /// 회전된 좌표계에서 가로 대시 행을 깔아 색연필 빗금을 만든다.
  void _dashRows(
    Canvas canvas, {
    required double halfW,
    required double halfH,
    required double spacing,
    required double strokeWidth,
    required Color color,
    required _DoodleRng rng,
    double phase = 0,
    double dashMin = 6,
    double dashMax = 15,
    double gapMin = 3,
    double gapMax = 7,
  }) {
    final path = Path();
    for (var y = -halfH + phase; y < halfH; y += spacing) {
      var x = -halfW - rng.nextDouble() * 8;
      while (x < halfW) {
        final dash = dashMin + rng.nextDouble() * (dashMax - dashMin);
        path.moveTo(x, y);
        path.lineTo(x + dash, y);
        x += dash + gapMin + rng.nextDouble() * (gapMax - gapMin);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintBoundaryScribble(
    Canvas canvas,
    double bx,
    double height,
    Color color,
    _DoodleRng rng,
  ) {
    final path = Path()..moveTo(bx, 2);
    var y = 2.0;
    var side = 1.0;
    while (y < height - 4) {
      final seg = 22 + rng.nextDouble() * 12;
      path.quadraticBezierTo(
        bx + side * (3.5 + rng.nextDouble() * 3.5),
        y + seg / 2,
        bx + (rng.nextDouble() - 0.5) * 2,
        y + seg,
      );
      y += seg;
      side = -side;
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );
  }

  /// 종이 결 — 빗금과 다른 방향(+8°)의 성긴 흰 대시를 전체에 얹는다.
  void _paintGrain(Canvas canvas, Size size, _DoodleRng rng) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(0.14);
    final halfW = size.width / 2 + 30;
    final halfH = (size.width * 0.14 + size.height) / 2 + 20;
    _dashRows(
      canvas,
      halfW: halfW,
      halfH: halfH,
      spacing: 9,
      strokeWidth: 1.3,
      color: Colors.white.withValues(alpha: 0.22),
      rng: rng,
      dashMin: 2,
      dashMax: 5,
      gapMin: 6,
      gapMax: 15,
    );
    canvas.restore();
  }

  /// 시간 칸(1h) 단위로 그 시간의 날씨 낙서를 그린다.
  /// 별은 맑은 밤에만, 구름은 양에 따라, 빗줄기·눈송이는 매시간 흩뿌린다.
  void _paintWeatherDoodles(
    Canvas canvas,
    Size size,
    _SkyZones zones,
    _DoodleRng rng,
  ) {
    final cellW = size.width / 24;
    for (var h = 0; h < 24; h++) {
      final kind = wx[h];
      final dark = zones.isNight(h + 0.5);
      final left = h * cellW;
      double jx() => left + cellW * (0.15 + rng.nextDouble() * 0.7);

      // 별 — 맑음/구름조금인 밤에만 (흐리면 별이 가려진다).
      // 슬롯 텍스트를 피해 _textBand 아래에만 흩뿌린다.
      double dy(double pad) =>
          _textBand + rng.nextDouble() * (size.height - _textBand - pad);
      if (dark && (kind == _WxKind.clear || kind == _WxKind.partly)) {
        if (kind == _WxKind.clear || h.isEven) {
          _drawStar(
            canvas,
            Offset(jx(), dy(16)),
            0.45 + rng.nextDouble() * 0.55,
            rng,
          );
        }
        final extra = rng.nextDouble();
        if (extra < 0.4) {
          _drawSpark(canvas, Offset(jx(), dy(12)));
        } else if (extra < 0.65) {
          canvas.drawCircle(
            Offset(jx(), dy(12)),
            1.6,
            Paint()..color = _starFill,
          );
        }
      }

      // 구름 — 구름조금은 두 시간에 하나, 흐림은 매시간 크게, 강수는 위쪽에.
      final isPrecip = switch (kind) {
        _WxKind.rain ||
        _WxKind.heavyRain ||
        _WxKind.thunder ||
        _WxKind.sleet ||
        _WxKind.snow ||
        _WxKind.heavySnow => true,
        _ => false,
      };
      final (Color, Color)? cloudColors = switch (kind) {
        _WxKind.clear => null,
        _WxKind.partly =>
          dark
              ? (const Color(0x59AAB3D4), const Color(0x806A7598))
              : (const Color(0xD9FFFFFF), _cloudEdge),
        _WxKind.cloudy =>
          dark
              ? (const Color(0x73A3ACCD), const Color(0x99626D90))
              : (const Color(0xEBF1F4F7), const Color(0xFFC4CFD8)),
        _WxKind.snow || _WxKind.heavySnow =>
          dark
              ? (const Color(0x66878FB0), const Color(0x885F6A8C))
              : (const Color(0xF0F4F7FA), const Color(0xFFC9D3DC)),
        _ =>
          dark
              ? (const Color(0x66767FA3), const Color(0x88525E84))
              : (const Color(0xEBE2E9EF), const Color(0xFFA9B8C4)),
      };
      final everyOther = kind != _WxKind.cloudy;
      final free = size.height - _textBand;
      if (cloudColors != null && (!everyOther || h.isOdd)) {
        final upper = everyOther ? (h ~/ 2).isEven : h.isEven;
        // 강수 구름은 위쪽(텍스트 바로 아래) — 빗줄·눈송이가 그 밑에 떨어진다.
        final cy = isPrecip
            ? _textBand + 8 + rng.nextDouble() * 8
            : _textBand +
                  free * (upper ? 0.22 : 0.62) +
                  (rng.nextDouble() - 0.5) * 8;
        _drawCloud(
          canvas,
          Offset(jx(), cy),
          (everyOther ? 0.6 : 0.75) + rng.nextDouble() * 0.35,
          cloudColors.$1,
          cloudColors.$2,
        );
        if (!everyOther && rng.nextDouble() < 0.35) {
          _drawCloud(
            canvas,
            Offset(jx(), _textBand + free * (upper ? 0.7 : 0.25)),
            0.5 + rng.nextDouble() * 0.2,
            cloudColors.$1,
            cloudColors.$2,
          );
        }
      }

      // 강수 낙서 — 밝은 바탕(낮)엔 진한 빗줄, 어두운 바탕(밤)엔 밝은 빗줄.
      final rainColor = dark
          ? const Color(0xCCDCE8F6)
          : const Color(0xE6486682);
      final flakeColor = dark
          ? const Color(0xE6EAF1FB)
          : const Color(0xF2FFFFFF);
      double py() =>
          _textBand + 26 + rng.nextDouble() * (size.height - _textBand - 48);
      switch (kind) {
        case _WxKind.rain:
          _drawRainCluster(canvas, Offset(jx(), py()), 1, rainColor);
          _drawRainCluster(canvas, Offset(jx(), py()), 0.85, rainColor);
        case _WxKind.heavyRain:
          for (var i = 0; i < 4; i++) {
            _drawRainCluster(canvas, Offset(jx(), py()), 1.1, rainColor);
          }
        case _WxKind.thunder:
          _drawRainCluster(canvas, Offset(jx(), py()), 0.9, rainColor);
          _drawRainCluster(canvas, Offset(jx(), py()), 0.8, rainColor);
          if (h.isEven) {
            _drawBolt(
              canvas,
              Offset(
                left + cellW * 0.5,
                _textBand + 30 + rng.nextDouble() * 14,
              ),
            );
          }
        case _WxKind.sleet:
          _drawRainCluster(canvas, Offset(jx(), py()), 0.9, rainColor);
          _drawFlake(canvas, Offset(jx(), py()), 0.9, flakeColor);
        case _WxKind.snow:
          _drawFlake(
            canvas,
            Offset(jx(), py()),
            0.8 + rng.nextDouble() * 0.4,
            flakeColor,
          );
          _drawFlake(
            canvas,
            Offset(jx(), py()),
            0.7 + rng.nextDouble() * 0.3,
            flakeColor,
          );
        case _WxKind.heavySnow:
          for (var i = 0; i < 4; i++) {
            _drawFlake(
              canvas,
              Offset(jx(), py()),
              0.9 + rng.nextDouble() * 0.5,
              flakeColor,
            );
          }
        case _WxKind.clear || _WxKind.partly || _WxKind.cloudy:
          break;
      }
    }
  }

  void _drawStar(Canvas canvas, Offset o, double scale, _DoodleRng rng) {
    final star = _starPath(scale);
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.rotate((rng.nextDouble() - 0.5) * 0.6);
    canvas.drawPath(star, Paint()..color = _starFill);
    canvas.drawPath(
      star,
      Paint()
        ..color = _starEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  void _drawSpark(Canvas canvas, Offset o) {
    canvas.drawPath(
      Path()
        ..moveTo(o.dx - 3, o.dy)
        ..lineTo(o.dx + 3, o.dy)
        ..moveTo(o.dx, o.dy - 3)
        ..lineTo(o.dx, o.dy + 3),
      Paint()
        ..color = _starFill
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawCloud(
    Canvas canvas,
    Offset o,
    double scale,
    Color fill,
    Color edge,
  ) {
    final cloud = _cloudPath(scale);
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.drawPath(cloud, Paint()..color = fill);
    canvas.drawPath(
      cloud,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  /// 빗줄기 세 가닥 낙서.
  void _drawRainCluster(Canvas canvas, Offset o, double s, Color color) {
    canvas.drawPath(
      Path()
        ..moveTo(o.dx, o.dy)
        ..relativeLineTo(-3 * s, 8 * s)
        ..moveTo(o.dx + 7 * s, o.dy - 2 * s)
        ..relativeLineTo(-3 * s, 8 * s)
        ..moveTo(o.dx + 14 * s, o.dy)
        ..relativeLineTo(-3 * s, 8 * s),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round,
    );
  }

  /// 6방향 잔가지 눈송이 (* 모양).
  void _drawFlake(Canvas canvas, Offset o, double s, Color color) {
    canvas.drawPath(
      Path()
        ..moveTo(o.dx - 4.5 * s, o.dy)
        ..lineTo(o.dx + 4.5 * s, o.dy)
        ..moveTo(o.dx - 2.2 * s, o.dy - 3.9 * s)
        ..lineTo(o.dx + 2.2 * s, o.dy + 3.9 * s)
        ..moveTo(o.dx + 2.2 * s, o.dy - 3.9 * s)
        ..lineTo(o.dx - 2.2 * s, o.dy + 3.9 * s),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  /// 노란 번개 낙서.
  void _drawBolt(Canvas canvas, Offset o) {
    canvas.drawPath(
      Path()
        ..moveTo(o.dx + 2.5, o.dy - 9)
        ..lineTo(o.dx - 2, o.dy - 0.5)
        ..lineTo(o.dx + 1.5, o.dy - 1)
        ..lineTo(o.dx - 2.5, o.dy + 8),
      Paint()
        ..color = const Color(0xFFFFD66B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// 손그림 풍 살짝 비뚠 5각 별 (scale 1.0 ≈ 반지름 6.5).
  Path _starPath(double s) {
    const pts = [
      Offset(0, -6.5),
      Offset(1.7, -2),
      Offset(6.3, -1.4),
      Offset(2.8, 1.7),
      Offset(3.9, 6.2),
      Offset(-0.2, 3.5),
      Offset(-4.3, 5.9),
      Offset(-2.8, 1.5),
      Offset(-6.4, -1.7),
      Offset(-1.9, -2.1),
    ];
    final path = Path()..moveTo(pts.first.dx * s, pts.first.dy * s);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx * s, p.dy * s);
    }
    return path..close();
  }

  /// 동글동글 낙서 구름 (scale 1.0 ≈ 폭 38).
  Path _cloudPath(double s) {
    return Path()
      ..moveTo(-14 * s, 4 * s)
      ..relativeQuadraticBezierTo(-6 * s, -1 * s, -5 * s, -7 * s)
      ..relativeQuadraticBezierTo(1 * s, -6 * s, 8 * s, -6 * s)
      ..relativeQuadraticBezierTo(2 * s, -6 * s, 9 * s, -5 * s)
      ..relativeQuadraticBezierTo(7 * s, -6 * s, 12 * s, 0)
      ..relativeQuadraticBezierTo(7 * s, -1 * s, 7 * s, 6 * s)
      ..relativeQuadraticBezierTo(0, 7 * s, -7 * s, 8 * s)
      ..relativeQuadraticBezierTo(-12 * s, 2 * s, -24 * s, 4 * s)
      ..close();
  }

  /// 노을 하늘에 갈매기 두 마리 — 'v' 낙서.
  void _paintBirds(Canvas canvas, Size size, _SkyZones zones) {
    final paint = Paint()
      ..color = _birdInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final cx = size.width * (zones.ss - 0.7) / 24;
    for (final (dx, dy, s) in [
      (-9.0, _textBand + 14, 1.0),
      (10.0, _textBand + 26, 0.8),
    ]) {
      canvas.save();
      canvas.translate(cx + dx, dy);
      canvas.scale(s);
      canvas.drawPath(
        Path()
          ..moveTo(-4, 0)
          ..quadraticBezierTo(-2, -3, 0, 0)
          ..quadraticBezierTo(2, -3, 4, 0),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CrayonSkyPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.sunrise != sunrise ||
      oldDelegate.sunset != sunset ||
      !listEquals(oldDelegate.wx, wx);
}

/// 시드 고정 LCG — 매 paint마다 동일한 낙서가 나오게 결정적 난수만 쓴다.
class _DoodleRng {
  _DoodleRng(this._state);

  int _state;

  double nextDouble() {
    _state = (_state * 1664525 + 1013904223) & 0x7fffffff;
    return _state / 0x7fffffff;
  }
}

/// 색연필 배경 어디서든 같은 모습으로 읽히는 글자 —
/// 종이색 외곽선(스트로크) 글자를 깔고 그 위에 잉크 본문을 겹친다.
class _OutlinedText extends StatelessWidget {
  const _OutlinedText(
    this.text, {
    required this.style,
    required this.strokeWidth,
  });

  final String text;

  /// color/foreground 없이 전달 — 잉크·외곽선 색은 이 위젯이 입힌다.
  final TextStyle style;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = _crayonPaper,
          ),
        ),
        Text(text, style: style.copyWith(color: _crayonInk)),
      ],
    );
  }
}

/// 연결형 strip의 한 시간 칸. 시간+온도를 상단에 얹는다.
/// 그림 모드는 종이색 외곽선 글자, 애플 모드는 흰 타이포 + 은은한 그림자.
/// 지난 시간은 통째로 흐리게, 현재 hour만 알약 배경으로 강조.
class _HourSlot extends StatelessWidget {
  const _HourSlot({
    required this.hour,
    required this.briefing,
    required this.hourly,
    required this.style,
    required this.isNow,
    required this.isPast,
    required this.width,
    required this.rightGap,
  });

  final int hour;
  final Briefing? briefing;
  final HourlyWeather? hourly;
  final _StripStyle style;
  final bool isNow;
  final bool isPast;
  final double width;
  final double rightGap;

  @override
  Widget build(BuildContext context) {
    // Briefing 데이터(메시지 있는 hour) 우선, 없으면 Open-Meteo hourly로 fallback.
    final temp =
        briefing?.weatherSnapshot?.temperatureC.round() ??
        hourly?.temperatureC.round();

    final apple = style == _StripStyle.gradient;
    final label = isNow ? '지금' : _hourLabel(hour);

    Widget slotText(
      String s,
      TextStyle base,
      double strokeW, {
      bool soft = false,
    }) {
      if (!apple) return _OutlinedText(s, style: base, strokeWidth: strokeW);
      return Text(
        s,
        style: base.copyWith(
          color: Colors.white.withValues(alpha: soft ? 0.78 : 1),
          shadows: const [
            Shadow(
              color: Color(0x4D000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
      );
    }

    // 슬롯 본체. isNow면 알약 배경 + 보더로 감싼다.
    final slot = Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: isNow
          ? BoxDecoration(
              color: Colors.white.withValues(alpha: apple ? 0.25 : 0.55),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: apple ? 0.5 : 0.8),
              ),
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
              slotText(
                label,
                TextStyle(
                  fontSize: isNow ? 11.5 : 11,
                  fontWeight: isNow ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: -0.1,
                ),
                2.4,
                soft: !isNow,
              ),
              // 시간 바로 아래 온도 — 그 아래 빈 공간은 배경 날씨 표현의 자리.
              const SizedBox(height: 3),
              slotText(
                temp != null ? '$temp°' : '—',
                TextStyle(
                  fontSize: isNow ? 20 : 18,
                  fontWeight: isNow ? FontWeight.w800 : FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: -0.3,
                ),
                3,
              ),
            ],
          ),
        ),
      ),
    );

    // 지난 시간은 통째로 흐리게 — '지금' 이후가 자연스럽게 도드라진다.
    return Padding(
      padding: EdgeInsets.only(right: rightGap),
      child: isPast ? Opacity(opacity: 0.55, child: slot) : slot,
    );
  }
}

/// 주간 카드 — 오늘부터 8일치(KMA 단기+중기)를 한 행 한 일로 보여준다.
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
          weatherGlyphAsset(
            weatherGlyphFor(
              condition: summary.condition,
              isDay: partHour >= 6 && partHour < 19,
            ),
          ),
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
