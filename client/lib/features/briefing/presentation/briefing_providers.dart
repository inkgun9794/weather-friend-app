import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/data/briefing_repository.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';

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

class TodayBriefingsNotifier extends AsyncNotifier<Map<int, Briefing>> {
  bool _refreshing = false;

  @override
  Future<Map<int, Briefing>> build() async {
    final dateAsync = ref.watch(kstDateProvider);
    ref.watch(kstHourProvider);
    final date = switch (dateAsync) {
      AsyncData(:final value) => value,
      _ => todayKstIso(),
    };
    final character = ref.watch(selectedCharacterProvider);
    final repo = ref.read(briefingRepositoryProvider);
    final cached = repo.readCachedDay(
      city: _defaultCity,
      date: date,
      characterId: character.name,
    );

    if (cached != null) {
      unawaited(
        Future<void>.microtask(
          () => _refresh(date: date, character: character, silent: true),
        ),
      );
      return cached;
    }

    return repo.fetchDay(
      city: _defaultCity,
      date: date,
      characterId: character.name,
    );
  }

  Future<void> refresh() async {
    final dateAsync = ref.read(kstDateProvider);
    final date = switch (dateAsync) {
      AsyncData(:final value) => value,
      _ => todayKstIso(),
    };
    await _refresh(
      date: date,
      character: ref.read(selectedCharacterProvider),
      silent: false,
    );
  }

  Future<void> _refresh({
    required String date,
    required CharacterId character,
    required bool silent,
  }) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final fresh = await ref
          .read(briefingRepositoryProvider)
          .fetchDay(
            city: _defaultCity,
            date: date,
            characterId: character.name,
          );
      if (ref.read(selectedCharacterProvider) == character) {
        state = AsyncData(fresh);
      }
    } catch (error, stackTrace) {
      if (!silent && state is! AsyncData<Map<int, Briefing>>) {
        state = AsyncError(error, stackTrace);
      } else {
        debugPrint('[briefing_cache] refresh failed, keeping cache: $error');
      }
    } finally {
      _refreshing = false;
    }
  }
}

final todayBriefingsProvider =
    AsyncNotifierProvider<TodayBriefingsNotifier, Map<int, Briefing>>(
      TodayBriefingsNotifier.new,
    );

final briefingHistoryProvider = Provider<List<Briefing>>((ref) {
  ref.watch(todayBriefingsProvider);
  final character = ref.watch(selectedCharacterProvider);
  return ref
      .watch(briefingRepositoryProvider)
      .readCachedHistory(city: _defaultCity, characterId: character.name);
});
