import 'package:weather_friend/shared/widgets/weather_icons.dart';

/// 기분을 날씨로 표현 — 작성 완료 전에 골라 기록에 도장처럼 남긴다.
///
/// 앱의 카와이 날씨 글리프를 그대로 재사용해 날씨 탭과 같은 시각 언어를 유지한다.
/// 저장은 [name]('sunny' 등) 문자열로 한다.
enum DiaryMood {
  sunny(label: '맑음', glyph: WeatherGlyph.sunny),
  partly(label: '구름', glyph: WeatherGlyph.partlyCloudy),
  cloudy(label: '흐림', glyph: WeatherGlyph.overcast),
  rainy(label: '비', glyph: WeatherGlyph.rain),
  snowy(label: '눈', glyph: WeatherGlyph.snow),
  stormy(label: '번개', glyph: WeatherGlyph.thunder);

  const DiaryMood({required this.label, required this.glyph});

  final String label;
  final WeatherGlyph glyph;

  /// 활성 세트의 날씨 PNG 에셋 경로.
  String get asset => weatherGlyphAsset(glyph);

  static DiaryMood? fromName(String? name) {
    if (name == null) return null;
    for (final mood in values) {
      if (mood.name == name) return mood;
    }
    return null;
  }
}
