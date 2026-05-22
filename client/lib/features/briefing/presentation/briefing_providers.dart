import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/data/briefing_repository.dart';
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

final todayBriefingsProvider = FutureProvider<Map<int, Briefing>>((ref) async {
  final repo = ref.watch(briefingRepositoryProvider);
  final character = ref.watch(selectedCharacterProvider);
  return repo.fetchDay(
    city: _defaultCity,
    date: todayKstIso(),
    characterId: character.name,
  );
});
