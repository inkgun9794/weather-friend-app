"""한국 시·군·구 GeoJSON 단순화 — 모바일 앱 asset용.

southkorea-maps의 원본 17MB → ~200KB로 축소.
Douglas-Peucker simplification (tolerance ≈ 300m).

실행 (한 번만):
    cd worker
    uv run --with shapely python scripts/simplify_korea_geojson.py
"""

from __future__ import annotations

import json
from pathlib import Path

from shapely.geometry import mapping, shape


def main() -> None:
    assets = Path(__file__).resolve().parent.parent.parent / "client" / "assets" / "maps"
    src = assets / "korea_municipalities_full.json"
    dst = assets / "korea_municipalities.json"

    print(f"Loading: {src} ({src.stat().st_size:,} bytes)")
    with src.open(encoding="utf-8") as f:
        data = json.load(f)

    n_features = len(data["features"])
    print(f"Features (시·군·구): {n_features}")

    # tolerance — 위경도 단위. 0.003 ≈ 300m. 시·군·구 모양 유지하기에 충분.
    TOLERANCE = 0.003

    for feature in data["features"]:
        geom = shape(feature["geometry"])
        simplified = geom.simplify(TOLERANCE, preserve_topology=True)
        feature["geometry"] = mapping(simplified)

        # properties는 name_korean 정도만 유지 (한국어 이름)
        props = feature.get("properties", {})
        new_props = {}
        for key in ("name_eng", "name", "code"):
            if key in props:
                new_props[key] = props[key]
        feature["properties"] = new_props

    with dst.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))

    print(f"Saved: {dst} ({dst.stat().st_size:,} bytes, {dst.stat().st_size * 100 // src.stat().st_size}%)")

    # 원본 삭제 (asset에 안 들어가게)
    src.unlink()
    print(f"Removed: {src}")


if __name__ == "__main__":
    main()
