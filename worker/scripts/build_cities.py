"""기상청 별첨 엑셀에서 184개 시·군·구 추출 → JSON.

광역시 8개 (단일) + 도의 시·군·구 176개 = 184개.
- city_id: 행정구역코드 10자리 (광역시는 시·도 코드, 도는 시·군·구 코드)
- label: 한글 라벨 (예: "서울", "경기 수원시 장안구")
- lat, lon, nx, ny: 엑셀 좌표 그대로
- mid_land_reg_id: 중기육상 광역 regId (도별 매핑, 강원은 영서/영동 분리)
- mid_temp_reg_id: 중기기온 대표시 regId (도별 대표시, 강원 영동은 별도)

실행:
    cd worker
    uv run --with pandas --with openpyxl python scripts/build_cities.py <xlsx_path>

결과: worker/data/cities_kma.json
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pandas as pd

# 광역시 8개 — 단일 도시로 처리
GWANGYEOK_INFO: dict[str, tuple[str, str, str]] = {
    # 시·도명: (city_id_label, mid_land_reg_id, mid_temp_reg_id)
    "서울특별시":     ("서울", "11B00000", "11B10101"),
    "부산광역시":     ("부산", "11H20000", "11H20201"),
    "대구광역시":     ("대구", "11H10000", "11H10701"),
    "인천광역시":     ("인천", "11B00000", "11B20201"),
    "광주광역시":     ("광주", "11F20000", "11F20501"),
    "대전광역시":     ("대전", "11C20000", "11C20401"),
    "울산광역시":     ("울산", "11H20000", "11H20101"),
    "세종특별자치시": ("세종", "11C20000", "11C20404"),
}

# 도(道) 9개 — 시·군·구 단위로 분리
# 도명: (도_라벨, default_mid_land_reg_id, default_mid_temp_reg_id)
DO_INFO: dict[str, tuple[str, str, str]] = {
    "경기도":          ("경기", "11B00000", "11B20601"),
    "강원특별자치도":  ("강원", "11D10000", "11D10301"),  # 기본: 영서/춘천
    "충청북도":        ("충북", "11C10000", "11C10301"),
    "충청남도":        ("충남", "11C20000", "11C20101"),
    "전라남도":        ("전남", "11F20000", "21F20801"),
    "전북특별자치도":  ("전북", "11F10000", "11F10201"),
    "경상북도":        ("경북", "11H10000", "11H10501"),
    "경상남도":        ("경남", "11H20000", "11H20301"),
    "제주특별자치도":  ("제주", "11G00000", "11G00201"),
}

# 강원 영동 시·군 — mid_land/mid_temp 별도 매핑
GANGWON_YEONGDONG = {
    "강릉시", "동해시", "속초시", "삼척시", "고성군", "양양군",
}


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    xlsx_path = sys.argv[1]
    out_path = Path(__file__).resolve().parent.parent / "data" / "cities_kma.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)

    df = pd.read_excel(xlsx_path)
    df = df[df["구분"] == "kor"]

    cities: list[dict] = []

    # 1. 광역시 8개 (1단계만, 2단계 NaN)
    gw_df = df[df["1단계"].isin(GWANGYEOK_INFO.keys()) & df["2단계"].isna()]
    for _, row in gw_df.iterrows():
        label, mid_land, mid_temp = GWANGYEOK_INFO[row["1단계"]]
        cities.append({
            "city_id": str(row["행정구역코드"]),
            "label": label,
            "lat": float(row["위도(초/100)"]),
            "lon": float(row["경도(초/100)"]),
            "nx": int(row["격자 X"]),
            "ny": int(row["격자 Y"]),
            "mid_land_reg_id": mid_land,
            "mid_temp_reg_id": mid_temp,
        })

    # 2. 도(道)의 시·군·구 (2단계 not NaN, 3단계 NaN)
    do_df = df[df["1단계"].isin(DO_INFO.keys()) & df["2단계"].notna() & df["3단계"].isna()]
    for _, row in do_df.iterrows():
        do_name = row["1단계"]
        sg_name = row["2단계"]
        do_label, mid_land, mid_temp = DO_INFO[do_name]

        # 강원 영동 특례
        if do_name == "강원특별자치도":
            if any(sg_name.startswith(e) for e in GANGWON_YEONGDONG):
                mid_land = "11D20000"
                mid_temp = "11D20501"

        cities.append({
            "city_id": str(row["행정구역코드"]),
            "label": f"{do_label} {sg_name}",
            "lat": float(row["위도(초/100)"]),
            "lon": float(row["경도(초/100)"]),
            "nx": int(row["격자 X"]),
            "ny": int(row["격자 Y"]),
            "mid_land_reg_id": mid_land,
            "mid_temp_reg_id": mid_temp,
        })

    with out_path.open("w", encoding="utf-8") as f:
        json.dump(cities, f, ensure_ascii=False, indent=2)

    print(f"Saved {len(cities)} cities → {out_path}")
    print(f"  광역시: {len(gw_df)}")
    print(f"  도 시·군·구: {len(do_df)}")
    unique_mid_land = {c["mid_land_reg_id"] for c in cities}
    unique_mid_temp = {c["mid_temp_reg_id"] for c in cities}
    print(f"  unique mid_land regId: {len(unique_mid_land)} ({sorted(unique_mid_land)})")
    print(f"  unique mid_temp regId: {len(unique_mid_temp)} ({sorted(unique_mid_temp)})")


if __name__ == "__main__":
    main()
