import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/app/router/main_shell.dart';
import 'package:weather_friend/app/theme/app_dimens.dart';
import 'package:weather_friend/app/theme/app_type.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/live/data/cctv_camera.dart';
import 'package:weather_friend/features/live/data/its_cctv_client.dart';
import 'package:weather_friend/features/live/data/live_providers.dart';
import 'package:weather_friend/features/live/data/seoul_districts.dart';
import 'package:weather_friend/features/live/presentation/widgets/camera_tile.dart';
import 'package:weather_friend/features/live/presentation/widgets/cctv_player.dart';
import 'package:weather_friend/features/location/data/city_catalog.dart';
import 'package:weather_friend/features/location/data/selected_city_provider.dart';
import 'package:weather_friend/shared/widgets/weather_bg.dart';

/// 라이브 탭 — 선택 지역 근처 교통 CCTV로 "지금 비가 오는지"를 눈으로 확인.
///
/// 서울이면 구 칩으로 중심을 고르고, 그 외 도시는 도시 중심 좌표를 쓴다.
class LiveScreen extends ConsumerWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = currentHourKst();
    final isActive = ref.watch(activeTabIndexProvider) == kLiveTabIndex;

    return Scaffold(
      body: WeatherBg(
        hour: hour,
        child: SafeArea(
          bottom: false,
          child: itsApiKey.isEmpty
              ? const _SetupNeeded()
              : _LiveBody(active: isActive),
        ),
      ),
    );
  }
}

class _LiveBody extends ConsumerStatefulWidget {
  const _LiveBody({required this.active});

  final bool active;

  @override
  ConsumerState<_LiveBody> createState() => _LiveBodyState();
}

class _LiveBodyState extends ConsumerState<_LiveBody> {
  /// 사용자가 탭해 고른 카메라(null이면 가장 가까운 살아있는 카메라 자동 선택).
  CctvCamera? _selected;

  /// 재생에 실패한(죽은) 카메라 — 좌표 식별. featured 자동 선택에서 제외하고
  /// 목록엔 "응답없음"으로 표시. 당겨서 새로고침 시 초기화해 다시 시도.
  final Set<CctvCamera> _dead = {};

  /// 마지막 토큰 갱신 시각 — 짧은 창 안에선 갱신 대신 죽은 카메라로 확정(루프 방지).
  DateTime? _lastRenew;

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(cctvFeedProvider);
    final city = ref.watch(selectedCityProvider);
    final isSeoul = city.cityId == WeatherCity.seoulCityId;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _dead.clear();
          _lastRenew = null;
        });
        ref.invalidate(currentLatLngProvider);
        ref.invalidate(cctvFeedProvider);
        try {
          await ref.read(cctvFeedProvider.future);
        } catch (_) {
          // 에러 상태는 아래 슬리버에서 표시.
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Header(cityLabel: city.label)),
          if (isSeoul) const SliverToBoxAdapter(child: _GuChips()),
          ...feedAsync.when(
            // 토큰 자동 갱신(invalidate) 중엔 기존 목록을 유지(전체 스피너 깜빡임 방지).
            skipLoadingOnRefresh: true,
            data: _dataSlivers,
            loading: () => const <Widget>[
              SliverFillRemaining(hasScrollBody: false, child: _Loading()),
            ],
            error: (_, _) => <Widget>[
              SliverFillRemaining(
                hasScrollBody: false,
                child: _Notice(
                  icon: Icons.cloud_off_rounded,
                  text: '카메라 정보를 불러오지 못했어요',
                  onRetry: () => ref.invalidate(cctvFeedProvider),
                ),
              ),
            ],
          ),
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
    );
  }

  List<Widget> _dataSlivers(CctvFeed feed) {
    final cameras = feed.cameras;
    if (cameras.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Notice(
            icon: Icons.videocam_off_rounded,
            text: '이 지역 근처엔 교통 CCTV가 없어요',
            onRetry: () => ref.invalidate(cctvFeedProvider),
          ),
        ),
      ];
    }

    final featured = _pickFeatured(cameras);
    if (featured == null) {
      // 주변 카메라가 전부 응답하지 않음.
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Notice(
            icon: Icons.videocam_off_rounded,
            text: '주변 카메라가 모두 응답하지 않아요',
            onRetry: _resetAndReload,
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: _Featured(
          camera: featured,
          active: widget.active,
          onFailed: () => _onFeaturedFailed(featured),
        ),
      ),
      SliverToBoxAdapter(child: _SectionLabel('근처 카메라 ${cameras.length}곳')),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        sliver: SliverList.separated(
          itemCount: cameras.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm),
          itemBuilder: (_, i) {
            final cam = cameras[i];
            return CameraTile(
              camera: cam,
              center: feed.center,
              selected: cam == featured,
              dead: _dead.contains(cam),
              onTap: () => setState(() {
                _selected = cam;
                _dead.remove(cam); // 직접 고르면 다시 시도 기회를 준다.
              }),
            );
          },
        ),
      ),
    ];
  }

  /// 표시할 featured 카메라 — 사용자가 고른 게 살아있으면 그것, 아니면 가장 가까운
  /// 살아있는 카메라. 전부 죽었으면 null.
  CctvCamera? _pickFeatured(List<CctvCamera> cameras) {
    if (_selected != null) {
      for (final c in cameras) {
        if (c == _selected && !_dead.contains(c)) return c;
      }
    }
    for (final c in cameras) {
      if (!_dead.contains(c)) return c;
    }
    return null;
  }

  /// featured 영상이 실패했을 때: 먼저 토큰 만료를 가정해 1회 갱신(같은 카메라를
  /// 새 토큰으로 재시도). 그래도 실패하면 죽은 카메라로 확정해 다음으로 자동 전환.
  void _onFeaturedFailed(CctvCamera cam) {
    final now = DateTime.now();
    final renewedRecently =
        _lastRenew != null &&
        now.difference(_lastRenew!) < const Duration(seconds: 12);
    if (!renewedRecently) {
      _lastRenew = now;
      ref.invalidate(cctvFeedProvider);
    } else {
      setState(() => _dead.add(cam));
    }
  }

  void _resetAndReload() {
    setState(() {
      _dead.clear();
      _lastRenew = null;
    });
    ref.invalidate(currentLatLngProvider);
    ref.invalidate(cctvFeedProvider);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.cityLabel});

  final String cityLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.lg,
        AppSpace.lg,
        AppSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$cityLabel 실시간',
            style: AppType.titleLg.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 2),
          Text(
            '도로 CCTV로 지금 비가 오는지 확인해요',
            style: AppType.caption.copyWith(color: AppColors.inkMute),
          ),
        ],
      ),
    );
  }
}

