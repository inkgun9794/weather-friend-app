import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:weather_friend/app/router/main_shell.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/fortune/data/fortune_report.dart';
import 'package:weather_friend/features/fortune/data/pending_fortune.dart';
import 'package:weather_friend/features/fortune/data/saju_profile.dart';
import 'package:weather_friend/features/fortune/presentation/widgets/birth_input_form.dart';
import 'package:weather_friend/features/fortune/presentation/widgets/fortune_result_card.dart';
import 'package:weather_friend/features/fortune/presentation/widgets/score_chart_card.dart';
import 'package:weather_friend/shared/widgets/weather_bg.dart';

/// 운세 탭 메인.
///   - 내 프로필 없으면 → 입력 form
///   - 내 프로필 있으면 → 그 사람 (또는 게스트) 결과 + "다른 프로필" / "리포트" 버튼
class FortuneScreen extends ConsumerStatefulWidget {
  const FortuneScreen({super.key, this.initialProfile});

  /// 리포트에서 특정 프로필 선택해서 들어올 때 사용 (extra로 전달).
  final SajuProfile? initialProfile;

  @override
  ConsumerState<FortuneScreen> createState() => _FortuneScreenState();
}

class _FortuneScreenState extends ConsumerState<FortuneScreen> {
  bool _profileLoaded = false;

  /// 현재 화면에서 보고 있는 프로필. null이면 내 프로필.
  SajuProfile? _viewingProfile;

  @override
  void initState() {
    super.initState();
    _viewingProfile = widget.initialProfile;
    Future.microtask(_loadProfile);
  }

  @override
  void didUpdateWidget(covariant FortuneScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousKey = oldWidget.initialProfile?.cacheKey;
    final nextKey = widget.initialProfile?.cacheKey;
    if (previousKey != nextKey) {
      if (widget.initialProfile != null) {
        ref.read(pendingFortuneProvider.notifier).reset();
      }
      _viewingProfile = widget.initialProfile;
    }
  }

