/// 위경도 ↔ KMA 동네예보 격자 (Lambert Conformal Conic projection).
///
/// Worker의 adapters/kma_lambert.py 를 Dart로 포팅. 같은 상수, 같은 수식.
/// 검증: PDF '동네예보격자영역정보' 모서리 4점 일치.
library;

import 'dart:math' as math;

// 가이드/PDF 명시 상수
const _re = 6371.00877;
const _grid = 5.0;
const _slat1 = 30.0;
const _slat2 = 60.0;
const _olon = 126.0;
const _olat = 38.0;
const _xo = 210 / _grid;
const _yo = 675 / _grid;

// 사전 계산 (모듈 로드 시점 한 번)
const _degrad = math.pi / 180.0;
final double _slat1Rad = _slat1 * _degrad;
final double _slat2Rad = _slat2 * _degrad;
final double _olonRad = _olon * _degrad;
final double _olatRad = _olat * _degrad;
const double _reN = _re / _grid;

final double _sn = _computeSn();
final double _sf = _computeSf();
final double _ro = _computeRo();

double _computeSn() {
  final s = math.tan(math.pi * 0.25 + _slat2Rad * 0.5) /
      math.tan(math.pi * 0.25 + _slat1Rad * 0.5);
  return math.log(math.cos(_slat1Rad) / math.cos(_slat2Rad)) / math.log(s);
}

double _computeSf() {
  final s = math.tan(math.pi * 0.25 + _slat1Rad * 0.5);
  return math.pow(s, _sn).toDouble() * math.cos(_slat1Rad) / _sn;
}

double _computeRo() {
  final s = math.tan(math.pi * 0.25 + _olatRad * 0.5);
  return _reN * _sf / math.pow(s, _sn).toDouble();
}

/// 위경도 → 연속(float) 격자 좌표 (1-based).
/// GeoJSON polygon vertex 매핑용 — int 변환 안 함 (path 그리기엔 float이 필요).
({double nx, double ny}) latLonToGridFloat(double lat, double lon) {
  var ra = math.tan(math.pi * 0.25 + lat * _degrad * 0.5);
  ra = _reN * _sf / math.pow(ra, _sn).toDouble();
  var theta = lon * _degrad - _olonRad;
  if (theta > math.pi) theta -= 2.0 * math.pi;
  if (theta < -math.pi) theta += 2.0 * math.pi;
  theta *= _sn;
  final x = ra * math.sin(theta) + _xo;
  final y = _ro - ra * math.cos(theta) + _yo;
  // +1 = 1-based 격자 (정수 변환 안 함)
  return (nx: x + 1, ny: y + 1);
}
