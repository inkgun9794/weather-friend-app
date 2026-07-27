import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/core/services/weather_widget_service.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/domain/outfit_guide.dart';
import 'package:weather_friend/features/briefing/data/weather_providers.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/location/data/selected_city_provider.dart';

/// Pushes the current weather to the home-screen widgets whenever the weather
/// bundle, the selected city, or the KST hour changes. Watch this provider once
/// from the app root to keep it alive; it wires the listeners and does an
/// initial sync.
final weatherWidgetSyncProvider = Provider<void>((ref) {
  // home_widget only exists on Android/iOS.
  if (kIsWeb ||
      !(defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    return;
  }

  const service = WeatherWidgetService();

  Future<void> pushCurrent() async {
    final bundle = ref.read(weatherBundleProvider).value;
    if (bundle == null) return;
    final hour = ref.read(kstHourProvider).value ?? currentHourKst();
    final hourly = bundle.today[hour];
    if (hourly == null) return;

    final city = ref.read(selectedCityProvider);
    final (sunrise, sunset) =
        ref.read(todaySunriseSunsetProvider).value ?? (null, null);

    final feelsLike = (hourly.feelsLikeC ?? hourly.temperatureC).round();
    await service.sync(
      WeatherWidgetSnapshot(
        cityLabel: city.label,
        condition: widgetConditionFromKo(hourly.condition),
        isDay: widgetIsDaytime(hour, sunrise, sunset),
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
  }

  // Re-sync on any relevant change. Errors are non-fatal (widget just keeps its
  // last frame), so swallow them rather than crash the app.
  void schedule() {
    pushCurrent().catchError((Object e) {
      debugPrint('WeatherWidget sync failed: $e');
    });
  }

  ref.listen(weatherBundleProvider, (_, _) => schedule());
  ref.listen(kstHourProvider, (_, _) => schedule());
  ref.listen(selectedCityProvider, (_, _) => schedule());
  ref.listen(todaySunriseSunsetProvider, (_, _) => schedule());

  schedule();
});
