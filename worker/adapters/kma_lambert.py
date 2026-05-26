"""KMA 동네예보 격자 ↔ 위경도 변환 (Lambert Conformal Conic projection).

단기예보 활용가이드 부록 C 코드를 Python으로 포팅. 격자는 1-based.
검증 데이터: PDF '동네예보격자영역정보' (2024-03-05)의 모서리 4점.

상수는 모듈 로드 시점에 1회 사전 계산.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

# 가이드/PDF 명시 상수
_RE = 6371.00877      # 지구반경 [km]
_GRID = 5.0           # 격자간격 [km]
_SLAT1 = 30.0         # 표준위도 1
_SLAT2 = 60.0         # 표준위도 2
_OLON = 126.0         # 기준점 경도
_OLAT = 38.0          # 기준점 위도
_XO = 210 / _GRID     # 기준점 격자 X (= 42, 내부 0-based)
_YO = 675 / _GRID     # 기준점 격자 Y (= 135, 내부 0-based)

# 사전 계산
_DEGRAD = math.pi / 180.0
_RADDEG = 180.0 / math.pi

_RE_N = _RE / _GRID
_SLAT1_RAD = _SLAT1 * _DEGRAD
_SLAT2_RAD = _SLAT2 * _DEGRAD
_OLON_RAD = _OLON * _DEGRAD
_OLAT_RAD = _OLAT * _DEGRAD

_SN = math.tan(math.pi * 0.25 + _SLAT2_RAD * 0.5) / math.tan(
    math.pi * 0.25 + _SLAT1_RAD * 0.5
)
_SN = math.log(math.cos(_SLAT1_RAD) / math.cos(_SLAT2_RAD)) / math.log(_SN)
_SF = math.tan(math.pi * 0.25 + _SLAT1_RAD * 0.5)
_SF = math.pow(_SF, _SN) * math.cos(_SLAT1_RAD) / _SN
_RO = math.tan(math.pi * 0.25 + _OLAT_RAD * 0.5)
_RO = _RE_N * _SF / math.pow(_RO, _SN)


@dataclass(frozen=True)
class GridXY:
    nx: int  # 1..149
    ny: int  # 1..253


@dataclass(frozen=True)
class LonLat:
    lon: float
    lat: float


def latlon_to_grid(lat: float, lon: float) -> GridXY:
    """위경도 → (nx, ny). 1-based 격자 번호."""
    ra = math.tan(math.pi * 0.25 + lat * _DEGRAD * 0.5)
    ra = _RE_N * _SF / math.pow(ra, _SN)
    theta = lon * _DEGRAD - _OLON_RAD
    if theta > math.pi:
        theta -= 2.0 * math.pi
    if theta < -math.pi:
        theta += 2.0 * math.pi
    theta *= _SN
    x = ra * math.sin(theta) + _XO
    y = _RO - ra * math.cos(theta) + _YO
    return GridXY(nx=int(x + 1.5), ny=int(y + 1.5))


def grid_to_latlon(nx: int, ny: int) -> LonLat:
    """(nx, ny) → 위경도. 1-based 격자 번호."""
    x = nx - 1
    y = ny - 1
    xn = x - _XO
    yn = _RO - y + _YO
    ra = math.sqrt(xn * xn + yn * yn)
    if _SN < 0.0:
        ra = -ra
    alat = math.pow((_RE_N * _SF / ra), (1.0 / _SN))
    alat = 2.0 * math.atan(alat) - math.pi * 0.5

    if abs(xn) <= 0.0:
        theta = 0.0
    elif abs(yn) <= 0.0:
        theta = math.pi * 0.5
        if xn < 0.0:
            theta = -theta
    else:
        theta = math.atan2(xn, yn)
    alon = theta / _SN + _OLON_RAD
    return LonLat(lon=alon * _RADDEG, lat=alat * _RADDEG)
