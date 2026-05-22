import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/data/briefing_repository.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/character/domain/character.dart';

const _defaultCity = 'seoul';

class SelectedCharacterNotifier extends Notifier<CharacterId> {
  @override
  CharacterId build() => CharacterId.jiyoung;

  void set(CharacterId id) => state = id;
}

final selectedCharacterProvider =
    NotifierProvider<SelectedCharacterNotifier, CharacterId>(
      SelectedCharacterNotifier.new,
    );

/// KST 자정마다 새 ISO date를 emit. 0시 도래 시 date 의존 provider들 자동 invalidate.
final kstDateProvider = StreamProvider<String>((ref) async* {
  yield todayKstIso();
  while (true) {
    await Future<void>.delayed(untilNextKstMidnight());
    yield todayKstIso();
  }
});

/// KST 정시마다 새 hour를 emit. 매시간 0분에 hour 의존 위젯 자동 rebuild.
final kstHourProvider = StreamProvider<int>((ref) async* {
  yield currentHourKst();
  while (true) {
    await Future<void>.delayed(untilNextKstHour());
    yield currentHourKst();
  }
});

final todayBriefingsProvider = FutureProvider<Map<int, Briefing>>((ref) async {
  final dateAsync = ref.watch(kstDateProvider);
  final date = switch (dateAsync) {
    AsyncData(:final value) => value,
    _ => todayKstIso(),
  };
  final repo = ref.watch(briefingRepositoryProvider);
  final character = ref.watch(selectedCharacterProvider);
  return repo.fetchDay(
    city: _defaultCity,
    date: date,
    characterId: character.name,
  );
});

/// twoDayWeatherProvider를 wrap — kstDateProvider watch해서 자정에 새로 fetch.
/// (open_meteo_client.dart의 raw provider는 그대로 두고, 여기서 시간 의존성 추가.)
final reactiveTwoDayWeatherProvider = FutureProvider<TwoDayWeather>((ref) async {
  ref.watch(kstDateProvider); // 자정에 새 fetch 트리거
  ref.invalidate(twoDayWeatherProvider);
  return ref.watch(twoDayWeatherProvider.future);
});
