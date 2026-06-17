import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/app/router/main_shell.dart';
import 'package:weather_friend/app/theme/app_dimens.dart';
import 'package:weather_friend/app/theme/app_type.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/data/air_quality_provider.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/features/briefing/data/uv_index_provider.dart';
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

/// 메인 날씨 화면 — 깔끔하고 미니멀한 중앙 정렬 레이아웃.
///
/// 현재 날씨 기반 그라데이션(WeatherBg) 위에 동일한 프로스티드
/// 글래스 카드를 올린다.
/// 위→아래: 헤더(도시·날짜) → 현재 날씨 → 시간별 → 캐릭터 브리핑 → 주간.
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
    final briefings = asyncBriefings.value ?? const <int, Briefing>{};
    // 브리핑(멘트/음성)은 비용상 서울만 생성 — 카드 콘텐츠는 도시와 무관하게
    // 노출하되, 날씨 '수치'(온도/컨디션/옷 추천)에 서울 스냅샷이 섞이면 안 되므로
    // 비서울 도시에선 날씨 용도의 브리핑 맵을 비워서 선택 도시 데이터만 쓴다.
    final isSeoulCity =
        ref.watch(selectedCityProvider).cityId == WeatherCity.seoulCityId;
    final weatherBriefings = isSeoulCity ? briefings : const <int, Briefing>{};
    final asyncHourly = ref.watch(todayHourlyWeatherProvider);
    final sky = skyFor(currentHour);

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
            // 화면 안 글래스 카드들을 같은 backdrop key로 묶어 배경 샘플링을
            // 1회로 합친다. 네비바(MainShell)는 스크롤 시 카드와 겹치므로 같은
            // 그룹에 넣지 않는다.
            child: BackdropGroup(
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _CurrentWeather(
                      briefings: weatherBriefings,
                      currentHour: currentHour,
                      sky: sky,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _HourlyStrip(
                      briefings: weatherBriefings,
                      currentHour: currentHour,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _HeroCard(
                      briefings: briefings,
                      weatherBriefing: weatherBriefings[currentHour],
                      currentHour: currentHour,
                    ),
                  ),
                  const SliverToBoxAdapter(child: _WeeklyForecastCard()),
                  // 글래스 하단바 뒤로 컨텐츠가 흘러가도록 — 마지막 항목이
                  // 가려지지 않게 바 높이 + 시스템 safe area + 약간의 숨 공간.
                  SliverPadding(
                    padding: EdgeInsets.only(
                      bottom:
                          kGlassNavBarHeight +
                          MediaQuery.paddingOf(context).bottom +
                          AppSpace.xxl,
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

/// 메인 Hero에 노출되는 알람 카드 하나.
/// - 6시~20시: 6시 카드 (음성 + 아침 안부)
/// - 21시~익일 5시: 21시 카드 (텍스트 + 잘자) — 6시 카드 자리를 교체
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

const _kMonths = [
  '1월', '2월', '3월', '4월', '5월', '6월',
  '7월', '8월', '9월', '10월', '11월', '12월', //
];
const _kWeekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 헤더에 띄울 KST 기준 "M월 D일 (요일)".
String _headerDate(DateTime kst) =>
    '${_kMonths[kst.month - 1]} ${kst.day}일 (${_kWeekdays[(kst.weekday - 1) % 7]})';

/// 일출/일몰 기준 낮/밤 판정 — 둘 다 없으면 6시~19시 휴리스틱.
bool _isDaytimeHour(int hour, DateTime? sunrise, DateTime? sunset) {
  if (sunrise == null || sunset == null) {
    return hour >= 6 && hour < 19;
  }
  final mid = hour + 0.5;
  final sr = sunrise.hour + sunrise.minute / 60.0;
  final ss = sunset.hour + sunset.minute / 60.0;
  return mid >= sr && mid < ss;
}

/// 일출/일몰 시각에 가장 가까운 정시인지 (±30분) — 해 뜨고 지는 아이콘용.
bool _isEventHour(int hour, DateTime? event) {
  if (event == null) return false;
  final eventMinutes = event.hour * 60 + event.minute;
  final nearestHour = ((eventMinutes + 30) ~/ 60).clamp(0, 23);
  return hour == nearestHour;
}

/// 모든 카드가 공유하는 단일 프로스티드 글래스 컨테이너.
/// 반투명 흰색 + BackdropFilter 블러 + 얇은 흰 헤어라인 + 둥근 모서리.
/// 화면 어디에 놓여도 같은 질감이라 카드 간 일관성이 유지된다.
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          ),
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}

/// 현재 날씨 — 날씨 아이콘 + 큰 기온 + "컨디션 · 체감 N°" 한 줄. 중앙 정렬.
/// 기온 양옆으로 습도·자외선·미세먼지 칩이 서로 다른 박자로 둥둥 떠다닌다.
class _CurrentWeather extends ConsumerStatefulWidget {
  const _CurrentWeather({
    required this.briefings,
    required this.currentHour,
    required this.sky,
  });

  /// 옷·날씨 수치 해석용 — 비서울 도시에선 비어 있음(서울 스냅샷 차단).
  final Map<int, Briefing> briefings;
  final int currentHour;
  final SkyPalette sky;

  @override
  ConsumerState<_CurrentWeather> createState() => _CurrentWeatherState();
}

class _CurrentWeatherState extends ConsumerState<_CurrentWeather>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    // 60초 주기 — 칩 주기(4·5·6초)가 모두 60의 약수라 루프 경계에서 끊김이 없다.
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hourlyAsync = ref.watch(todayHourlyWeatherProvider);
    final sunAsync = ref.watch(todaySunriseSunsetProvider);
    final hourly = switch (hourlyAsync) {
      AsyncData(:final value) => value[widget.currentHour],
      _ => null,
    };
    final (sunrise, sunset) = switch (sunAsync) {
      AsyncData(:final value) => value,
      _ => (null, null),
    };
    final display = resolveCurrentWeatherDisplay(
      hourly: hourly,
      exactBriefing: widget.briefings[widget.currentHour],
    );
    final temp = display.temperatureC?.round();
    final feels = display.feelsLikeC?.round();
    final cond = display.condition ?? '—';

    final now = nowKst();
    final glyph = weatherGlyphFor(
      condition: display.condition ?? '맑음',
      isDay: _isDaytimeHour(widget.currentHour, sunrise, sunset),
      weatherCode: hourly?.weatherCode,
      isSunrise: _isEventHour(widget.currentHour, sunrise),
      isSunset: _isEventHour(widget.currentHour, sunset),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        AppSpace.lg,
        AppSpace.xl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            ref.watch(selectedCityProvider).label,
            textAlign: TextAlign.center,
            style: AppType.title.copyWith(color: widget.sky.ink),
          ),
          const SizedBox(height: AppSpace.xxs),
          Text(
            _headerDate(now),
            textAlign: TextAlign.center,
            style: AppType.caption.copyWith(color: widget.sky.inkSoft),
          ),
          const SizedBox(height: AppSpace.xl),
          Image.asset(
            weatherGlyphAsset(glyph),
            width: 96,
            height: 96,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(height: AppSpace.sm),
          _floatingTempBand(display, temp),
          const SizedBox(height: AppSpace.xs),
          Text(
            feels != null ? '$cond · 체감 $feels°' : cond,
            textAlign: TextAlign.center,
            style: AppType.subhead.copyWith(
              color: widget.sky.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 가운데 큰 기온을 중심으로 습도·자외선·미세먼지 칩이 양옆에서 둥둥
  /// 떠다닌다. 데이터가 있는 지표만 [_floatSlots] 순서대로 자리를 잡는다.
  Widget _floatingTempBand(CurrentWeatherDisplay display, int? temp) {
    final humidity = display.humidity;
    final uvIdx = ref.watch(uvIndexProvider).value?.round();
    // 미세먼지 등급: 키가 있으면 AirKorea 공식 등급/측정값이 우선,
    // 없으면 Open-Meteo 측정값(display.pm10, 키 불필요)으로 환산 → 키 없이도 노출.
    final aq = ref.watch(airQualityProvider).value;
    final pmGrade = aq?.pm10Grade ?? pm10GradeKo(aq?.pm10 ?? display.pm10);

    final chips = <_FloatingMetricData>[
      if (humidity != null)
        _FloatingMetricData(
          icon: Icons.water_drop_rounded,
          color: const Color(0xFF55A3E0),
          value: '$humidity%',
          label: '습도',
        ),
      if (uvIdx != null)
        _FloatingMetricData(
          icon: Icons.wb_sunny_rounded,
          color: const Color(0xFFF6B33D),
          value: '$uvIdx · ${uvGradeKo(uvIdx.toDouble())}',
          label: '자외선',
        ),
      if (pmGrade != null)
        _FloatingMetricData(
          icon: Icons.blur_on_rounded,
          color: const Color(0xFF7E9B6B),
          value: pmGrade,
          label: '미세먼지',
        ),
    ];

    // 태블릿 등 넓은 화면에서 칩이 가장자리로 너무 벌어지지 않도록 폭 제한.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SizedBox(
          height: 162,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Text(
                  temp != null ? '$temp°' : '—',
                  style: AppType.hero.copyWith(
                    color: widget.sky.ink,
                    fontSize: 72,
                    fontWeight: FontWeight.w300,
                    height: 1.0,
                    letterSpacing: -2.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              for (var i = 0; i < chips.length && i < _floatSlots.length; i++)
                _FloatingMetricChip(
                  data: chips[i],
                  controller: _floatController,
                  slot: _floatSlots[i],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 떠다니는 지표 칩 한 개의 데이터.
class _FloatingMetricData {
  const _FloatingMetricData({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
}

/// 칩이 놓일 자리(alignment) + 떠다니는 리듬. [periodSeconds]는 60의 약수여야
/// 60초 루프 경계에서 위치가 튀지 않는다.
class _FloatSlot {
  const _FloatSlot(this.alignment, this.periodSeconds, this.phase);

  final Alignment alignment;
  final double periodSeconds;
  final double phase;
}

/// 온도 양옆의 불규칙한 자리들 — 칩은 데이터 순서대로 여기에 배정된다.
/// 큰 기온(가운데)을 피하도록 좌우 가장자리 쪽으로, 높이는 제각각.
const _floatSlots = <_FloatSlot>[
  _FloatSlot(Alignment(-0.96, -0.72), 5, 0), // 습도 — 좌상
  _FloatSlot(Alignment(0.98, -0.66), 4, 1.9), // 자외선 — 우상
  _FloatSlot(Alignment(-0.66, 0.86), 6, 3.6), // 미세먼지 — 좌하
];

/// 글래스 느낌의 둥근 지표 칩 — 아이콘+값+라벨. 컨트롤러에 맞춰 위아래로
/// 부드럽게 떠다니고(±8px) 아주 살짝 기운다.
class _FloatingMetricChip extends StatelessWidget {
  const _FloatingMetricChip({
    required this.data,
    required this.controller,
    required this.slot,
  });

  final _FloatingMetricData data;
  final AnimationController controller;
  final _FloatSlot slot;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: slot.alignment,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final wave = math.sin(
            2 * math.pi * (controller.value * 60 / slot.periodSeconds) +
                slot.phase,
          );
          return Transform.translate(
            offset: Offset(0, wave * 7),
            child: Transform.rotate(angle: wave * 0.03, child: child),
          );
        },
        child: _bubble(),
      ),
    );
  }

  Widget _bubble() {
    // 그림자는 clip 밖(바깥 DecoratedBox)에, 반투명 유리는 ClipOval+BackdropFilter로.
    // 앱의 _GlassCard와 같은 결(blur + white 0.55) — 뒤 하늘이 비쳐 보인다.
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 0.8,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(data.icon, size: 17, color: data.color),
                const SizedBox(height: 1),
                SizedBox(
                  width: 52,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      data.value,
                      style: AppType.subhead.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                      ),
                    ),
                  ),
                ),
                Text(
                  data.label,
                  style: AppType.micro2.copyWith(
                    color: AppColors.inkMute,
                    height: 1.1,
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

/// 시간별 예보 — 다가오는 시간들을 가로 스트립으로. 각 슬롯은
/// 시간 라벨(지금 / N시) + 날씨 아이콘 + 기온. 글래스 카드 안에 담는다.
class _HourlyStrip extends ConsumerStatefulWidget {
  const _HourlyStrip({required this.briefings, required this.currentHour});

  final Map<int, Briefing> briefings;
  final int currentHour;

  @override
  ConsumerState<_HourlyStrip> createState() => _HourlyStripState();
}

class _HourlyStripState extends ConsumerState<_HourlyStrip> {
  static const double _slotWidth = 44;
  static const double _gap = AppSpace.lg;

  final _controller = ScrollController();
  bool _didInitialScroll = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hourlyAsync = ref.watch(todayHourlyWeatherProvider);
    final sunAsync = ref.watch(todaySunriseSunsetProvider);
    final hourly = switch (hourlyAsync) {
      AsyncData(:final value) => value,
      _ => const <int, HourlyWeather>{},
    };
    final (sunrise, sunset) = switch (sunAsync) {
      AsyncData(:final value) => value,
      _ => (null, null),
    };

    // 하루 전체 0시~23시 — 데이터(예보 또는 브리핑 스냅샷)가 있는 시간만.
    final hours = <int>[
      for (var h = 0; h < 24; h++)
        if (hourly[h] != null || widget.briefings[h] != null) h,
    ];
    if (hours.isEmpty) return const SizedBox.shrink();

    // 처음 열 때 '지금'이 왼쪽에 오도록 현재 시각 위치로 점프.
    final nowIndex = hours.indexOf(widget.currentHour);
    if (!_didInitialScroll && nowIndex > 0) {
      _didInitialScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_controller.hasClients) return;
        _controller.jumpTo(
          (nowIndex * (_slotWidth + _gap)).clamp(
            0.0,
            _controller.position.maxScrollExtent,
          ),
        );
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.xxl,
        AppSpace.lg,
        0,
      ),
      child: _GlassCard(
        child: SizedBox(
          height: 116,
          child: ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: AppSpace.lg,
            ),
            itemCount: hours.length,
            separatorBuilder: (_, _) => const SizedBox(width: _gap),
            itemBuilder: (_, i) {
              final h = hours[i];
              return _HourSlot(
                hour: h,
                briefing: widget.briefings[h],
                hourly: hourly[h],
                isNow: h == widget.currentHour,
                isPast: h < widget.currentHour,
                sunrise: sunrise,
                sunset: sunset,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 시간별 스트립의 한 칸 — 시간 라벨 + 날씨 아이콘 + 기온, 세로 중앙 정렬.
/// 지나간 시간은 옅게 표시한다.
class _HourSlot extends StatelessWidget {
  const _HourSlot({
    required this.hour,
    required this.briefing,
    required this.hourly,
    required this.isNow,
    required this.isPast,
    required this.sunrise,
    required this.sunset,
  });

  final int hour;
  final Briefing? briefing;
  final HourlyWeather? hourly;
  final bool isNow;
  final bool isPast;
  final DateTime? sunrise;
  final DateTime? sunset;

  @override
  Widget build(BuildContext context) {
    // Briefing weatherSnapshot 우선, 없으면 Open-Meteo hourly로 fallback.
    final temp =
        briefing?.weatherSnapshot?.temperatureC.round() ??
        hourly?.temperatureC.round();
    final condition =
        briefing?.weatherSnapshot?.condition ?? hourly?.condition ?? '맑음';
    final glyph = weatherGlyphFor(
      condition: condition,
      isDay: _isDaytimeHour(hour, sunrise, sunset),
      weatherCode: hourly?.weatherCode,
      isSunrise: _isEventHour(hour, sunrise),
      isSunset: _isEventHour(hour, sunset),
    );
    // 하루 전체라 24시간제로 — 오전/오후 모호함 없이 '0시'~'23시'.
    final label = isNow ? '지금' : '$hour시';

    final slot = SizedBox(
      width: 44,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppType.micro.copyWith(
              color: isNow ? AppColors.ink : AppColors.inkMute,
              fontWeight: isNow ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Image.asset(
            weatherGlyphAsset(glyph),
            width: 30,
            height: 30,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            temp != null ? '$temp°' : '—',
            style: AppType.bodyLg.copyWith(
              color: AppColors.ink,
              fontWeight: isNow ? FontWeight.w700 : FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return isPast ? Opacity(opacity: 0.45, child: slot) : slot;
  }
}

/// 오늘 시간별 예보에서 [fromHour] 이후의 비 시간대를 보고 우산 배지를 정한다.
/// 17시 이후·새벽(<4시) 비는 '밤'(달), 그 외는 '낮'(해)으로 분류 —
/// 낮·밤 둘 다면 종일(우산만), 한쪽만이면 해/달, 비가 없으면 없음.
RainPhase _rainPhaseToday(
  Iterable<HourlyWeather> hours, {
  required int fromHour,
}) {
  var hasDay = false;
  var hasNight = false;
  for (final h in hours) {
    if (h.hour < fromHour) continue;
    if (!umbrellaNeeded(
      condition: h.condition,
      precipitationProb: h.precipitationProb,
    )) {
      continue;
    }
    if (h.hour >= 17 || h.hour < 4) {
      hasNight = true;
    } else {
      hasDay = true;
    }
  }
  if (hasDay && hasNight) return RainPhase.allDay;
  if (hasNight) return RainPhase.night;
  if (hasDay) return RainPhase.day;
  return RainPhase.none;
}

/// 캐릭터 브리핑 카드 — 앱의 핵심 기능. 아침/저녁 안부 + 음성 + 옷 추천.
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
    final hourlyMap = switch (hourlyAsync) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final hourly = hourlyMap?[currentHour];
    final display = resolveCurrentWeatherDisplay(
      hourly: hourly,
      exactBriefing: weatherBriefing,
    );
    final outfitTemp = display.feelsLikeC ?? display.temperatureC;
    final outfitGuide = outfitTemp != null
        ? outfitGuideFor(outfitTemp.round())
        : null;
    // 우산 배지: 오늘 '남은' 시간대의 비 예보로 없음/해/달/종일을 정한다.
    // (현재 시각만 보면 밤에 올 비를 놓쳐 우산이 안 떴음.)
    // 시간별 데이터가 아직 없으면 현재 스냅샷으로 폴백 — 시간대 불명이라 우산만.
    final rainPhase = hourlyMap != null
        ? _rainPhaseToday(hourlyMap.values, fromHour: currentHour)
        : (umbrellaNeeded(
                condition: display.condition,
                precipitationProb: display.precipitationProb,
              )
              ? RainPhase.allDay
              : RainPhase.none);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.xxl,
        AppSpace.lg,
        0,
      ),
      child: Column(
        children: [
          for (var i = 0; i < heroes.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpace.md),
            _HeroBriefingCard(
              briefing: heroes[i],
              outfitGuide: outfitGuide,
              rainPhase: rainPhase,
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
    required this.rainPhase,
  });

  final Briefing briefing;
  final OutfitGuide? outfitGuide;
  final RainPhase rainPhase;

  @override
  Widget build(BuildContext context) {
    final charId = Character.parseId(briefing.characterId);
    if (charId == null) return const SizedBox.shrink();
    final character = Character.byId(charId);
    final hasAudio = briefing.audioUrl != null;

    return _GlassCard(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CharacterPortrait(charId: charId, size: 34),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      character.displayName.split(' ').last,
                      style: AppType.body.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${_hourLabel(briefing.hour)}:00 전송',
                      style: AppType.micro.copyWith(color: AppColors.inkMute),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasAudio) ...[
            const SizedBox(height: AppSpace.md),
            AudioBubble(
              charId: charId,
              audioUrl: briefing.audioUrl!,
              neutral: true,
            ),
            if (outfitGuide != null) ...[
              const SizedBox(height: AppSpace.md),
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.ink.withValues(alpha: 0.07),
              ),
              const SizedBox(height: AppSpace.md),
              OutfitRecommendationSection(
                guide: outfitGuide!,
                characterId: charId,
                rainPhase: rainPhase,
              ),
            ],
          ] else ...[
            const SizedBox(height: AppSpace.md),
            Text(
              briefing.transcript,
              style: AppType.reading.copyWith(
                color: AppColors.ink,
                fontSize: 14.5,
                height: 1.55,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 주간 카드 — 오늘부터 8일치(KMA 단기+중기)를 한 행 한 일로 보여준다.
/// 각 행은 [요일 라벨 | 오전 | 오후 | 저녁] (아이콘+기온) 구성.
/// 오늘 행은 라벨 "오늘" + bolder weight로 살짝 강조.
class _WeeklyForecastCard extends ConsumerWidget {
  const _WeeklyForecastCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weekDaysProvider);
    final days = switch (async) {
      AsyncData(:final value) => value,
      _ => const <WeekDay>[],
    };
    if (days.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.xxl,
        AppSpace.lg,
        0,
      ),
      child: _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.lg,
                AppSpace.lg,
                AppSpace.sm,
              ),
              child: Text(
                '주간 날씨',
                style: AppType.headline.copyWith(color: AppColors.ink),
              ),
            ),
            // 컬럼 헤더 (오전/오후/저녁) — 한 번만 표시해서 각 행 의미 명확.
            const _WeekColumnHeaders(),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              color: AppColors.ink.withValues(alpha: 0.08),
            ),
            for (var i = 0; i < days.length; i++) ...[
              _WeekDayRow(day: days[i], isToday: i == 0),
              if (i < days.length - 1)
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                  color: AppColors.ink.withValues(alpha: 0.05),
                ),
            ],
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
  }
}

class _WeekColumnHeaders extends StatelessWidget {
  const _WeekColumnHeaders();

  @override
  Widget build(BuildContext context) {
    final style = AppType.micro.copyWith(
      color: AppColors.inkMute,
      letterSpacing: 0.6,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        0,
        AppSpace.lg,
        AppSpace.xs,
      ),
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
  const _WeekDayRow({required this.day, required this.isToday});

  final WeekDay day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final label = isToday ? '오늘' : _weekdayChar(day.weekday);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.md,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: AppType.body.copyWith(
                color: AppColors.ink,
                fontSize: isToday ? 14 : 13.5,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: _PartCell(summary: day.morning, partHour: 9)),
          Expanded(child: _PartCell(summary: day.afternoon, partHour: 14)),
          Expanded(child: _PartCell(summary: day.evening, partHour: 20)),
        ],
      ),
    );
  }

  static String _weekdayChar(int weekday) {
    // DateTime.weekday: 1=Mon … 7=Sun.
    return _kWeekdays[(weekday - 1) % 7];
  }
}

class _PartCell extends StatelessWidget {
  const _PartCell({required this.summary, this.partHour = 12});

  final DayPartSummary summary;
  // morning ~9시 / afternoon ~14시 / evening ~20시.
  // weekly 카드는 day-level이라 sunrise/sunset 정확한 값을 알 수 없음 →
  // 일출/일몰 없이 6시~19시 휴리스틱으로 낮/밤만 판단.
  final int partHour;

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(height: AppSpace.xs),
        Text(
          '${summary.tempC}°',
          style: AppType.body.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
