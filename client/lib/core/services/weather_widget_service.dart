import 'package:home_widget/home_widget.dart';

/// iOS App Group id — must match the App Group enabled on BOTH the Runner
/// target and the widget extension target in Xcode. Android ignores this.
const String kWidgetAppGroupId = 'group.com.weatherfriend.app';

/// Normalized condition keys the native widgets switch their illustration on.
/// Keep these names in sync with the Android drawables (`wx_clear` …) and the
/// iOS asset/switch cases.
enum WidgetCondition { clear, cloudy, rain, snow }

/// Maps the app's Korean condition text to a normalized key. Mirrors the
/// mapping used by the in-app weather background so the widget agrees with the
/// screen.
WidgetCondition widgetConditionFromKo(String? ko) {
  final s = ko ?? '';
  if (s.contains('비') || s.contains('소나기')) return WidgetCondition.rain;
  if (s.contains('눈')) return WidgetCondition.snow;
  if (s.contains('흐') || s.contains('구름')) return WidgetCondition.cloudy;
  return WidgetCondition.clear;
}

/// Whether [hour] falls in daytime, per the day's sunrise/sunset. Mirrors the
/// in-app test so the widget picks the same day/night illustration. Falls back
/// to 06–19 when sun times are unknown. Shared by the live sync and the
/// background refresh so both agree.
bool widgetIsDaytime(int hour, DateTime? sunrise, DateTime? sunset) {
  if (sunrise == null || sunset == null) {
    return hour >= 6 && hour < 19;
  }
  final mid = hour + 0.5;
  final sr = sunrise.hour + sunrise.minute / 60.0;
  final ss = sunset.hour + sunset.minute / 60.0;
  return mid >= sr && mid < ss;
}

/// "오전/오후 h:mm 기준" freshness label from a KST [DateTime].
String widgetUpdatedLabel(DateTime kst) {
  final isAm = kst.hour < 12;
  final h12 = kst.hour % 12 == 0 ? 12 : kst.hour % 12;
  final mm = kst.minute.toString().padLeft(2, '0');
  return '${isAm ? '오전' : '오후'} $h12:$mm 기준';
}

/// Everything a home-screen widget needs, pre-formatted in Dart so the native
/// side stays dumb (just picks an image by [condition] and prints strings).
class WeatherWidgetSnapshot {
  const WeatherWidgetSnapshot({
    required this.cityLabel,
    required this.condition,
    required this.isDay,
    required this.updatedLabel,
    this.temperatureC,
    this.precipitationProb,
    this.outfitKeys = const [],
  });

  final String cityLabel;
  final WidgetCondition condition;
  final bool isDay;
  final String updatedLabel;
  final double? temperatureC;
  final int? precipitationProb;

  /// Native image keys (`oc_<key>`) for the recommended outfit icons, in order.
  /// Umbrella, when needed, is already included as the last key.
  final List<String> outfitKeys;
}

/// Writes the current weather into the shared store the native widgets read
/// (App Group on iOS, SharedPreferences on Android) and asks the OS to redraw
/// them. Safe to call on any platform; `home_widget` no-ops off Android/iOS.
class WeatherWidgetService {
  const WeatherWidgetService();

  Future<void> sync(WeatherWidgetSnapshot s) async {
    await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    await Future.wait([
      HomeWidget.saveWidgetData<String>('city', s.cityLabel),
      HomeWidget.saveWidgetData<String>(
        'temp',
        s.temperatureC == null ? '--°' : '${s.temperatureC!.round()}°',
      ),
      HomeWidget.saveWidgetData<String>('condition', s.condition.name),
      HomeWidget.saveWidgetData<bool>('isDay', s.isDay),
      HomeWidget.saveWidgetData<String>(
        'precip',
        s.precipitationProb == null ? '' : '강수 ${s.precipitationProb}%',
      ),
      HomeWidget.saveWidgetData<String>('updated', s.updatedLabel),
      // 옷 아이콘 키를 콤마로 이어서 저장 (예: "coat,scarf,umbrella").
      HomeWidget.saveWidgetData<String>('outfit', s.outfitKeys.join(',')),
    ]);
    await HomeWidget.updateWidget(
      androidName: 'WeatherWidgetProvider',
      iOSName: 'WeatherWidget',
      qualifiedAndroidName: 'com.weatherfriend.app.WeatherWidgetProvider',
    );
  }

  /// Whether the OS/launcher can show an in-app "pin widget" dialog.
  /// Android 8.0+ on supporting launchers only; always false on iOS (Apple has
  /// no programmatic add — the app must show a manual guide instead).
  Future<bool> canRequestPin() async {
    return (await HomeWidget.isRequestPinWidgetSupported()) ?? false;
  }

  /// Pops the system "Add to Home screen" dialog for our widget (Android only).
  /// One tap by the user pins it. No-op/throws on unsupported platforms — call
  /// [canRequestPin] first.
  Future<void> requestPin() async {
    await HomeWidget.requestPinWidget(
      androidName: 'WeatherWidgetProvider',
      qualifiedAndroidName: 'com.weatherfriend.app.WeatherWidgetProvider',
    );
  }
}
