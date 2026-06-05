import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/data/briefing_repository.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';
import 'package:weather_friend/features/location/data/selected_city_provider.dart';

const _defaultCity = 'seoul';
const _selectedCharacterKey = 'selected_character_id';

class SelectedCharacterNotifier extends Notifier<CharacterId> {
  @override
  CharacterId build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getString(_selectedCharacterKey);
    return saved == null
        ? CharacterId.jiyoung
        : (Character.parseId(saved) ?? CharacterId.jiyoung);
  }

  Future<void> set(CharacterId id) async {
    if (state == id) return;
    state = id;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_selectedCharacterKey, id.name);
  }
}

final selectedCharacterProvider =
    NotifierProvider<SelectedCharacterNotifier, CharacterId>(
      SelectedCharacterNotifier.new,
    );

/// 사이클 경계(KST 05시)마다 새 ISO date를 emit. 05시 도래 시 date 의존 provider들 자동 invalidate.
final kstDateProvider = StreamProvider<String>((ref) async* {
  yield todayKstIso();
  while (true) {
    await Future<void>.delayed(untilNextKstCycleStart());
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
  final city = ref.watch(selectedCityProvider);
  final briefingCity = city.briefingCityKey;
  final selectedCityBriefings = await repo.fetchDay(
    city: briefingCity,
    date: date,
    characterId: character.name,
  );
  if (selectedCityBriefings.isNotEmpty || briefingCity == _defaultCity) {
    return selectedCityBriefings;
  }

  // The worker currently generates AI/audio briefings for Seoul only. Weather
  // cards still use the selected KMA city; this avoids showing Seoul text for
  // a non-Seoul location until per-city briefings are generated server-side.
  return const <int, Briefing>{};
});

/// weatherBundleProvider를 wrap — kstDateProvider watch해서 사이클 경계(05시)에 새로 fetch.
/// (open_meteo_client.dart의 raw provider는 그대로 두고, 여기서 시간 의존성 추가.)
final reactiveWeatherBundleProvider = FutureProvider<WeatherBundle>((
  ref,
) async {
  ref.watch(kstDateProvider); // 05시 경계에 새 fetch 트리거
  ref.invalidate(weatherBundleProvider);
  return ref.watch(weatherBundleProvider.future);
});