  Future<void> _loadProfile() async {
    final repo = await ref.read(sajuProfileRepositoryProvider.future);
    final profile = repo.load();
    if (mounted) {
      ref.read(sajuProfileProvider.notifier).set(profile);
      setState(() => _profileLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 운세 탭에 들어오면 자동으로 ready→seen 처리 (탭 툴팁 제거).
    ref.listen<PendingFortuneState>(pendingFortuneProvider, (prev, next) {
      if (next.status == PendingFortuneStatus.ready) {
        // 다음 프레임에 markSeen — build 중 state 변경 방지.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(pendingFortuneProvider.notifier).markSeen();
          }
        });
      }
    });
    // 진입 시 이미 ready였던 경우도 처리.
    final initialPending = ref.read(pendingFortuneProvider);
    if (initialPending.status == PendingFortuneStatus.ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(pendingFortuneProvider.notifier).markSeen();
        }
      });
    }

    final myProfile = ref.watch(sajuProfileProvider);
    final pending = ref.watch(pendingFortuneProvider);
    final reports = ref.watch(fortuneReportsProvider).asData?.value ?? const [];
    final hourAsync = ref.watch(kstHourProvider);
    final currentHour = switch (hourAsync) {
      AsyncData(:final value) => value,
      _ => currentHourKst(),
    };
    final sky = skyFor(currentHour);

    // viewing 우선순위:
    //   진행 중인 pending(loading/ready/seen) 프로필 > 사용자 선택 > 내 프로필
    final pendingProfile =
        (pending.status == PendingFortuneStatus.loading ||
            pending.status == PendingFortuneStatus.ready ||
            pending.status == PendingFortuneStatus.seen)
        ? pending.profile
        : null;
    final viewing = pendingProfile ?? _viewingProfile ?? myProfile;

    // viewing의 오늘 운세가 캐시(FortuneReport)에 있나? 또는 pending 진행 중인가?
    // → 있으면 결과 화면, 없으면 hub 화면 (사용자가 액션 버튼으로 트리거).
    final hasTodayResult =
        viewing != null &&
        reports.any((r) => r.profile.cacheKey == viewing.cacheKey);
    final isPendingForViewing =
        viewing != null &&
        pending.profile?.cacheKey == viewing.cacheKey &&
        (pending.status == PendingFortuneStatus.loading ||
            pending.status == PendingFortuneStatus.ready ||
            pending.status == PendingFortuneStatus.seen);
    final showResult = hasTodayResult || isPendingForViewing;

    return Scaffold(
      // 날씨 탭과 같은 시간대 그라데이션 배경.
      body: WeatherBg(
        hour: currentHour,
        child: SafeArea(
          bottom: false,
          child: !_profileLoaded
              ? Center(child: CircularProgressIndicator(color: sky.ink))
              : viewing == null
              ? _IntroAndInput(sky: sky)
              : showResult
              ? _ResultView(
                  profile: viewing,
                  sky: sky,
                  isMyProfile: viewing.cacheKey == myProfile?.cacheKey,
                  onViewOther: () => _showGuestInputSheet(context),
                  onEditMyProfile: () => _showEditMyProfileSheet(context),
                  onShowReports: () => _showReports(context),
                  onSwitchToMine: _switchToMyProfile,
                )
              : _HubView(
                  profile: viewing,
                  sky: sky,
                  isMyProfile: viewing.cacheKey == myProfile?.cacheKey,
                  onFetchFortune: () =>
                      ref.read(pendingFortuneProvider.notifier).start(viewing),
                  onViewOther: () => _showGuestInputSheet(context),
                  onEditMyProfile: () => _showEditMyProfileSheet(context),
                  onShowReports: () => _showReports(context),
                  onSwitchToMine: _switchToMyProfile,
                  hasReports: reports.isNotEmpty,
                  reportsCount: reports.length,
                ),
        ),
      ),
    );
  }

  Future<void> _showGuestInputSheet(BuildContext context) async {
    final guest = await showModalBottomSheet<SajuProfile>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _SheetWrapper(
        title: '다른 프로필 운세',
        child: BirthInputForm(
          mode: BirthInputMode.guest,
          waitForFortune: true,
          onSaved: (profile) => Navigator.of(sheetCtx).pop(profile),
        ),
      ),
    );
    if (guest != null && mounted) {
      setState(() => _viewingProfile = guest);
    }
  }

  Future<void> _showEditMyProfileSheet(BuildContext context) async {
    final current = ref.read(sajuProfileProvider);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _SheetWrapper(
        title: '사주 정보 변경',
        child: BirthInputForm(
          mode: BirthInputMode.primary,
          initialProfile: current,
          onSaved: (_) => Navigator.of(sheetCtx).pop(),
        ),
      ),
    );
    if (mounted) {
      // 내 프로필이 바뀌었으니 viewing도 초기화 (내 것 다시 보기)
      _switchToMyProfile();
    }
  }

  Future<void> _showReports(BuildContext context) async {
    final selected = await context.push<SajuProfile>('/fortune/report');
    if (!mounted || selected == null) return;

    ref.read(pendingFortuneProvider.notifier).reset();
    setState(() => _viewingProfile = selected);
  }

  void _switchToMyProfile() {
    ref.read(pendingFortuneProvider.notifier).reset();
    setState(() => _viewingProfile = null);
  }
}

/// 첫 진입 — 운세 소개 + 생년월일/시 입력 form.
/// 폼 저장 시 pendingFortuneProvider가 알아서 fetch + 상태 전환 (callback 불필요).
class _IntroAndInput extends StatelessWidget {
  const _IntroAndInput({required this.sky});

  final SkyPalette sky;

  @override
  Widget build(BuildContext context) {
    final formStyle = BirthInputFormStyle.onSky(sky);
    final textShadows = _readableTextShadows(sky);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        24,
        20,
        kGlassNavBarHeight + MediaQuery.paddingOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘의 운세',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: sky.ink,
              shadows: textShadows,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '생년월일과 태어난 시간을 바탕으로\n매일 간단한 운세를 알려드려요.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: sky.inkSoft,
              fontWeight: FontWeight.w600,
              shadows: textShadows,
            ),
          ),
          const SizedBox(height: 28),
          BirthInputForm(
            mode: BirthInputMode.primary,
            style: formStyle,
            onSaved: (_) {},
          ),
        ],
      ),
    );
  }
}

