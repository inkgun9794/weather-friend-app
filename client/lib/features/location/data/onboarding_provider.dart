import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';

const _kKey = 'onboarding_complete';

/// 첫 실행이면 false, 사용자가 온보딩 완료하면 true로 영구 저장.
///
/// `build()`는 `sharedPreferencesProvider`(main에서 pre-load) 에서 동기로 읽어
/// race 없이 정확한 초기값을 돌려준다. 이전엔 `_load()`를 fire-and-forget해서
/// 라우터가 `false`를 본 뒤 `_load()`가 늦게 `true`로 갱신 → 사용자가 cold start
/// 마다 온보딩을 다시 보던 버그가 있었음.
class OnboardingCompleteNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_kKey) ?? false;
  }

  Future<void> markComplete() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_kKey, true);
    state = true;
  }
}

final onboardingCompleteProvider =
    NotifierProvider<OnboardingCompleteNotifier, bool>(
      OnboardingCompleteNotifier.new,
    );
