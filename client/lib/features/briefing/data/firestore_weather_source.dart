import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart'
    show DailySummary, DayPartSummary, HourlyWeather, UltraShortForecast,
        WeatherBundle, WeekDay;
import 'package:weather_friend/features/briefing/data/weather_source.dart';

/// Firestore의 KMA 캐시를 읽어 [WeatherBundle]로 변환하는 [WeatherSource].
///
/// 컬렉션 레이아웃 (worker/usecases/refresh_kma_cache.py에서 작성):
/// - kma_short/{cityId}    — 단기예보 1~3일치 hourly
/// - kma_mid_land/{regId}  — 중기육상 4~10일 오전/오후
/// - kma_mid_temp/{regId}  — 중기기온 4~10일 일별 최저/최고
class FirestoreWeatherSource implements WeatherSource {
  FirestoreWeatherSource(this._db);

  final FirebaseFirestore _db;

  // MVP: 서울 고정 매핑. 향후 GPS 기반으로 cities_kma.json 룩업으로 확장.
  static const _cityMapping = <String, _CityMapping>{
    'seoul': _CityMapping(
      cityId: '1100000000',
      midLandRegId: '11B00000',
      midTempRegId: '11B10101',
    ),
  };

  @override
  String get id => 'kma-firestore';

  @override
  Future<WeatherBundle> fetchBundle({String city = 'seoul'}) async {
    final m = _cityMapping[city];
    if (m == null) {
      throw StateError('Unsupported city: $city');
    }

    final results = await Future.wait([
      _db.collection('kma_short').doc(m.cityId).get(),
      _db.collection('kma_mid_land').doc(m.midLandRegId).get(),
      _db.collection('kma_mid_temp').doc(m.midTempRegId).get(),
      _db.collection('kma_ultra').doc(m.cityId).get(),
    ]);
    final short = results[0];
    final midLand = results[1];
    final midTemp = results[2];
    final ultra = results[3];

    // short/mid는 필수, ultra는 선택 (없으면 UI 섹션 숨김).
    if (!short.exists || !midLand.exists || !midTemp.exists) {
      throw StateError(
        'KMA cache missing for $city — '
        'short=${short.exists} land=${midLand.exists} temp=${midTemp.exists}',
      );
    }

    return _KmaMapper.toBundle(
      shortData: short.data()!,
      midLandData: midLand.data()!,
      midTempData: midTemp.data()!,
      ultraData: ultra.exists ? ultra.data() : null,
    );
  }
}

class _CityMapping {
  const _CityMapping({
    required this.cityId,
    required this.midLandRegId,
    required this.midTempRegId,
  });
  final String cityId;
  final String midLandRegId;
  final String midTempRegId;
}

// ─────────────────────────────────────────────────────────────────────
// KMA 응답 → WeatherBundle 매핑
// ─────────────────────────────────────────────────────────────────────

class _KmaMapper {
  static WeatherBundle toBundle({
    required Map<String, dynamic> shortData,
    required Map<String, dynamic> midLandData,
    required Map<String, dynamic> midTempData,
    Map<String, dynamic>? ultraData,
  }) {
    final hours = (shortData['hours'] as List).cast<Map<String, dynamic>>();
    return WeatherBundle(
      today: _todayHourly(hours, ultraData),
      todaySummary: _todaySummary(hours),
      weekDays: _weekDays(hours, midLandData, midTempData),
      ultraShort: ultraData != null ? _ultraShort(ultraData) : null,
    );
  }