List<Shadow> _readableTextShadows(SkyPalette sky) {
  final lightText = sky.ink.computeLuminance() > 0.55;
  return [
    Shadow(
      color: (lightText ? Colors.black : Colors.white).withValues(
        alpha: lightText ? 0.2 : 0.16,
      ),
      blurRadius: 12,
      offset: const Offset(0, 1),
    ),
  ];
}

/// Hub 화면 — 오늘 안 본 프로필. 사용자가 액션 버튼으로 운세 트리거.
/// 자동 LLM 호출 방지 (광고 → 운세 흐름의 진입점).
class _HubView extends StatelessWidget {
  const _HubView({
    required this.profile,
    required this.sky,
    required this.isMyProfile,
    required this.onFetchFortune,
    required this.onViewOther,
    required this.onEditMyProfile,
    required this.onShowReports,
    required this.onSwitchToMine,
    required this.hasReports,
    required this.reportsCount,
  });

  final SajuProfile profile;
  final SkyPalette sky;
  final bool isMyProfile;
  final VoidCallback onFetchFortune;
  final VoidCallback onViewOther;
  final VoidCallback onEditMyProfile;
  final VoidCallback onShowReports;
  final VoidCallback onSwitchToMine;
  final bool hasReports;
  final int reportsCount;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // 프로필 헤더
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          sliver: SliverToBoxAdapter(
            child: _ProfileHeader(
              profile: profile,
              sky: sky,
              isMyProfile: isMyProfile,
              onEdit: isMyProfile ? onEditMyProfile : null,
              onBackToMine: isMyProfile ? null : onSwitchToMine,
            ),
          ),
        ),
        // 메인 액션 — "오늘의 운세 받기" (광고 시청 진입점)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          sliver: SliverToBoxAdapter(
            child: _PrimaryActionCard(
              name: profile.name,
              sky: sky,
              onTap: onFetchFortune,
            ),
          ),
        ),
        // 보조 액션
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                _ActionButton(
                  icon: Icons.person_add_alt_1_rounded,
                  label: '다른 프로필 운세 보기',
                  onTap: onViewOther,
                ),
                if (hasReports) ...[
                  const SizedBox(height: 10),
                  _ActionButton(
                    icon: Icons.list_alt_rounded,
                    label: '오늘 본 운세 리포트 ($reportsCount)',
                    onTap: onShowReports,
                  ),
                ],
              ],
            ),
          ),
        ),
        // 하단 패딩
        SliverPadding(
          padding: EdgeInsets.only(
            bottom:
                kGlassNavBarHeight + MediaQuery.paddingOf(context).bottom + 24,
          ),
          sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
      ],
    );
  }
}

