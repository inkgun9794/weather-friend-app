import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/core/services/notification_service.dart';
import 'package:weather_friend/features/location/data/onboarding_provider.dart';
import 'package:weather_friend/features/record/data/diary_repository.dart';
import 'package:weather_friend/features/record/data/reminder_repository.dart';
import 'package:weather_friend/features/record/domain/diary_entry.dart';

/// 오후 7시까지 오늘 기록을 안 했으면 로컬 리마인더를 띄운다.
///
/// 기록 데이터가 기기에만 있어 "미작성 조건"을 서버가 알 수 없으므로 로컬에서 처리한다:
/// 오늘 미작성이면 19:00 one-shot 예약, 기록하면 취소. 앱이 며칠 닫혀 있어도 대비하려고
/// 향후 [_windowDays]일치를 미리 예약한다(앱을 연 날엔 그날 sync가 해당 알림을 취소).
/// 앱을 안 연 날은 어차피 기록이 불가능하니 그날 알림이 그대로 발사되는 게 맞다.
class RecordReminderCoordinator extends ConsumerStatefulWidget {
  const RecordReminderCoordinator({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RecordReminderCoordinator> createState() =>
      _RecordReminderCoordinatorState();
}

class _RecordReminderCoordinatorState
    extends ConsumerState<RecordReminderCoordinator>
    with WidgetsBindingObserver {
  static const int _baseId = 4100;
  static const int _windowDays = 7;
  static const int _hour = 19; // 오후 7시

  Timer? _midnightTimer;
  bool _syncing = false;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    _scheduleMidnightResync();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync();
      _scheduleMidnightResync();
    }
  }

  void _scheduleMidnightResync() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      _sync();
      _scheduleMidnightResync();
    });
  }

  /// 중복 호출 방지 — 진행 중이면 한 번만 추가로 다시 돌려 최신 상태를 반영한다.
  Future<void> _sync() async {
    if (_syncing) {
      _pending = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _pending = false;
        await _doSync();
      } while (_pending);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _doSync() async {
    if (!ref.read(onboardingCompleteProvider)) return;
    final notifications = ref.read(notificationServiceProvider);

    // 권한 없으면 예약하지 않고, 남아 있던 예약도 정리.
    if (!await notifications.hasPermission()) {
      for (var i = 0; i < _windowDays; i++) {
        await notifications.cancel(_baseId + i);
      }
      return;
    }

    final entries = ref.read(diaryListProvider);
    final content = await ref.read(reminderRepositoryProvider).load();
    final now = DateTime.now();

    for (var offset = 0; offset < _windowDays; offset++) {
      final id = _baseId + offset;
      await notifications.cancel(id);

      final day = DateTime(now.year, now.month, now.day + offset);
      final fireAt = DateTime(day.year, day.month, day.day, _hour);
      if (!fireAt.isAfter(now)) continue; // 이미 지난 시각
      // 그날 이미 기록했으면 예약 안 함(현실적으로 offset 0에서만 발생).
      if (entries.any((e) => isSameDay(e.createdAt, day))) continue;

      await notifications.scheduleRecordReminder(
        id: id,
        title: content.title,
        body: content.messageFor(day),
        scheduledAt: fireAt,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 기록이 추가/수정/삭제되면 즉시 재동기화(오늘 기록 시 알림 취소).
    ref.listen(diaryListProvider, (_, _) => _sync());
    // 온보딩 완료 직후에도 한 번.
    ref.listen<bool>(onboardingCompleteProvider, (prev, next) {
      if (prev != true && next == true) _sync();
    });
    return widget.child;
  }
}
