"""도시별 KMA 매핑 테이블.

각 도시에 대해:
- 위경도 (사용자 표시 마커, Lambert 검증용)
- 단기예보 격자 (nx, ny) — adapters.kma_lambert.latlon_to_grid 결과
- 중기육상 regId (광역구역, '11B00000' 등)
- 중기기온 regId (시 단위, '11B10101' 등)

도시 추가는 여기 한 줄만. (nx, ny)는 lambert 변환으로 검증.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class CityKma:
    city_id: str          # 내부 식별자 (e.g. "seoul")
    label: str            # 표시 라벨 (한글)
    lat: float
    lon: float
    short_nx: int         # 단기/초단기예보 격자 X
    short_ny: int         # 단기/초단기예보 격자 Y
    mid_land_reg_id: str  # 중기육상 광역
    mid_temp_reg_id: str  # 중기기온 시단위


# MVP — 서울만. 도시 추가 시 여기에 한 줄 추가.
CITIES_KMA: dict[str, CityKma] = {
    "seoul": CityKma(
        city_id="seoul",
        label="서울",
        lat=37.5665,
        lon=126.9780,
        short_nx=60,
        short_ny=127,
        mid_land_reg_id="11B00000",  # 서울/인천/경기
        mid_temp_reg_id="11B10101",  # 서울
    ),
}