/// "오늘의 운세 받기" — 큰 강조 버튼. 광고 시청 진입점.
class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({
    required this.name,
    required this.sky,
    required this.onTap,
  });

  final String name;
  final SkyPalette sky;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = sky.sun;
    final fg = AppColors.ink;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: fill,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 22,
                      color: fg,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$name의 오늘 운세 받기',
                          style: TextStyle(
                            color: fg,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '광고 시청 후 결과를 볼 수 있어요',
                          style: TextStyle(
                            color: fg.withValues(alpha: 0.72),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: fg.withValues(alpha: 0.8),
                    size: 24,
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

/// 결과 화면 — 프로필 라벨 헤더 + 사주 카드들 + 액션 버튼.
class _ResultView extends ConsumerWidget {
  const _ResultView({
    required this.profile,
    required this.sky,
    required this.isMyProfile,
    required this.onViewOther,
    required this.onEditMyProfile,
    required this.onShowReports,
    required this.onSwitchToMine,
  });

  final SajuProfile profile;
  final SkyPalette sky;
  final bool isMyProfile;
  final VoidCallback onViewOther;
  final VoidCallback onEditMyProfile;
  final VoidCallback onShowReports;
  final VoidCallback onSwitchToMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(fortuneReportsProvider).value ?? const [];
    final showReportsBtn = reports.length >= 2;

    return CustomScrollView(
      slivers: [
        // 헤더 — 프로필 라벨 + 편집 아이콘
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          sliver: SliverToBoxAdapter(
            child: _ProfileHeader(
              profile: profile,
              sky: sky,
              isMyProfile: isMyProfile,
              onEdit: isMyProfile ? onEditMyProfile : null,
              onBackToMine: isMyProfile ? null : onSwitchToMine,
            ),
          ),
        ),
        // 점수와 최근 흐름은 빠르게 읽을 수 있는 요약 정보로 유지.
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          sliver: SliverToBoxAdapter(child: ScoreChartCard(profile: profile)),
        ),
        // 날씨 앱에서 빠르게 읽을 수 있는 오늘의 핵심 운세.
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          sliver: SliverToBoxAdapter(
            child: FortuneTodayCards(profile: profile),
          ),
        ),
        // 액션 버튼들
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                _ActionButton(
                  icon: Icons.person_add_alt_1_rounded,
                  label: '다른 프로필 운세 보기',
                  onTap: onViewOther,
                ),
                if (showReportsBtn) ...[
                  const SizedBox(height: 10),
                  _ActionButton(
                    icon: Icons.list_alt_rounded,
                    label: '오늘 본 운세 리포트 (${reports.length})',
                    onTap: onShowReports,
                  ),
                ],
              ],
            ),
          ),
        ),
        // 상세 명리 자료는 기존처럼 맨 아래 참고 영역에 유지.
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            kGlassNavBarHeight + MediaQuery.paddingOf(context).bottom + 24,
          ),
          sliver: SliverToBoxAdapter(
            child: SajuReferenceCards(profile: profile),
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.sky,
    required this.isMyProfile,
    this.onEdit,
    this.onBackToMine,
  });

  final SajuProfile profile;
  final SkyPalette sky;
  final bool isMyProfile;
  final VoidCallback? onEdit;
  final VoidCallback? onBackToMine;

  @override
  Widget build(BuildContext context) {
    final cal = profile.isLunar ? '음력' : '양력';
    final birthLine =
        '$cal ${profile.year}.${profile.month.toString().padLeft(2, '0')}.${profile.day.toString().padLeft(2, '0')} '
        '${profile.hour.toString().padLeft(2, '0')}:00 · ${profile.gender.label}';
    final lightText = sky.ink.computeLuminance() > 0.55;
    final textShadows = _readableTextShadows(sky);
    final tagFill = lightText
        ? Colors.white.withValues(alpha: isMyProfile ? 0.22 : 0.16)
        : (isMyProfile
              ? AppColors.ink.withValues(alpha: 0.08)
              : AppColors.inkMute.withValues(alpha: 0.1));
    final tagText = lightText
        ? sky.ink
        : (isMyProfile ? AppColors.ink : AppColors.inkSoft);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    profile.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: sky.ink,
                      shadows: textShadows,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tagFill,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      profile.relation.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: tagText,
                        shadows: lightText ? textShadows : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                birthLine,
                style: TextStyle(
                  fontSize: 12,
                  color: sky.inkSoft,
                  fontWeight: FontWeight.w600,
                  shadows: textShadows,
                ),
              ),
            ],
          ),
        ),
        if (onBackToMine != null)
          TextButton.icon(
            onPressed: onBackToMine,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('내 운세'),
            style: TextButton.styleFrom(
              foregroundColor: sky.ink,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
        else if (onEdit != null)
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 22),
            color: sky.inkSoft,
            tooltip: '사주 정보 변경',
            onPressed: onEdit,
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withValues(alpha: 0.78),
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.ink, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.inkMute,
                    size: 20,
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

/// 입력 form을 감싸는 sheet wrapper — drag handle + 타이틀 + 패딩.
class _SheetWrapper extends StatelessWidget {
  const _SheetWrapper({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom:
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.inkMute.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
