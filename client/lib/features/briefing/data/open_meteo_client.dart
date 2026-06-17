import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/location/data/city_catalog.dart';

/// Open-Meteo는 무료·무제한·인증 X. worker가 사용하는 것과 동일한 endpoint.
/// 클라이언트가 직접 호출해서:
///   - 오늘 24h hourly  → 메인 화면 연결형 strip을 채움 (메시지 없는 hour에도
///     온도/아이콘이 보이도록)
///   - 오늘 daily 요약   → strip 헤더 한 줄
///   - 주간 weekDays     → 8일치(오늘+7일) 카드 (오전/오후 분리)
/// 모두 한 번의 API 호출로 받아오는 단일 bundle.

class HourlyWeather {
  const HourlyWeather({
    required this.hour,
    required this.temperatureC,
    required this.condition,
    required this.precipitationProb,
    this.feelsLikeC,
    this.humidity,
    this.weatherCode,
    this.uvIndex,
    this.pm10,
    this.pm25,
  });

  final int hour;
  final double temperatureC;
  final double? feelsLikeC;
  final String condition;
  final int precipitationProb;
  final int? humidity;

  /// 원본 WMO weather code (Open-Meteo). 강도/세부 condition 매핑용.
  /// null이면 KMA 출처 등으로 코드 없음.
  final int? weatherCode;

  /// 자외선 지수 (UV index). forecast hourly에서 옴. null이면 데이터 없음.
  final double? uvIndex;

  /// 미세먼지 PM10 (μg/m³). 별도 air-quality API에서 옴.
  /// 호출 실패 시 null — 날씨는 정상 동작.
  final int? pm10;

  /// 초미세먼지 PM2.5 (μg/m³). air-quality API에서 옴. 실패 시 null.
  final int? pm25;
}

class DailySummary {
  const DailySummary({
    required this.date,
    required this.maxC,
    required this.minC,
    required this.condition,
    required this.precipitationProbMax,
  });
  final String date;
  final double maxC;
  final double minC;
  final String condition;
  final int precipitationProbMax;

  /// "흐림 · 24° / 18°" 같은 한 줄 요약.
  String shortLine() {
    return '$condition · ${maxC.round()}° / ${minC.round()}°';
  }
}

String temperatureComparisonLine(DailySummary? today, DailySummary? yesterday) {
  if (today != null && _rainExpected(today)) {
    return '오늘은 비가 옵니다.';
  }
  if (today == null || yesterday == null) {
    return '오늘 날씨 정보를 불러오고 있습니다.';
  }

  final todayMean = (today.maxC + today.minC) / 2;
  final yesterdayMean = (yesterday.maxC + yesterday.minC) / 2;
  final difference = todayMean - yesterdayMean;
  if (difference.abs() < 1) {
    return '오늘은 어제와 비슷합니다.';
  }

  final degrees = difference.abs().round();
  return difference > 0
      ? '오늘은 어제보다 $degrees도 높습니다.'
      : '오늘은 어제보다 $degrees도 낮습니다.';
}

bool _rainExpected(DailySummary summary) {
  final condition = summary.condition;
  return condition.contains('비') ||
      condition.contains('소나기') ||
      condition.contains('천둥') ||
      summary.precipitationProbMax >= 60;
}

/// 하루를 3구간(오전/오후/저녁)으로 쪼갠 한 칸의 요약.
/// - condition: 한국어 텍스트. 윈도우 내 가장 심한 hour의 코드 기준.
///   (예: 오후 14~17시 중 한 시간이라도 비면 "비"로 표시 — 우산 챙길지 결정에 유의미.)
/// - tempC: 윈도우 내 시간들 평균 (정수 반올림).
class DayPartSummary {
  const DayPartSummary({required this.condition, required this.tempC});
  final String condition;
  final int tempC;
}

/// 주간 카드의 한 행. 하루를 3구간으로 나눠서 표시.
/// - morning   : 06~11시 (6시간, KST)
/// - afternoon : 12~17시 (6시간, KST)
/// - evening   : 18~23시 (6시간, KST)
/// 새벽(0~5시)은 카드에서 의도적으로 뺀다 — 사용자가 행동하는 시간대만.
class WeekDay {
  const WeekDay({
    required this.date,
    required this.weekday,
    required this.morning,
    required this.afternoon,
    required this.evening,
  });
  final String date; // ISO "2026-05-26"
  final int weekday; // DateTime.weekday: 1=Mon, 7=Sun
  final DayPartSummary morning;
  final DayPartSummary afternoon;
  final DayPartSummary evening;
}

