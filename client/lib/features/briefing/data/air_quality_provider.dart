import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/features/location/data/selected_city_provider.dart';

/// 한 측정소의 실시간 미세먼지 스냅샷. 농도 ㎍/㎥, 등급은 환경부 한국어
/// ('좋음'/'보통'/'나쁨'/'매우나쁨'). 미수신 항목은 null.
class AirQuality {
  const AirQuality({this.pm10, this.pm25, this.pm10Grade, this.pm25Grade});

  final int? pm10;
  final int? pm25;
  final String? pm10Grade;
  final String? pm25Grade;
}

/// 선택 도시의 실시간 미세먼지 — worker가 AirKorea에서 받아 캐시한
/// Firestore `air_quality/{cityId}` 문서를 읽는다(앱엔 키가 필요 없음).
///
/// 날씨 출처와 독립. 문서 없음/권한·네트워크 실패 시 null → UI는 미세먼지만
/// 숨긴다(Open-Meteo `display.pm10` 폴백이 있어 크래시 없음).
final airQualityProvider = FutureProvider<AirQuality?>((ref) async {
  final city = ref.watch(selectedCityProvider);
  try {
    final snap = await FirebaseFirestore.instance
        .collection('air_quality')
        .doc(city.cityId)
        .get();
    final data = snap.data();
    if (data == null) return null;
    return AirQuality(
      pm10: (data['pm10'] as num?)?.round(),
      pm25: (data['pm25'] as num?)?.round(),
      pm10Grade: data['pm10_grade'] as String?,
      pm25Grade: data['pm25_grade'] as String?,
    );
  } catch (_) {
    return null;
  }
});
