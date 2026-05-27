import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// 사용자 현재 위경도. 권한 거부/실패 시 서울 시청 fallback.
final userLatLngProvider =
    FutureProvider<({double lat, double lon})>((ref) async {
  ref.keepAlive();

  const fallback = (lat: 37.5665, lon: 126.9780); // 서울 시청

  try {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      debugPrint('[user_location] permission denied — fallback to Seoul');
      return fallback;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      ),
    );
    debugPrint(
      '[user_location] GPS (${pos.latitude.toStringAsFixed(6)}, '
      '${pos.longitude.toStringAsFixed(6)})',
    );
    return (lat: pos.latitude, lon: pos.longitude);
  } catch (e) {
    debugPrint('[user_location] failed ($e) — fallback to Seoul');
    return fallback;
  }
});
