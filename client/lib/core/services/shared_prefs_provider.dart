import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 시작 전에 `SharedPreferences.getInstance()`를 await 해두고,
/// main에서 override로 실제 인스턴스를 주입한다. 그래야 Notifier들이
/// `build()`에서 동기로 prefs를 읽고 race 없이 초기값을 결정할 수 있음.
///
/// override가 없으면 명시적으로 throw — 잊고 안 주입하면 실행 즉시 알게.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main() with '
    'the awaited SharedPreferences instance.',
  ),
);
