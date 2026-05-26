"""도시별 KMA 매핑 — data/cities_kma.json 로드.

184개 (광역시 8 + 도 시·군·구 176). 데이터 생성: scripts/build_cities.py
도시 추가/수정은 JSON 직접 수정 또는 build_cities.py 재실행.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class CityKma:
    city_id: str          # 행정구역코드 10자리 (예: "1100000000")
    label: str            # 한글 라벨 (예: "서울", "경기 수원시 장안구")
    lat: float
    lon: float
    short_nx: int
    short_ny: int
    mid_land_reg_id: str  # 중기육상 광역 (10종)
    mid_temp_reg_id: str  # 중기기온 대표시 (18종)


def _load_cities() -> dict[str, CityKma]:
    path = Path(__file__).resolve().parent.parent / "data" / "cities_kma.json"
    with path.open(encoding="utf-8") as f:
        items = json.load(f)
    return {
        item["city_id"]: CityKma(
            city_id=item["city_id"],
            label=item["label"],
            lat=item["lat"],
            lon=item["lon"],
            short_nx=item["nx"],
            short_ny=item["ny"],
            mid_land_reg_id=item["mid_land_reg_id"],
            mid_temp_reg_id=item["mid_temp_reg_id"],
        )
        for item in items
    }


CITIES_KMA: dict[str, CityKma] = _load_cities()
