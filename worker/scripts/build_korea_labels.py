"""기상청 별첨 엑셀에서 행정구역 라벨 추출 — RadarScreen 줌 단계 표시용.

level 0: 광역시·도 17개 (서울, 부산, 경기, 강원 등)
level 1: 시·군·구 (광역시 자치구 + 도의 시·군·구 ~246개)

결과: client/assets/maps/korea_labels.json (~30KB)

실행 (한 번만):
    cd worker
    uv run --with pandas --with openpyxl python scripts/build_korea_labels.py <xlsx_path>
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pandas as pd

SHORT_NAME = {
    "서울특별시": "서울",
    "부산광역시": "부산",
    "대구광역시": "대구",
    "인천광역시": "인천",
    "광주광역시": "광주",
    "대전광역시": "대전",
    "울산광역시": "울산",
    "세종특별자치시": "세종",
    "경기도": "경기",
    "강원특별자치도": "강원",
    "충청북도": "충북",
    "충청남도": "충남",
    "전라남도": "전남",
    "전북특별자치도": "전북",
    "경상북도": "경북",
    "경상남도": "경남",
    "제주특별자치도": "제주",
}


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    xlsx = sys.argv[1]
    out = Path(__file__).resolve().parent.parent.parent / "client" / "assets" / "maps" / "korea_labels.json"
    out.parent.mkdir(parents=True, exist_ok=True)

    df = pd.read_excel(xlsx)
    df = df[df["구분"] == "kor"]

    labels: list[dict] = []

    # level 0 — 광역시·도 (2단계 NaN인 행)
    for _, row in df[df["2단계"].isna()].iterrows():
        name1 = row["1단계"]
        if name1 not in SHORT_NAME:
            continue
        labels.append({
            "name": SHORT_NAME[name1],
            "level": 0,
            "nx": int(row["격자 X"]),
            "ny": int(row["격자 Y"]),
        })

    # level 1 — 시·군·구 (2단계 not NaN + 3단계 NaN)
    for _, row in df[df["2단계"].notna() & df["3단계"].isna()].iterrows():
        name1 = row["1단계"]
        name2 = row["2단계"]
        if name1 not in SHORT_NAME:
            continue
        labels.append({
            "name": name2,
            "level": 1,
            "nx": int(row["격자 X"]),
            "ny": int(row["격자 Y"]),
        })

    print(f"Total labels: {len(labels)}")
    print(f"  level 0 (광역시·도): {sum(1 for l in labels if l['level'] == 0)}")
    print(f"  level 1 (시·군·구):  {sum(1 for l in labels if l['level'] == 1)}")

    with out.open("w", encoding="utf-8") as f:
        json.dump(labels, f, ensure_ascii=False, separators=(",", ":"))

    print(f"Saved → {out} ({out.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
