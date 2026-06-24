import 'package:latlong2/latlong.dart';

/// ITS 교통 CCTV 한 대 — 실시간 HLS(.m3u8) 스트림 1개.
///
/// `streamUrl`은 토큰이 포함된 단명 URL이라 캐시하지 않고, 조회 직후 바로 재생한다.
class CctvCamera {
  const CctvCamera({
    required this.name,
    required this.lat,
    required this.lon,
    required this.streamUrl,
    required this.roadType,
  });

  /// cctvname — 예: "[서울][강변북로] 한강대교".
  final String name;

  /// coordy(위도) / coordx(경도).
  final double lat;
  final double lon;

  /// cctvurl — HLS 재생 URL.
  final String streamUrl;

  /// 'ex'(고속도로) | 'its'(국도·간선). 조회 type 그대로.
  final String roadType;

  LatLng get location => LatLng(lat, lon);

  /// 좌표 기반 식별 — streamUrl은 매 조회마다 토큰이 바뀌므로 식별자로 못 쓴다.
  /// 좌표는 카메라마다 고정이라 (a) ex/its 병합 시 중복 제거, (b) 새로고침 후
  /// "보던 카메라"를 새 토큰 객체로 다시 찾는 데 쓴다.
  String get _id => '${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';

  @override
  bool operator ==(Object other) => other is CctvCamera && other._id == _id;

  @override
  int get hashCode => _id.hashCode;
}
