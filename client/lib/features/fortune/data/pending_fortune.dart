import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/features/fortune/data/fortune_api.dart';
import 'package:weather_friend/features/fortune/data/saju_profile.dart';

/// 백그라운드 운세 fetch의 진행 상태.
///
/// idle → loading → ready → seen (사용자가 운세 탭 진입 시) → idle
/// loading 중 다른 profile.start() 호출 시 race condition은 cacheKey 비교로 처리.
enum PendingFortuneStatus { idle, loading, ready, seen, error }

class PendingFortuneState {
  const PendingFortuneState({
    required this.status,
    this.profile,
    this.error,
  });

  final PendingFortuneStatus status;
  final SajuProfile? profile;
  final Object? error;

  static const initial =
      PendingFortuneState(status: PendingFortuneStatus.idle);

  PendingFortuneState copyWith({
    PendingFortuneStatus? status,
    SajuProfile? profile,
    Object? error,
    bool clearProfile = false,
    bool clearError = false,
  }) =>
      PendingFortuneState(
        status: status ?? this.status,
        profile: clearProfile ? null : (profile ?? this.profile),
        error: clearError ? null : (error ?? this.error),
      );

  bool get isLoading => status == PendingFortuneStatus.loading;
  bool get isUnread => status == PendingFortuneStatus.ready;
}

/// 운세 fetch 상태 관리자. UI 어디서든 watch해서 로딩/툴팁 처리.
class PendingFortuneNotifier extends Notifier<PendingFortuneState> {
  @override
  PendingFortuneState build() => PendingFortuneState.initial;

  /// 백그라운드로 fetch 시작. 같은 profile이 이미 loading 중이면 no-op.
  /// 실제 결과는 fortuneForProfileProvider(profile)에서 가져오면 됨.
  Future<void> start(SajuProfile profile) async {
    // 동일 profile이 진행 중이면 중복 시작 X.
    if (state.status == PendingFortuneStatus.loading &&
        state.profile?.cacheKey == profile.cacheKey) {
      return;
    }
    state = PendingFortuneState(
      status: PendingFortuneStatus.loading,
      profile: profile,
    );

    try {
      // 실제 fetch는 fortuneForProfileProvider에서 (캐싱 + 리포트 자동 저장).
      await ref.read(fortuneForProfileProvider(profile).future);
      // race: 그 사이 다른 profile.start() 호출됐으면 무시.
      if (state.profile?.cacheKey != profile.cacheKey) return;
      state = state.copyWith(status: PendingFortuneStatus.ready);
    } catch (e) {
      if (state.profile?.cacheKey != profile.cacheKey) return;
      state = state.copyWith(status: PendingFortuneStatus.error, error: e);
    }
  }

  /// 사용자가 운세 탭으로 진입 → ready 상태면 seen 처리 (툴팁 제거).
  void markSeen() {
    if (state.status == PendingFortuneStatus.ready) {
      state = state.copyWith(status: PendingFortuneStatus.seen);
    }
  }

  /// 명시적 리셋 (필요 시).
  void reset() {
    state = PendingFortuneState.initial;
  }
}

final pendingFortuneProvider =
    NotifierProvider<PendingFortuneNotifier, PendingFortuneState>(
        PendingFortuneNotifier.new);
