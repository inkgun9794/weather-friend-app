import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:weather_friend/features/radar/data/lambert.dart';

/// 사용자 현재 위치 → KMA 격자 좌표 (float, 1-based).
///
/// 권한 거부/실패 시 서울 시청 좌표로 fallback.
/// 비구름 지도의 사용자 위치 마커용.
final userGridProvider =
    FutureProvider<({double nx, double ny})>((ref) async {
  ref.keepAlive();

  const fallback = (lat: 37.5665, lon: 126.9780); // 서울 시청

  try {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return latLonToGridFloat(fallback.lat, fallback.lon);
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 5),
      ),
    );
    return latLonToGridFloat(pos.latitude, pos.longitude);
  } catch (_) {
    return latLonToGridFloat(fallback.lat, fallback.lon);
  }
});