  /// kma_ultra → UltraShortForecast 변환.
  /// 초단기예보 구조: hours = [{fcst_date, fcst_time, t1h, rn1, pty, sky, ...}].
  static UltraShortForecast? _ultraShort(Map<String, dynamic> data) {
    final hours = (data['hours'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (hours.isEmpty) return null;

    final out = <HourlyWeather>[];
    for (final h in hours) {
      final tmp = (h['t1h'] as num?)?.toDouble();
      if (tmp == null) continue;
      final hour = _parseHour(h['fcst_time'] as String);
      out.add(HourlyWeather(
        hour: hour,
        temperatureC: tmp,
        condition: _kmaCondition(h['sky'] as int?, h['pty'] as int?),
        // 초단기는 강수확률(POP) 대신 강수형태(PTY)·강수량(RN1).
        // 카드 표시 단순화 — PTY > 0이면 100, 아니면 0.
        precipitationProb: ((h['pty'] as num?)?.toInt() ?? 0) > 0 ? 100 : 0,
      ));
    }

    if (out.isEmpty) return null;

    final baseDateStr = data['base_date'] as String?;
    final baseTimeStr = data['base_time'] as String?;
    final baseTime = (baseDateStr != null && baseTimeStr != null)
        ? _parseBaseTime(baseDateStr, baseTimeStr)
        : DateTime.now();

    return UltraShortForecast(baseTime: baseTime, hours: out);
  }

  static DateTime _parseBaseTime(String yyyymmdd, String hhmm) {
    return DateTime(
      int.parse(yyyymmdd.substring(0, 4)),
      int.parse(yyyymmdd.substring(4, 6)),
      int.parse(yyyymmdd.substring(6, 8)),
      int.parse(hhmm.substring(0, 2)),
      int.parse(hhmm.substring(2, 4)),
    );
  }

  /// 오늘 시간별 → `Map<hour, HourlyWeather>`.
  ///
  /// 단기예보를 기본으로 채우고, 같은 시각에 초단기예보 데이터가 있으면 덮어쓴다.
  /// 초단기는 30분마다 발표라 단기(3시간 주기)보다 훨씬 신선 → 우선.
  /// 강수확률(POP)은 초단기엔 없으므로 단기 값을 보존.
  static Map<int, HourlyWeather> _todayHourly(
    List<Map<String, dynamic>> shortHours,
    Map<String, dynamic>? ultraData,
  ) {
    final todayStr = _todayYYYYMMDD();
    final result = <int, HourlyWeather>{};

    // 1) 단기예보로 기본 채움.
    for (final h in shortHours) {
      if (h['fcst_date'] != todayStr) continue;
      final hour = _parseHour(h['fcst_time'] as String);
      final tmp = (h['tmp'] as num?)?.toDouble();
      if (tmp == null) continue;
      result[hour] = HourlyWeather(
        hour: hour,
        temperatureC: tmp,
        condition: _kmaCondition(h['sky'] as int?, h['pty'] as int?),
        precipitationProb: (h['pop'] as num?)?.toInt() ?? 0,
      );
    }

    // 2) 초단기예보가 커버하는 시각은 덮어쓰기 (더 신선한 기온/하늘/강수형태).
    final ultraHours =
        (ultraData?['hours'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    for (final h in ultraHours) {
      if (h['fcst_date'] != todayStr) continue;
      final tmp = (h['t1h'] as num?)?.toDouble();
      if (tmp == null) continue;
      final hour = _parseHour(h['fcst_time'] as String);
      final existing = result[hour];
      result[hour] = HourlyWeather(
        hour: hour,
        temperatureC: tmp,
        condition: _kmaCondition(h['sky'] as int?, h['pty'] as int?),
        // 초단기엔 POP 없음 — 단기 값 유지.
        precipitationProb: existing?.precipitationProb ?? 0,
      );
    }
    return result;
  }

  /// 오늘 일 요약: TMX/TMN + 통합 condition + 최대 강수확률.
  static DailySummary? _todaySummary(List<Map<String, dynamic>> hours) {
    final todayStr = _todayYYYYMMDD();
    double? tmx;
    double? tmn;
    int maxPop = 0;
    int worstSev = -1;
    String? worstCond;

    for (final h in hours) {
      if (h['fcst_date'] != todayStr) continue;
      final hourTmx = (h['tmx'] as num?)?.toDouble();
      final hourTmn = (h['tmn'] as num?)?.toDouble();
      if (hourTmx != null) tmx = hourTmx;
      if (hourTmn != null) tmn = hourTmn;
      final pop = (h['pop'] as num?)?.toInt() ?? 0;
      if (pop > maxPop) maxPop = pop;
      final cond = _kmaCondition(h['sky'] as int?, h['pty'] as int?);
      final sev = _condSeverity(cond);
      if (sev > worstSev) {
        worstSev = sev;
        worstCond = cond;
      }
    }

    if (tmx == null || tmn == null || worstCond == null) return null;
    return DailySummary(
      date: _toIsoDate(todayStr),
      maxC: tmx,
      minC: tmn,
      condition: worstCond,
      precipitationProbMax: maxPop,
    );
  }

  /// 7일 (오늘 + 1~3일 = 단기, +4~7일 = 중기).
  static List<WeekDay> _weekDays(
    List<Map<String, dynamic>> shortHours,
    Map<String, dynamic> midLand,
    Map<String, dynamic> midTemp,
  ) {
    final today = DateTime.now();
    final out = <WeekDay>[];

    // Day 0~3: 단기예보
    for (int offset = 0; offset < 4; offset++) {
      final d = today.add(Duration(days: offset));
      final dateStr = _yyyymmdd(d);
      final dayHours = shortHours
          .where((h) => h['fcst_date'] == dateStr)
          .toList();
      if (dayHours.isEmpty) continue;

      out.add(WeekDay(
        date: _toIsoDateFromDateTime(d),
        weekday: d.weekday,
        morning: _partFromHours(dayHours, 6, 12),
        afternoon: _partFromHours(dayHours, 12, 18),
        evening: _partFromHours(dayHours, 18, 24),
      ));
    }

    // Day 4~7: 중기예보 (오전/오후만 + 최저/최고)
    final landDays = (midLand['days'] as List).cast<Map<String, dynamic>>();
    final tempDays = (midTemp['days'] as List).cast<Map<String, dynamic>>();

    for (int offset = 4; offset <= 7; offset++) {
      final d = today.add(Duration(days: offset));
      final land = landDays.firstWhere(
        (x) => x['day_offset'] == offset,
        orElse: () => const {},
      );
      final temp = tempDays.firstWhere(
        (x) => x['day_offset'] == offset,
        orElse: () => const {},
      );
      if (land.isEmpty || temp.isEmpty) continue;

      final amCond = (land['am_weather'] as String?) ?? '맑음';
      final pmCond = (land['pm_weather'] as String?) ?? '맑음';
      final taMin = (temp['ta_min'] as num?)?.toInt();
      final taMax = (temp['ta_max'] as num?)?.toInt();
      if (taMin == null || taMax == null) continue;

      out.add(WeekDay(
        date: _toIsoDateFromDateTime(d),
        weekday: d.weekday,
        morning: DayPartSummary(condition: amCond, tempC: taMin),
        afternoon: DayPartSummary(condition: pmCond, tempC: taMax),
        // 중기엔 저녁 구분 없음 — 오후 컨디션 + 평균 기온으로 대체.
        evening: DayPartSummary(
          condition: pmCond,
          tempC: ((taMin + taMax) / 2).round(),
        ),
      ));
    }

    return out;
  }

  /// 시작 시(포함) ~ 끝 시(미포함) 범위 시간들을 한 part로 요약.
  static DayPartSummary _partFromHours(
    List<Map<String, dynamic>> dayHours,
    int startH,
    int endH,
  ) {
    final inRange = dayHours.where((h) {
      final hh = _parseHour(h['fcst_time'] as String);
      return hh >= startH && hh < endH;
    }).toList();
    if (inRange.isEmpty) {
      return const DayPartSummary(condition: '맑음', tempC: 0);
    }
    int worstSev = -1;
    String? worstCond;
    double tempSum = 0;
    int tempCount = 0;
    for (final h in inRange) {
      final cond = _kmaCondition(h['sky'] as int?, h['pty'] as int?);
      final sev = _condSeverity(cond);
      if (sev > worstSev) {
        worstSev = sev;
        worstCond = cond;
      }
      final tmp = (h['tmp'] as num?)?.toDouble();
      if (tmp != null) {
        tempSum += tmp;
        tempCount += 1;
      }
    }
    return DayPartSummary(
      condition: worstCond ?? '맑음',
      tempC: tempCount > 0 ? (tempSum / tempCount).round() : 0,
    );
  }

  // ─── KMA 코드 → 한글 ───

  /// SKY (1맑음/3구름많음/4흐림) + PTY (0없음/1비/2비-눈/3눈/4소나기) → 한글.
  /// PTY가 0이 아니면 PTY 우선 (강수가 하늘상태보다 우선 표현).
  static String _kmaCondition(int? sky, int? pty) {
    if (pty != null && pty > 0) {
      return switch (pty) {
        1 => '비',
        2 => '비/눈',
        3 => '눈',
        4 => '소나기',
        _ => '비',
      };
    }
    return switch (sky) {
      1 => '맑음',
      3 => '구름많음',
      4 => '흐림',
      _ => '맑음',
    };
  }

  /// part summary용 — 같은 윈도우에서 "가장 심한" 컨디션 선정 기준.
  static int _condSeverity(String cond) {
    if (cond.contains('번개')) return 6;
    if (cond.contains('비') || cond.contains('소나기')) return 5;
    if (cond.contains('눈')) return 4;
    if (cond.contains('흐림')) return 2;
    if (cond.contains('구름')) return 1;
    return 0;
  }

  // ─── 날짜 helpers ───

  static String _todayYYYYMMDD() => _yyyymmdd(DateTime.now());

  static String _yyyymmdd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y$m$dd';
  }

  static String _toIsoDate(String yyyymmdd) {
    return '${yyyymmdd.substring(0, 4)}-${yyyymmdd.substring(4, 6)}-${yyyymmdd.substring(6, 8)}';
  }

  static String _toIsoDateFromDateTime(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  static int _parseHour(String hhmm) => int.parse(hhmm.substring(0, 2));
}

final firestoreWeatherSourceProvider = Provider<WeatherSource>((ref) {
  return FirestoreWeatherSource(FirebaseFirestore.instance);
});
