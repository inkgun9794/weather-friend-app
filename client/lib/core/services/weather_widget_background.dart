import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';
import 'package:weather_friend/core/services/weather_widget_service.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/data/weather_cache.dart';
import 'package:weather_friend/features/briefing/data/weather_facade.dart';
import 'package:weather_friend/features/briefing/domain/outfit_guide.dart';
import 'package:weather_friend/features/location/data/city_catalog.dart';
import 'package:weather_friend/features/location/data/selected_city_provider.dart';
import 'package:weather_friend/firebase_options.dart';
import 'package:workmanager/workmanager.dart';

/// Unique task name for the periodic widget refresh.
const String kWeatherWidgetTaskName = 'weatherWidgetRefresh';

/// How often the OS is *asked* to run the refresh. Both iOS and Android treat
/// this as a floor and throttle in practice, so the widget won't be truly
/// real-time — matching how the built-in weather widgets behave. Set to 60 min
/// because the KMA source (via Firestore) only refreshes hourly, so reading more
/// often would just re-read identical data (extra Firestore reads, no new data).
const Duration kWeatherWidgetInterval = Duration(minutes: 60);

/// Entry point run by WorkManager in a background isolate. Must be a top-level
/// or static function annotated for AOT retention.
@pragma('vm:entry-point')
void weatherWidgetCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await refreshWeatherWidgetInBackground();
      return true;
    } catch (error, stackTrace) {
      debugPrint('[widget-bg] refresh failed: $error\n$stackTrace');
      // false → WorkManager retries later with backoff.
      return false;
    }
  });
}

/// Registers the periodic background refresh. Call once at app start.
Future<void> initWeatherWidgetBackgroundRefresh() async {
  if (kIsWeb) return;
  await Workmanager().initialize(weatherWidgetCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    kWeatherWidgetTaskName,
    kWeatherWidgetTaskName,
    frequency: kWeatherWidgetInterval,
    // update(keep 아님): 이미 등록된 기기에서도 주기 변경이 반영되도록.
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    constraints: Constraints(networkType: NetworkType.connected),
  );
}

/// Fetches the current weather for the selected city and pushes it to the
/// home-screen widget — WITHOUT the app being open. Reuses the app's KMA-first
/// facade and warms the app's on-disk cache so the next app open is instant.
Future<void> refreshWeatherWidgetInBackground() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await CityCatalog.load(); // rootBundle asset — needs the binding above
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  try {
    final city = container.read(selectedCityProvider);
    final date = todayKstIso();

    final bundle =
        await container.read(weatherFacadeProvider).fetchBundle(city: city.cityId);

    // Warm the app cache so opening the app shows this data immediately.
    await container
        .read(weatherCacheProvider)
        .write(cityId: city.cityId, date: date, bundle: bundle);

    final hour = currentHourKst();
    final hourly = bundle.today[hour];
    if (hourly == null) return;

    final feelsLike = (hourly.feelsLikeC ?? hourly.temperatureC).round();
    await const WeatherWidgetService().sync(
      WeatherWidgetSnapshot(
        cityLabel: city.label,
        condition: widgetConditionFromKo(hourly.condition),
        isDay: widgetIsDaytime(hour, bundle.sunriseToday, bundle.sunsetToday),
        temperatureC: hourly.temperatureC,
        precipitationProb: hourly.precipitationProb,
        updatedLabel: widgetUpdatedLabel(nowKst()),
        outfitKeys: outfitIconKeysFor(
          feelsLike: feelsLike,
          condition: hourly.condition,
          precipitationProb: hourly.precipitationProb,
        ),
      ),
    );
    debugPrint('[widget-bg] refreshed ${city.label} @$hour시');
  } finally {
    container.dispose();
  }
}
