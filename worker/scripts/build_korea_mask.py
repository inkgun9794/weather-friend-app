"""한반도 영역 mask 생성 — 일회성.

API허브 RN1 격자에서 비관측영역(-99) 아닌 셀만 추출.
이게 곧 한반도 + 인근 해안 영역의 격자 위치 집합.

Firestore `kma_grid_mask/korea` 에 저장. 한 번만 돌리면 됨 (한반도는 변하지 않음).

실행:
    cd worker
    set -a && source ../.env && set +a
    uv run python scripts/build_korea_mask.py
"""

from __future__ import annotations

import asyncio
import logging
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# scripts/ 디렉토리에서 실행되므로 worker root를 import path에 추가
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from adapters.kma_apihub import NX, NY, fetch_vsrt_grid  # noqa: E402
from google.cloud import firestore  # noqa: E402
from usecases.refresh_kma_cache import grid_tmef, latest_grid_tmfc  # noqa: E402

log = logging.getLogger(__name__)
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s"
)


async def main() -> None:
    project_id = os.environ.get("GCP_PROJECT_ID", "weather-friend-92281")
    log.info("Korea mask 생성 (project=%s)", project_id)

    # 임의의 최근 시점으로 RN1 격자 fetch.
    # mask는 어떤 시점이든 동일 (한반도 영역은 시간 무관).
    tmfc = latest_grid_tmfc()
    tmef = grid_tmef(tmfc, 1)
    log.info("샘플 격자 fetch: tmfc=%s tmef=%s", tmfc, tmef)
    grid = await fetch_vsrt_grid(var="RN1", tmfc=tmfc, tmef=tmef)

    # -99 아닌 셀 = 한반도(+ 일부 해안) 관측영역.
    # at()이 -99면 None 반환하니 None 아니면 한반도.
    cells: list[dict] = []
    for ny in range(1, NY + 1):
        for nx in range(1, NX + 1):
            if grid.at(nx, ny) is not None:
                cells.append({"nx": nx, "ny": ny})

    log.info("한반도 영역 셀: %d개 (전체 %d 중)", len(cells), NX * NY)

    # Firestore 저장 — 한 번만, 영구.
    db = firestore.AsyncClient(project=project_id)
    try:
        await db.collection("kma_grid_mask").document("korea").set({
            "nx": NX,
            "ny": NY,
            "cells": cells,
            "updated_at": firestore.SERVER_TIMESTAMP,
            "note": "Korean peninsula grid mask (cells where KMA observes). "
                    "Generated once from RN1 grid (-99 = unobserved).",
        })
        log.info("Firestore kma_grid_mask/korea 저장 완료.")
    finally:
        db.close()


if __name__ == "__main__":
    asyncio.run(main())
