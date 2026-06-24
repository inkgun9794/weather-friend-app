import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:weather_friend/features/briefing/data/open_meteo_client.dart'
    show httpClientProvider;
import 'package:weather_friend/features/live/data/cctv_camera.dart';

/// 빌드 시 주입: `--dart-define=ITS_API_KEY=발급키`.
///
/// 비어 있으면(키 미주입) 클라이언트는 빈 리스트를 돌려주고, 라이브 화면은
/// "설정 필요" 안내 상태를 띄운다(크래시 없음). its.go.kr 가입 후 무료 발급.
const itsApiKey = String.fromEnvironment('ITS_API_KEY');

/// ITS 국가교통정보센터 CCTV OpenAPI 클라이언트.
///
/// 엔드포인트는 HTTPS(`openapi.its.go.kr:9443`)지만, 응답의 `cctvurl`(실제 영상
/// 스트림)은 평문 HTTP라 네이티브 cleartext 예외가 필요하다(ios Info.plist /
/// android network_security_config).
class ItsCctvClient {
  ItsCctvClient(this._http);

  final http.Client _http;

  /// 중심 좌표 주변(±[halfSpanDeg]° bbox)의 실시간 CCTV를 조회한다.
  ///
  /// 고속도로(`ex`)와 국도·간선(`its`)을 모두 조회해 병합한다. ITS는 도심 도로가
  /// 아니라 고속도로·국도 위주라, 도심(예: 서울 중구)에선 가장 가까운 카메라가
  /// 10km 이상 떨어진 외곽 순환·간선일 수 있다. 그래서 반경을 넉넉히(±0.15° ≈
  /// 13~17km) 잡고, 호출부에서 중심 거리순 정렬 후 가까운 N개만 보여준다.
  /// 키가 없거나 실패하면 빈 리스트.
  Future<List<CctvCamera>> fetchNearby({
    required double centerLat,
    required double centerLon,
    double halfSpanDeg = 0.15,
  }) async {
    if (itsApiKey.isEmpty) return const [];

    final minX = centerLon - halfSpanDeg;
    final maxX = centerLon + halfSpanDeg;
    final minY = centerLat - halfSpanDeg;
    final maxY = centerLat + halfSpanDeg;

    final results = await Future.wait([
      _fetchType('its', minX, maxX, minY, maxY),
      _fetchType('ex', minX, maxX, minY, maxY),
    ]);

    // 같은 카메라가 양쪽 type에 걸리는 경우는 드물지만, url 경로 기준으로 중복 제거.
    final seen = <CctvCamera>{};
    final merged = <CctvCamera>[];
    for (final cam in [...results[0], ...results[1]]) {
      if (seen.add(cam)) merged.add(cam);
    }
    return merged;
  }

  Future<List<CctvCamera>> _fetchType(
    String type,
    double minX,
    double maxX,
    double minY,
    double maxY,
  ) async {
    try {
      final uri = Uri.https('openapi.its.go.kr:9443', '/cctvInfo', {
        'apiKey': itsApiKey,
        'type': type, // ex=고속도로, its=국도·간선
        'cctvType': '1', // 1 = 실시간 스트리밍(HLS)
        'minX': minX.toStringAsFixed(6),
        'maxX': maxX.toStringAsFixed(6),
        'minY': minY.toStringAsFixed(6),
        'maxY': maxY.toStringAsFixed(6),
        'getType': 'json',
      });
      final resp = await _http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return const [];

      final body = json.decode(resp.body) as Map<String, dynamic>;
      // 표준 형태는 response.data[]. 일부 응답은 최상위 data[]를 쓰기도 함.
      final response = body['response'];
      final rawList = (response is Map ? response['data'] : null) ?? body['data'];
      if (rawList is! List) return const [];

      final cameras = <CctvCamera>[];
      for (final item in rawList) {
        if (item is! Map) continue;
        final name = (item['cctvname'] ?? 'CCTV').toString();
        // 터널·지하차도 카메라는 하늘이 안 보여 강수 확인에 무의미 → 제외.
        // (예: 강동구 옆 세종포천선 '고덕터널'에만 카메라가 ~20개 박혀 있어
        //  거르지 않으면 가까운 목록이 전부 터널로 도배된다.)
        if (_isIndoor(name)) continue;
        final url = (item['cctvurl'] ?? '').toString();
        final lon = _toDouble(item['coordx']);
        final lat = _toDouble(item['coordy']);
        if (url.isEmpty || lat == null || lon == null) continue;
        cameras.add(
          CctvCamera(
            name: name,
            lat: lat,
            lon: lon,
            streamUrl: url,
            roadType: type,
          ),
        );
      }
      return cameras;
    } catch (_) {
      return const [];
    }
  }

  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// 실내(터널·지하차도) 카메라 판별 — 하늘이 안 보여 강수 확인용으로 제외.
  static bool _isIndoor(String name) =>
      name.contains('터널') || name.contains('지하차도');
}

final itsCctvClientProvider = Provider<ItsCctvClient>((ref) {
  return ItsCctvClient(ref.watch(httpClientProvider));
});
