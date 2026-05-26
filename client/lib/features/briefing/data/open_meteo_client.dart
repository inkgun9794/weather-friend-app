import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/data/weather_facade.dart'
    show weatherFacadeProvider;

/// Open-Meteo는 무료·무제한·인증 X. worker가 사용하는 것과 동일한 endpoint.
/// 클라이언트가 직접 호출해서:
///   - 오늘 24h hourly  → 메인 화면 연결형 strip을 채움 (메시지 없는 hour에도
///     온도/아이콘이 보이도록)
///   - 오늘 daily 요약   → strip 헤더 한 줄
///   - 주간 weekDays     → 다음 주 월요일까지의 카드 (오전/오후 분리)
/// 모두 한 번의 API 호출로 받아오는 단일 bundle.

class HourlyWeather {
  const HourlyWeather({
    required this.hour,
    required this.temperatureC,
    required this.condition,
    required this.precipitationProb,
  });

  final int hour;
  final double temperatureC;
  final String condition;
  final int precipitationProb;
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
  final String date;     // ISO "2026-05-26"
  final int weekday;     // DateTime.weekday: 1=Mon, 7=Sun
  final DayPartSummary morning;
  final DayPartSummary afternoon;
  final DayPartSummary evening;
}

/// 초단기 6시간 예측 — KMA만 제공. OpenMeteo 폴백 시 null.
/// "초단기" 섹션 카드 + (선택) 비구름 지도용 데이터의 토대.
class UltraShortForecast {
  const UltraShortForecast({
    required this.baseTime,
    required this.hours,
  });

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
    this.ultraShort,
  });

  final Map<int, HourlyWeather> today;
  final DailySummary? todaySummary;
  final List<WeekDay> weekDays;

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
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return 5; // 비/이슬비/소나기
  if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) return 4; // 눈
  if (code == 45 || code == 48) return 3; // 안개
  if (code == 3) return 2; // 흐림
  if (code == 2) return 1; // 구름 조금
  return 0; // 맑음 / 대체로 맑음
}

const _cityCoords = <String, (double, double)>{
  'seoul': (37.5665, 126.9780),
};

class OpenMeteoClient {
  OpenMeteoClient(this._http);

  final http.Client _http;

  /// 오늘 ~ 다음 주 월요일까지 한 번에 받는다.
  /// 호출 1회로 hourly(전체 일수 × 24시간) + daily(전체 일수) 모두 채움 —
  /// Open-Meteo는 forecast_days 파라미터 하나로 다중 일 조회 지원.
  Future<WeatherBundle> fetchBundle({String city = 'seoul'}) async {
    final coords = _cityCoords[city];
    if (coords == null) {
      throw ArgumentError('Unsupported city: $city');
    }
    final (lat, lng) = coords;

    final daysCount = _daysUntilNextMonday(nowKst());

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toString(),
      'longitude': lng.toString(),
      'hourly': 'temperature_2m,precipitation_probability,weather_code',
      'daily': 'temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max',
      'timezone': 'Asia/Seoul',
      'forecast_days': daysCount.toString(),
    });

    final resp = await _http.get(uri).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw OpenMeteoException('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final data = json.decode(resp.body) as Map<String, dynamic>;
    final hourly = data['hourly'] as Map<String, dynamic>;
    final temps = (hourly['temperature_2m'] as List);
    final probs = (hourly['precipitation_probability'] as List);
    final codes = (hourly['weather_code'] as List);

    // 오늘 24시간만 hourly map으로 (연결형 strip용).
    final today = <int, HourlyWeather>{};
    for (var h = 0; h < 24 && h < temps.length; h++) {
      today[h] = _snapshot(h, temps[h], probs[h], codes[h]);
    }

    // 일별 요약.
    final daily = data['daily'] as Map<String, dynamic>?;
    final dates = (daily?['time'] as List?) ?? const [];
    final maxs = (daily?['temperature_2m_max'] as List?) ?? const [];
    final mins = (daily?['temperature_2m_min'] as List?) ?? const [];
    final dCodes = (daily?['weather_code'] as List?) ?? const [];
    final dProbs = (daily?['precipitation_probability_max'] as List?) ?? const [];

    DailySummary? todaySummary;
    if (dates.isNotEmpty) {
      todaySummary = DailySummary(
        date: dates[0].toString(),
        maxC: (maxs[0] as num).toDouble(),
        minC: (mins[0] as num).toDouble(),
        condition: _weatherCodeKo[(dCodes[0] as num).toInt()] ?? '알 수 없음',
        precipitationProbMax: ((dProbs[0] as num?) ?? 0).toInt(),
      );
    }

    // 주간 카드 — 각 일을 오전(6-11)/오후(12-17)/저녁(18-23)로 분리해서 대표값 뽑음.
    final weekDays = <WeekDay>[];
    for (var d = 0; d < dates.length; d++) {
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
      weekDays: weekDays,
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

  HourlyWeather _snapshot(int hour, Object? temp, Object? prob, Object? code) {
    return HourlyWeather(
      hour: hour,
      temperatureC: (temp as num).toDouble(),
      condition: _weatherCodeKo[(code as num).toInt()] ?? '알 수 없음',
      precipitationProb: ((prob as num?) ?? 0).toInt(),
    );
  }
}

/// 오늘(포함)부터 다음 주 월요일(포함)까지 며칠인지.
/// - 월: 8일(오늘 ~ 다음 월요일)
/// - 화: 7일, 수: 6일, …, 일: 2일
int _daysUntilNextMonday(DateTime today) {
  final w = today.weekday; // 1=Mon … 7=Sun
  return w == DateTime.monday ? 8 : (9 - w);
}

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

// KMA Firestore 캐시 우선 → 실패 시 OpenMeteo 자동 폴백.
// 폴백 로직은 weather_facade.dart의 WeatherFacade가 담당.
final weatherBundleProvider = FutureProvider<WeatherBundle>((ref) async {
  final facade = ref.watch(weatherFacadeProvider);
  return facade.fetchBundle();
});

final todayHourlyWeatherProvider = FutureProvider<Map<int, HourlyWeather>>((ref) async {
  return (await ref.watch(weatherBundleProvider.future)).today;
});

final todayDailySummaryProvider = FutureProvider<DailySummary?>((ref) async {
  return (await ref.watch(weatherBundleProvider.future)).todaySummary;
});

final weekDaysProvider = FutureProvider<List<WeekDay>>((ref) async {
  return (await ref.watch(weatherBundleProvider.future)).weekDays;
});
