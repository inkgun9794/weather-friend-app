import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';
import 'package:weather_friend/features/live/data/cctv_camera.dart';
import 'package:weather_friend/features/live/data/its_cctv_client.dart';
import 'package:weather_friend/features/live/data/seoul_districts.dart';
import 'package:weather_friend/features/location/data/city_catalog.dart';
import 'package:weather_friend/features/location/data/selected_city_provider.dart';

/// 서울에서 구를 안 골랐을 때 기본 중심 — 도심 중앙.
const kDefaultSeoulGu = '중구';

/// 화면당 보여줄 카메라 수 상한.
const _maxCameras = 12;

const _kSelectedGuKey = 'live_selected_gu';

/// 서울에서 사용자가 고른 자치구 이름. null이면 도시 중심 좌표를 쓴다.
/// SharedPreferences에 영속 — 탭을 다시 와도 유지(`selected_city_provider` 패턴).
class LiveSelectedGuNotifier extends Notifier<String?> {
  @override
  String? build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getString(_kSelectedGuKey);
    return (saved == null || saved.isEmpty) ? null : saved;
  }

  Future<void> set(String? gu) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (gu == null || gu.isEmpty) {
      await prefs.remove(_kSelectedGuKey);
      state = null;
    } else {
      await prefs.setString(_kSelectedGuKey, gu);
      state = gu;
    }
  }
}

final liveSelectedGuProvider =
    NotifierProvider<LiveSelectedGuNotifier, String?>(
      LiveSelectedGuNotifier.new,
    );

/// 기기 현재 위치 — "가장 가까운 카메라가 1번"의 기준점.
///
/// 권한이 이미 허용된 경우에만 쓰고 직접 프롬프트는 띄우지 않는다(앱 정책: 온보딩/
/// 설정 밖에선 위치 권한을 묻지 않음 — `LocationCoordinator`와 동일). 권한 없음/실패
/// 시 null → 호출부가 선택 도시 중심으로 폴백한다.
final currentLatLngProvider = FutureProvider<LatLng?>((ref) async {
  try {
    final perm = await Geolocator.checkPermission();
    if (perm != LocationPermission.always &&
        perm != LocationPermission.whileInUse) {
      return null;
    }
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return LatLng(last.latitude, last.longitude);
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 6),
      ),
    );
    return LatLng(pos.latitude, pos.longitude);
  } catch (_) {
    return null;
  }
});

/// 카메라 리스트 + 그 기준이 된 중심 좌표(거리 표시·정렬용).
typedef CctvFeed = ({LatLng center, List<CctvCamera> cameras});

/// 선택 지역(서울이면 선택 구, 그 외엔 도시 중심) 주변 실시간 CCTV.
///
/// autoDispose — 탭/앱을 떠나면 해제. 당겨서 새로고침은 `ref.invalidate`로
/// 토큰이 신선한 스트림 URL을 다시 받는다.
final cctvFeedProvider = FutureProvider.autoDispose<CctvFeed>((ref) async {
  final city = ref.watch(selectedCityProvider);
  final isSeoul = city.cityId == WeatherCity.seoulCityId;
  final selectedGu = ref.watch(liveSelectedGuProvider);

  var centerLat = city.lat;
  var centerLon = city.lon;

  if (isSeoul && selectedGu != null) {
    // 사용자가 구를 직접 골랐으면 그 구 중심(수동 우선).
    final districts = await ref.watch(seoulDistrictsProvider.future);
    final gu = _findDistrict(districts, selectedGu);
    if (gu != null) {
      centerLat = gu.lat;
      centerLon = gu.lon;
    }
  } else {
    // 기본: 현재 GPS 위치 — 가장 가까운 카메라가 1번이 되도록.
    final here = await ref.watch(currentLatLngProvider.future);
    if (here != null) {
      centerLat = here.latitude;
      centerLon = here.longitude;
    } else if (isSeoul) {
      // GPS 불가 + 서울이면 기본 구(중구) 중심으로.
      final districts = await ref.watch(seoulDistrictsProvider.future);
      final gu = _findDistrict(districts, kDefaultSeoulGu);
      if (gu != null) {
        centerLat = gu.lat;
        centerLon = gu.lon;
      }
    }
    // 비서울 + GPS 불가 → 선택 도시 중심(위 기본값).
  }

  final client = ref.watch(itsCctvClientProvider);
  final cameras = await client.fetchNearby(
    centerLat: centerLat,
    centerLon: centerLon,
  );

  // 중심에서 가까운 순으로 정렬해 상위 N개만.
  const distance = Distance();
  final center = LatLng(centerLat, centerLon);
  cameras.sort(
    (a, b) => distance(center, a.location).compareTo(
      distance(center, b.location),
    ),
  );

  return (
    center: center,
    cameras: cameras.take(_maxCameras).toList(growable: false),
  );
});

/// 선택 구 → 기본 구(중구) → 첫 구 순으로 매칭.
SeoulDistrict? _findDistrict(List<SeoulDistrict> districts, String? name) {
  if (districts.isEmpty) return null;
  for (final wanted in [name, kDefaultSeoulGu]) {
    if (wanted == null) continue;
    for (final d in districts) {
      if (d.name == wanted) return d;
    }
  }
  return districts.first;
}
