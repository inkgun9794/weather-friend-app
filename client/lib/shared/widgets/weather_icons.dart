// 날씨 아이콘 에셋 관리 — 시맨틱 글리프 + 세트(테마) 전환.
//
// 조건(KMA condition / WMO weatherCode) → [WeatherGlyph] 결정은 weatherGlyphFor,
// 글리프 → 실제 PNG 경로는 weatherGlyphAsset가 담당한다.
// 아이콘 세트 전환은 아래 [kActiveWeatherIconSet] 한 줄만 바꾸면 앱 전체에 적용된다.

/// 날씨 상태를 나타내는 시맨틱 아이콘 키.
///
/// 표시용 의미 단위라 데이터 소스(KMA condition 문자열 / WMO weatherCode)와
/// 분리돼 있다. 각 세트가 이 글리프를 자기 PNG로 매핑한다.
enum WeatherGlyph {
  sunny, // 맑음 (낮)
  night, // 맑음 (밤)
  sunrise, // 일출 ±30분
  sunset, // 일몰 ±30분
  overcast, // 흐림
  partlyCloudy, // 구름많음 (낮)
  partlyCloudyNight, // 구름많음 (밤)
  rain, // 비
  shower, // 소나기
  heavyRain, // 강한 비
  rainThunder, // 번개동반 비
  thunder, // 천둥번개 (비 없이)
  snow, // 눈
  heavySnow, // 강한 눈
  sleet, // 비/눈 (진눈깨비)
}

/// 사용할 아이콘 세트.
enum WeatherIconSet {
  /// 기존 Flaticon 카와이 세트 (assets/icons/weather/).
  legacy,

  /// 신규 카와이 세트 (assets/icons/weather_v2/).
  kawaiiV2,
}

/// ⭐ 활성 아이콘 세트 — 이 한 줄만 바꾸면 전체 앱 아이콘이 전환된다.
const WeatherIconSet kActiveWeatherIconSet = WeatherIconSet.kawaiiV2;

/// [WeatherGlyph] → 활성 세트의 PNG 에셋 경로.
String weatherGlyphAsset(WeatherGlyph glyph) => switch (kActiveWeatherIconSet) {
      WeatherIconSet.legacy => _legacyAsset(glyph),
      WeatherIconSet.kawaiiV2 => _v2Asset(glyph),
    };

const String _legacyDir = 'assets/icons/weather';
const String _v2Dir = 'assets/icons/weather_v2';

String _legacyAsset(WeatherGlyph g) => switch (g) {
      WeatherGlyph.sunny => '$_legacyDir/sun.png',
      WeatherGlyph.night => '$_legacyDir/moon.png',
      WeatherGlyph.sunrise => '$_legacyDir/sunrise.png',
      WeatherGlyph.sunset => '$_legacyDir/sunset.png',
      // 기존 세트는 흐림/구름많음/주야 구분이 없어 모두 cloud.png.
      WeatherGlyph.overcast => '$_legacyDir/cloud.png',
      WeatherGlyph.partlyCloudy => '$_legacyDir/cloud.png',
      WeatherGlyph.partlyCloudyNight => '$_legacyDir/cloud.png',
      WeatherGlyph.rain => '$_legacyDir/rain.png',
      WeatherGlyph.shower => '$_legacyDir/shower.png',
      WeatherGlyph.heavyRain => '$_legacyDir/heavy_rain.png',
      // 기존 세트는 번개동반 비 전용 아이콘이 없어 thunder와 공유.
      WeatherGlyph.rainThunder => '$_legacyDir/thunder.png',
      WeatherGlyph.thunder => '$_legacyDir/thunder.png',
      WeatherGlyph.snow => '$_legacyDir/snow.png',
      WeatherGlyph.heavySnow => '$_legacyDir/blizzard.png',
      WeatherGlyph.sleet => '$_legacyDir/sleet.png',
    };

String _v2Asset(WeatherGlyph g) => switch (g) {
      WeatherGlyph.sunny => '$_v2Dir/sunny.png',
      WeatherGlyph.night => '$_v2Dir/night.png',
      WeatherGlyph.sunrise => '$_v2Dir/sunrise.png',
      WeatherGlyph.sunset => '$_v2Dir/sunset.png',
      WeatherGlyph.overcast => '$_v2Dir/overcast.png',
      WeatherGlyph.partlyCloudy => '$_v2Dir/partly_cloudy.png',
      // 구름많음(밤) 전용 — 구름+달 (005-cloudy). 맑은밤(달만)과 시각적 구분.
      WeatherGlyph.partlyCloudyNight => '$_v2Dir/partly_cloudy_night.png',
      WeatherGlyph.rain => '$_v2Dir/rain.png',
      WeatherGlyph.shower => '$_v2Dir/shower.png',
      WeatherGlyph.heavyRain => '$_v2Dir/heavy_rain.png',
      WeatherGlyph.rainThunder => '$_v2Dir/rain_thunder.png',
      WeatherGlyph.thunder => '$_v2Dir/thunder.png',
      WeatherGlyph.snow => '$_v2Dir/snow.png',
      WeatherGlyph.heavySnow => '$_v2Dir/heavy_snow.png',
      WeatherGlyph.sleet => '$_v2Dir/sleet.png',
    };

/// 날씨 조건 → [WeatherGlyph] 결정.
///
/// [condition]은 KMA condition 문자열('비','구름많음',…) 또는 WMO 한글 매핑.
/// [weatherCode]가 있으면 강도/번개를 보강한다 (없으면 기본 카테고리).
/// 우선순위: 진눈깨비 → 눈 → 비 → 천둥 → 흐림 → 구름많음 → 맑음.
WeatherGlyph weatherGlyphFor({
  required String condition,
  required bool isDay,
  int? weatherCode,
  bool isSunrise = false,
  bool isSunset = false,
}) {
  final code = weatherCode;

  // 1. 진눈깨비 (비+눈) — '비'/'눈' 단독 분기보다 먼저.
  if (condition.contains('비/눈') || condition.contains('진눈깨비')) {
    return WeatherGlyph.sleet;
  }

  // 2. 눈
  if (condition.contains('눈')) {
    if (code == 75 || code == 86) return WeatherGlyph.heavySnow;
    return WeatherGlyph.snow;
  }

  // 3. 비 / 소나기 (+ 번개·강도 보강)
  if (condition.contains('비') || condition.contains('소나기')) {
    if (code != null && code >= 95) return WeatherGlyph.rainThunder;
    if (code == 65 || code == 82) return WeatherGlyph.heavyRain;
    if (condition.contains('소나기') || code == 81) return WeatherGlyph.shower;
    return WeatherGlyph.rain;
  }

  // 4. 천둥번개 (비 없이) — KMA 문자열 또는 WMO 코드 95+.
  if (condition.contains('천둥') || (code != null && code >= 95)) {
    return WeatherGlyph.thunder;
  }

  // 5. 흐림
  if (condition.contains('흐')) return WeatherGlyph.overcast;

  // 6. 구름많음 / 구름 (낮·밤)
  if (condition.contains('구름')) {
    return isDay ? WeatherGlyph.partlyCloudy : WeatherGlyph.partlyCloudyNight;
  }

  // 7. 맑음 — 일출/일몰 윈도우 우선, 그 외 낮/밤.
  if (isSunrise) return WeatherGlyph.sunrise;
  if (isSunset) return WeatherGlyph.sunset;
  return isDay ? WeatherGlyph.sunny : WeatherGlyph.night;
}
