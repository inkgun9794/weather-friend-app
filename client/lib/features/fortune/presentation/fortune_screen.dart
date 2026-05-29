import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:weather_friend/app/router/main_shell.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/fortune/data/fortune_report.dart';
import 'package:weather_friend/features/fortune/data/pending_fortune.dart';
import 'package:weather_friend/features/fortune/data/saju_profile.dart';
import 'package:weather_friend/features/fortune/presentation/widgets/birth_input_form.dart';
import 'package:weather_friend/features/fortune/presentation/widgets/fortune_result_card.dart';
import 'package:weather_friend/features/fortune/presentation/widgets/score_chart_card.dart';

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

    // viewing 우선순위:
    //   진행 중인 pending(loading/ready/seen) 프로필 > 사용자 선택 > 내 프로필
    final pendingProfile =
        (pending.status == PendingFortuneStatus.loading ||
                pending.status == PendingFortuneStatus.ready ||
                pending.status == PendingFortuneStatus.seen)
            ? pending.profile
            : null;
    final viewing = pendingProfile ?? _viewingProfile ?? myProfile;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: !_profileLoaded
            ? const Center(child: CircularProgressIndicator())
            : viewing == null
                ? const _IntroAndInput()
                : _ResultView(
                    profile: viewing,
                    isMyProfile: viewing.cacheKey == myProfile?.cacheKey,
                    onViewOther: () => _showGuestInputSheet(context),
                    onEditMyProfile: () => _showEditMyProfileSheet(context),
                    onShowReports: () => context.push('/fortune/report'),
                    onSwitchToMine: () => setState(() => _viewingProfile = null),
                  ),
      ),
    );
  }

  Future<void> _showGuestInputSheet(BuildContext context) async {
    final guest = await showModalBottomSheet<SajuProfile>(
      context: context,
      isScrollControlled: true,
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
      setState(() => _viewingProfile = null);
    }
  }
}

/// 첫 진입 — 운세 소개 + 생년월일/시 입력 form.
/// 폼 저장 시 pendingFortuneProvider가 알아서 fetch + 상태 전환 (callback 불필요).
class _IntroAndInput extends StatelessWidget {
  const _IntroAndInput();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20, 24, 20,
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
              color: AppColors.ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '생년월일과 태어난 시간으로 사주를 분석해\n매일 새로운 운세를 알려드려요.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.inkMute,
            ),
          ),
          const SizedBox(height: 28),
          BirthInputForm(
            mode: BirthInputMode.primary,
            onSaved: (_) {},
          ),
        ],
      ),
    );
  }
}

/// 결과 화면 — 프로필 라벨 헤더 + 사주 카드들 + 액션 버튼.
class _ResultView extends ConsumerWidget {
  const _ResultView({
    required this.profile,
    required this.isMyProfile,
    required this.onViewOther,
    required this.onEditMyProfile,
    required this.onShowReports,
    required this.onSwitchToMine,
  });

  final SajuProfile profile;
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
              isMyProfile: isMyProfile,
              onEdit: isMyProfile ? onEditMyProfile : null,
              onBackToMine: isMyProfile ? null : onSwitchToMine,
            ),
          ),
        ),
        // 점수 + 차트 카드
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          sliver: SliverToBoxAdapter(
            child: ScoreChartCard(profile: profile, isMyProfile: isMyProfile),
          ),
        ),
        // 사주 + 일간/오행/운세 카드들
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          sliver: SliverToBoxAdapter(child: FortuneResultCard(profile: profile)),
        ),
        // 액션 버튼들
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            20, 4, 20,
            kGlassNavBarHeight + MediaQuery.paddingOf(context).bottom + 24,
          ),
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
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.isMyProfile,
    this.onEdit,
    this.onBackToMine,
  });

  final SajuProfile profile;
  final bool isMyProfile;
  final VoidCallback? onEdit;
  final VoidCallback? onBackToMine;

  @override
  Widget build(BuildContext context) {
    final cal = profile.isLunar ? '음력' : '양력';
    final birthLine =
        '$cal ${profile.year}.${profile.month.toString().padLeft(2, '0')}.${profile.day.toString().padLeft(2, '0')} '
        '${profile.hour.toString().padLeft(2, '0')}:00 · ${profile.gender.label}';

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
                      color: AppColors.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isMyProfile
                          ? AppColors.ink.withValues(alpha: 0.08)
                          : AppColors.inkMute.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      profile.relation.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isMyProfile ? AppColors.ink : AppColors.inkSoft,
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
                  color: AppColors.inkMute,
                  fontWeight: FontWeight.w500,
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
              foregroundColor: AppColors.ink,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
        else if (onEdit != null)
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 22),
            color: AppColors.inkMute,
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.inkMute.withValues(alpha: 0.22),
            ),
            borderRadius: BorderRadius.circular(14),
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
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 4,
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