class _GuChips extends ConsumerWidget {
  const _GuChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final districtsAsync = ref.watch(seoulDistrictsProvider);
    // null = '내 위치'(GPS) 모드. 특정 구를 고르면 그 구로 중심을 옮긴다.
    final manual = ref.watch(liveSelectedGuProvider);

    return districtsAsync.maybeWhen(
      data: (districts) {
        if (districts.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            itemCount: districts.length + 1, // 맨 앞 '내 위치'
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
            itemBuilder: (_, i) {
              if (i == 0) {
                return _GuChip(
                  label: '내 위치',
                  icon: Icons.my_location_rounded,
                  selected: manual == null,
                  onTap: () =>
                      ref.read(liveSelectedGuProvider.notifier).set(null),
                );
              }
              final name = districts[i - 1].name;
              return _GuChip(
                label: name,
                selected: name == manual,
                onTap: () =>
                    ref.read(liveSelectedGuProvider.notifier).set(name),
              );
            },
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _GuChip extends StatelessWidget {
  const _GuChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.inkSoft;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.ink
                : Colors.white.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.6),
              width: 0.6,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: fg),
                const SizedBox(width: 4),
              ],
              Text(label, style: AppType.label.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Featured extends StatelessWidget {
  const _Featured({
    required this.camera,
    required this.active,
    required this.onFailed,
  });

  final CctvCamera camera;
  final bool active;
  final VoidCallback onFailed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.md,
        AppSpace.lg,
        AppSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            // ValueKey로 카메라가 바뀌면 플레이어를 새로 만들어 컨트롤러를 교체.
            child: CctvPlayer(
              key: ValueKey(camera.streamUrl),
              camera: camera,
              active: active,
              onFailed: onFailed,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  camera.name.replaceAll(RegExp(r'\s+'), ' ').trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.subhead.copyWith(color: AppColors.ink),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              _RoadBadge(roadType: camera.roadType),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoadBadge extends StatelessWidget {
  const _RoadBadge({required this.roadType});

  final String roadType;

  @override
  Widget build(BuildContext context) {
    final label = roadType == 'ex' ? '고속도로' : '도로';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppType.micro.copyWith(color: AppColors.inkSoft),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.sm,
        AppSpace.lg,
        AppSpace.sm,
      ),
      child: Text(
        text,
        style: AppType.label.copyWith(color: AppColors.inkMute),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.ink),
      ),
    );
  }
}

/// 에러/빈 목록 공통 안내 + 다시 시도.
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, required this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: AppColors.inkMute),
            const SizedBox(height: AppSpace.sm),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppType.subhead.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: AppSpace.md),
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

/// ITS_API_KEY 미주입 시 — 크래시 대신 설정 안내.
class _SetupNeeded extends StatelessWidget {
  const _SetupNeeded();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_outlined, size: 40, color: AppColors.inkMute),
            const SizedBox(height: AppSpace.md),
            Text(
              '실시간 CCTV 설정이 필요해요',
              style: AppType.title.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'its.go.kr에서 무료 인증키를 받아\n'
              '--dart-define=ITS_API_KEY 로 실행하면\n'
              '근처 도로 CCTV가 여기에 표시돼요.',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: AppColors.inkMute),
            ),
          ],
        ),
      ),
    );
  }
}
