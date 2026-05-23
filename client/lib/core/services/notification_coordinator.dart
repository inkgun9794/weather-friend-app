import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/core/services/notification_service.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/data/briefing_repository.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/features/location/data/onboarding_provider.dart';

const _defaultCity = 'seoul';

/// 알림 본문 갱신 + 재예약을 조율한다.
///
/// 트리거:
///  - 앱 시작 직후 (onboarding 완료 상태에서)
///  - 앱이 foreground로 돌아올 때
///  - 선택한 캐릭터가 바뀔 때
///
/// 동작:
///  1. Firestore에서 오늘의 morning(05시) / evening(21시) 브리핑 transcript fetch
///  2. 권한이 있으면 두 슬롯을 새 본문으로 재예약 (없으면 무시)
class NotificationCoordinator extends ConsumerStatefulWidget {
  const NotificationCoordinator({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationCoordinator> createState() =>
      _NotificationCoordinatorState();
}

class _NotificationCoordinatorState
    extends ConsumerState<NotificationCoordinator> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (!ref.read(onboardingCompleteProvider)) return;

    final service = ref.read(notificationServiceProvider);
    if (!await service.hasPermission()) return;

    final repo = ref.read(briefingRepositoryProvider);
    final character = ref.read(selectedCharacterProvider);
    final date = todayKstIso();

    final bodies = <BriefingSlot, String>{};
    try {
      final results = await Future.wait([
        repo.fetchOne(
          city: _defaultCity,
          date: date,
          hour: BriefingSlot.morning.hour,
          characterId: character.name,
        ),
        repo.fetchOne(
          city: _defaultCity,
          date: date,
          hour: BriefingSlot.evening.hour,
          characterId: character.name,
        ),
      ]);
      final morning = results[0];
      final evening = results[1];
      if (morning != null) bodies[BriefingSlot.morning] = morning.transcript;
      if (evening != null) bodies[BriefingSlot.evening] = evening.transcript;
    } catch (_) {
      // 네트워크 실패 — fallback 문구로라도 예약 유지
    }

    await service.scheduleDailyBriefings(bodies: bodies);
  }

  @override
  Widget build(BuildContext context) {
    // 캐릭터 변경 시 재예약
    ref.listen<CharacterId>(selectedCharacterProvider, (prev, next) {
      if (prev != next) _refresh();
    });
    // 온보딩 완료로 바뀌면 재예약
    ref.listen<bool>(onboardingCompleteProvider, (prev, next) {
      if (prev != true && next == true) _refresh();
    });
    return widget.child;
  }
}