/// 초단기 6시간 예측 — KMA만 제공. OpenMeteo 폴백 시 null.
/// "초단기" 섹션 카드 + (선택) 비구름 지도용 데이터의 토대.
class UltraShortForecast {
  const UltraShortForecast({required this.baseTime, required this.hours});

  /// 발표시각 (해당 데이터 정확도/신선도 표시용).
  final DateTime baseTime;

  /// 발표 +1~+6시간, 1시간 간격 6개 슬롯.
  final List<HourlyWeather> hours;
}

/// 단일 API 호출로 받는 묶음. 화면별로 필요한 부분만 derived provider로 꺼냄.
class WeatherBundle {
  const WeatherBundle({
    required this.today,
    required this.todaySummary,
    required this.weekDays,
    this.yesterdaySummary,
    this.sunriseToday,
    this.sunsetToday,
    this.ultraShort,
  });

  final Map<int, HourlyWeather> today;
  final DailySummary? todaySummary;
  final DailySummary? yesterdaySummary;
  final List<WeekDay> weekDays;

  /// 오늘 일출/일몰 시각 (KST). 아이콘 낮/밤 결정용. fetch 실패 시 null.
  final DateTime? sunriseToday;
  final DateTime? sunsetToday;

  /// 초단기 6시간 — KMA에서 fetch 성공 시만 채워짐. 없으면 UI 섹션 숨김.
  final UltraShortForecast? ultraShort;
}

// WMO weather code → 한국어. worker/adapters/weather_open_meteo.py와 정합.
const _weatherCodeKo = <int, String>{
  0: '맑음',
  1: '대체로 맑음',
  2: '구름 조금',
  3: '흐림',
  45: '안개',
  48: '짙은 안개',
  51: '약한 이슬비',
  53: '이슬비',
  55: '강한 이슬비',
  61: '약한 비',
  63: '비',
  65: '강한 비',
  71: '약한 눈',
  73: '눈',
  75: '강한 눈',
  77: '싸락눈',
  80: '소나기',
  81: '강한 소나기',
  82: '매우 강한 소나기',
  85: '약한 눈 소나기',
  86: '강한 눈 소나기',
  95: '천둥번개',
  96: '천둥번개 (우박)',
  99: '강한 천둥번개',
};

/// WMO 코드 심각도 — 같은 윈도우(오전/오후) 안에서 "대표 컨디션" 선정에 사용.
/// 단순 5단계: 맑음 < 흐림 < 안개 < 눈 < 비 < 천둥번개.
/// 비가 가장 위에 오는 게 직관에 맞진 않지만, "비 < 천둥번개"만 지키면
/// 우산 알림 의도와 충돌하지 않음. (강도 구분은 안 함 — 작은 아이콘에서 큰 정보 X.)
int _wmoSeverity(int code) {
  if (code >= 95) return 6; // 천둥번개
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
    return 5; // 비/이슬비/소나기
  }
  if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) return 4; // 눈
  if (code == 45 || code == 48) return 3; // 안개
  if (code == 3) return 2; // 흐림
  if (code == 2) return 1; // 구름 조금
  return 0; // 맑음 / 대체로 맑음
}

class OpenMeteoClient {
  OpenMeteoClient(this._http);

  final http.Client _http;

