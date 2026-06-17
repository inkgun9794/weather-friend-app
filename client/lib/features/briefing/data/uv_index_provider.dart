import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart'
    show httpClientProvider;
import 'package:weather_friend/features/location/data/selected_city_provider.dart';

/// 선택 도시 좌표 기준 현재 자외선 지수 — Open-Meteo (날씨 소스와 독립).
///
/// UV는 미세먼지와 달리 측정소 실측이 아니라 모델 예보라 위경도 기반 Open-Meteo로
/// 충분하다. 날씨 출처(KMA/Open-Meteo)와 무관하게 항상 동작하도록 별도 provider로
/// 둔다. 실패/미수신 시 null → UI는 자외선만 숨길 뿐 크래시 없음.
final uvIndexProvider = FutureProvider<double?>((ref) async {
  final city = ref.watch(selectedCityProvider);
  final client = ref.watch(httpClientProvider);
  try {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': city.lat.toString(),
      'longitude': city.lon.toString(),
      'hourly': 'uv_index',
      'timezone': 'Asia/Seoul',
      'forecast_days': '1',
    });
    final resp = await client.get(uri).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) return null;

    final data = json.decode(resp.body) as Map<String, dynamic>;
    final hourly = data['hourly'] as Map<String, dynamic>?;
    final times = (hourly?['time'] as List?) ?? const [];
    final uvs = (hourly?['uv_index'] as List?) ?? const [];

    // 현재 KST 시각에 해당하는 슬롯을 찾아 그 값을 반환.
    final now = nowKst();
    for (var i = 0; i < times.length && i < uvs.length; i++) {
      final t = DateTime.tryParse(times[i].toString());
      if (t != null &&
          t.year == now.year &&
          t.month == now.month &&
          t.day == now.day &&
          t.hour == now.hour) {
        return (uvs[i] as num?)?.toDouble();
      }
    }
    return null;
  } catch (_) {
    return null;
  }
});
