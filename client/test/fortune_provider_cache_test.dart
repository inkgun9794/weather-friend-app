import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saju/saju.dart' as saju;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:weather_friend/features/fortune/data/fortune_api.dart';
import 'package:weather_friend/features/fortune/data/fortune_report.dart';
import 'package:weather_friend/features/fortune/data/saju_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(tzdata.initializeTimeZones);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saving a fetched fortune does not start another fetch', () async {
    final prefs = await SharedPreferences.getInstance();
    final api = _CountingFortuneApi();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) async => prefs),
        fortuneApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(
      fortuneForProfileProvider(_profile).future,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(result.score, 74);
    expect(api.calls, 1);
    expect(await container.read(fortuneReportsProvider.future), hasLength(1));
  });

  test('a new provider container reuses a current-version report', () async {
    final prefs = await SharedPreferences.getInstance();
    final firstApi = _CountingFortuneApi();
    final firstContainer = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) async => prefs),
        fortuneApiProvider.overrideWithValue(firstApi),
      ],
    );

    await firstContainer.read(fortuneForProfileProvider(_profile).future);
    expect(firstApi.calls, 1);
    firstContainer.dispose();

    final secondApi = _CountingFortuneApi();
    final secondContainer = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) async => prefs),
        fortuneApiProvider.overrideWithValue(secondApi),
      ],
    );
    addTearDown(secondContainer.dispose);

    final cached = await secondContainer.read(
      fortuneForProfileProvider(_profile).future,
    );

    expect(cached.score, 74);
    expect(secondApi.calls, 0);
  });
}

const _profile = SajuProfile(
  name: '나',
  relation: SajuRelation.self,
  year: 1994,
  month: 8,
  day: 10,
  hour: 11,
  minute: 0,
  isLunar: false,
  gender: SajuGender.male,
);

class _CountingFortuneApi extends FortuneApi {
  int calls = 0;

  @override
  Future<FortuneResult> fetch({
    required SajuProfile profile,
    required saju.SajuResult result,
    required DateTime date,
  }) async {
    calls += 1;
    return const FortuneResult(text: '## 오늘의 운세\n차분하게 흐름을 살펴보세요.', score: 74);
  }
}
