import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kKey = 'selected_city_label';
const _kFallback = '서울';

/// 사용자가 온보딩 위치 단계에서 resolve한 도시 라벨.
///
/// 표시 전용 ("서울 광진구", "경기 수원시" 등). Firestore 브리핑 조회 키와는 별개 —
/// 워커가 현재 'seoul' 하나만 생성하므로 lookup은 여전히 'seoul' 슬러그로 한다.
/// 위치 거부/실패 시 [_kFallback] 으로 폴백.
class SelectedCityNotifier extends Notifier<String> {
  @override
  String build() {
    _load();
    return _kFallback;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kKey);
    if (saved != null && saved.isNotEmpty) state = saved;
  }

  Future<void> set(String label) async {
    final clean = label.trim();
    final value = clean.isEmpty ? _kFallback : clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, value);
    state = value;
  }
}

final selectedCityProvider =
    NotifierProvider<SelectedCityNotifier, String>(SelectedCityNotifier.new);