  /// 오늘부터 8일치(오늘 + 7일)를 한 번에 받는다 — KMA 단기(+3일)+중기(+7일)
  /// 조합과 같은 범위라, 폴백으로 떨어져도 주간 카드 일수가 줄지 않는다.
  /// 호출 1회로 hourly(전체 일수 × 24시간) + daily(전체 일수) 모두 채움 —
  /// Open-Meteo는 forecast_days 파라미터 하나로 다중 일 조회 지원.
  Future<WeatherBundle> fetchBundle({
    String city = WeatherCity.seoulCityId,
  }) async {
    final selected = await CityCatalog.findById(city);
    final lat = selected.lat;
    final lng = selected.lon;

    const daysCount = 8;

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toString(),
      'longitude': lng.toString(),
      'hourly':
          'temperature_2m,apparent_temperature,relative_humidity_2m,precipitation_probability,weather_code,uv_index',
      'daily':
          'temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max,sunrise,sunset',
      'timezone': 'Asia/Seoul',
      'past_days': '1',
      'forecast_days': daysCount.toString(),
    });

    final now = nowKst();
    final todayDate = _isoDate(now);

    // 예보(필수)와 대기질(부가)을 동시에 호출 — 대기질은 별도 host라 개별 try/catch로
    // 감싸서 실패해도 날씨 화면은 정상 동작. (실패 시 빈 맵 → PM 필드 null.)
    final results = await Future.wait([
      _http.get(uri).timeout(const Duration(seconds: 30)),
      _fetchAirQuality(lat: lat, lng: lng, todayDate: todayDate),
    ]);
    final resp = results[0] as http.Response;
    final airByHour = results[1] as Map<int, ({int? pm10, int? pm25})>;

    if (resp.statusCode != 200) {
      throw OpenMeteoException('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final data = json.decode(resp.body) as Map<String, dynamic>;
    final hourly = data['hourly'] as Map<String, dynamic>;
    final times = (hourly['time'] as List);
    final temps = (hourly['temperature_2m'] as List);
    final feelsLike = (hourly['apparent_temperature'] as List);
    final humidity = (hourly['relative_humidity_2m'] as List);
    final probs = (hourly['precipitation_probability'] as List);
    final codes = (hourly['weather_code'] as List);
    final uvs = (hourly['uv_index'] as List?) ?? const [];

    // 날짜를 기준으로 오늘 24시간만 추린다.
    final today = <int, HourlyWeather>{};
    for (var i = 0; i < times.length && i < temps.length; i++) {
      final timestamp = times[i].toString();
      if (!timestamp.startsWith(todayDate)) continue;
      final parsed = DateTime.tryParse(timestamp);
      if (parsed == null) continue;
      final air = airByHour[parsed.hour];
      today[parsed.hour] = _snapshot(
        parsed.hour,
        temps[i],
        feelsLike[i],
        humidity[i],
        probs[i],
        codes[i],
        i < uvs.length ? uvs[i] : null,
        air?.pm10,
        air?.pm25,
      );
    }

    // 일별 요약.
    final daily = data['daily'] as Map<String, dynamic>?;
    final dates = (daily?['time'] as List?) ?? const [];
    final maxs = (daily?['temperature_2m_max'] as List?) ?? const [];
    final mins = (daily?['temperature_2m_min'] as List?) ?? const [];
    final dCodes = (daily?['weather_code'] as List?) ?? const [];
    final dProbs =
        (daily?['precipitation_probability_max'] as List?) ?? const [];
    final sunrises = (daily?['sunrise'] as List?) ?? const [];
    final sunsets = (daily?['sunset'] as List?) ?? const [];

    final todayIndex = dates.indexWhere((date) => date.toString() == todayDate);
    final sunriseToday = todayIndex >= 0 && todayIndex < sunrises.length
        ? DateTime.tryParse(sunrises[todayIndex].toString())
        : null;
    final sunsetToday = todayIndex >= 0 && todayIndex < sunsets.length
        ? DateTime.tryParse(sunsets[todayIndex].toString())
        : null;
    final todaySummary = _dailySummaryAt(
      todayIndex,
      dates: dates,
      maxs: maxs,
      mins: mins,
      codes: dCodes,
      probabilities: dProbs,
    );
    final yesterdaySummary = _dailySummaryAt(
      todayIndex - 1,
      dates: dates,
      maxs: maxs,
      mins: mins,
      codes: dCodes,
      probabilities: dProbs,
    );

    // 주간 카드 — 각 일을 오전(6-11)/오후(12-17)/저녁(18-23)로 분리해서 대표값 뽑음.
    final weekDays = <WeekDay>[];
    for (var d = todayIndex < 0 ? 0 : todayIndex; d < dates.length; d++) {
      final dateStr = dates[d].toString();
      final dt = DateTime.parse(dateStr);
      weekDays.add(
        WeekDay(
          date: dateStr,
          weekday: dt.weekday,
          morning: _partSummary(temps, codes, d, 6, 11),
          afternoon: _partSummary(temps, codes, d, 12, 17),
          evening: _partSummary(temps, codes, d, 18, 23),
        ),
      );
    }

    return WeatherBundle(
      today: today,
      todaySummary: todaySummary,
      yesterdaySummary: yesterdaySummary,
      weekDays: weekDays,
      sunriseToday: sunriseToday,
      sunsetToday: sunsetToday,
    );
  }

  DailySummary? _dailySummaryAt(
    int index, {
    required List dates,
    required List maxs,
    required List mins,
    required List codes,
    required List probabilities,
  }) {
    if (index < 0 ||
        index >= dates.length ||
        index >= maxs.length ||
        index >= mins.length ||
        index >= codes.length) {
      return null;
    }
    return DailySummary(
      date: dates[index].toString(),
      maxC: (maxs[index] as num).toDouble(),
      minC: (mins[index] as num).toDouble(),
      condition: _weatherCodeKo[(codes[index] as num).toInt()] ?? '알 수 없음',
      precipitationProbMax: index < probabilities.length
          ? ((probabilities[index] as num?) ?? 0).toInt()
          : 0,
    );
  }

  /// dayIdx번째 날의 [startHour, endHour] 구간을 한 칸으로 요약.
  /// 기온은 평균, 컨디션은 가장 심한 hour의 코드 (소나기 한 시간이라도 있으면
  /// "비"로 잡혀서 사용자가 알아챌 수 있게).
  DayPartSummary _partSummary(
    List temps,
    List codes,
    int dayIdx,
    int startHour,
    int endHourInclusive,
  ) {
    final base = dayIdx * 24;
    double tempSum = 0;
    int count = 0;
    int worstCode = 0;
    int worstSev = -1;
    for (var h = startHour; h <= endHourInclusive; h++) {
      final i = base + h;
      if (i >= temps.length) break;
      tempSum += (temps[i] as num).toDouble();
      count++;
      final code = (codes[i] as num).toInt();
      final sev = _wmoSeverity(code);
      if (sev > worstSev) {
        worstSev = sev;
        worstCode = code;
      }
    }
    return DayPartSummary(
      condition: _weatherCodeKo[worstCode] ?? '알 수 없음',
      tempC: count > 0 ? (tempSum / count).round() : 0,
    );
  }

  HourlyWeather _snapshot(
    int hour,
    Object? temp,
    Object? feelsLike,
    Object? humidity,
    Object? prob,
    Object? code,
    Object? uv,
    int? pm10,
    int? pm25,
  ) {
    final codeInt = (code as num).toInt();
    return HourlyWeather(
      hour: hour,
      temperatureC: (temp as num).toDouble(),
      feelsLikeC: (feelsLike as num).toDouble(),
      humidity: (humidity as num).toInt(),
      condition: _weatherCodeKo[codeInt] ?? '알 수 없음',
      precipitationProb: ((prob as num?) ?? 0).toInt(),
      weatherCode: codeInt,
      uvIndex: (uv as num?)?.toDouble(),
      pm10: pm10,
      pm25: pm25,
    );
  }

  /// 대기질(미세먼지) 별도 API — `air-quality.open-meteo.com`. forecast와 다른 host.
  /// 절대 throw하지 않는다: 어떤 실패(네트워크/타임아웃/HTTP/파싱)든 빈 맵 반환 →
  /// 호출부에서 PM 필드만 null로 남고 날씨 화면은 정상.
  Future<Map<int, ({int? pm10, int? pm25})>> _fetchAirQuality({
    required double lat,
    required double lng,
    required String todayDate,
  }) async {
    try {
      final uri = Uri.https('air-quality.open-meteo.com', '/v1/air-quality', {
        'latitude': lat.toString(),
        'longitude': lng.toString(),
        'hourly': 'pm10,pm2_5',
        'timezone': 'Asia/Seoul',
        'forecast_days': '1',
      });
      final resp = await _http.get(uri).timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) return const {};

      final data = json.decode(resp.body) as Map<String, dynamic>;
      final hourly = data['hourly'] as Map<String, dynamic>?;
      if (hourly == null) return const {};
      final times = (hourly['time'] as List?) ?? const [];
      final pm10s = (hourly['pm10'] as List?) ?? const [];
      final pm25s = (hourly['pm2_5'] as List?) ?? const [];

      final byHour = <int, ({int? pm10, int? pm25})>{};
      for (var i = 0; i < times.length; i++) {
        final timestamp = times[i].toString();
        if (!timestamp.startsWith(todayDate)) continue;
        final parsed = DateTime.tryParse(timestamp);
        if (parsed == null) continue;
        final pm10 = i < pm10s.length ? (pm10s[i] as num?)?.round() : null;
        final pm25 = i < pm25s.length ? (pm25s[i] as num?)?.round() : null;
        byHour[parsed.hour] = (pm10: pm10, pm25: pm25);
      }
      return byHour;
    } catch (_) {
      // 대기질 실패는 무시 — 날씨가 우선.
      return const {};
    }
  }
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class OpenMeteoException implements Exception {
  OpenMeteoException(this.message);
  final String message;
  @override
  String toString() => 'OpenMeteoException: $message';
}

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final openMeteoClientProvider = Provider<OpenMeteoClient>((ref) {
  return OpenMeteoClient(ref.watch(httpClientProvider));
});
