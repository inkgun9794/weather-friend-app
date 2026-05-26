"""KMA 캐시 갱신 entry point.

Usage:
    uv run python refresh_kma.py --mode ultra   # 초단기만 (10분 워크플로)
    uv run python refresh_kma.py --mode full    # 단기+초단기+중기 (30분 또는 1시간 워크플로)

Required env vars:
- KMA_OPENAPI_KEY  : data.go.kr 키 (URL-encoded 그대로)
- KMA_APIHUB_KEY   : apihub.kma.go.kr authKey
- GCP_PROJECT_ID   : Firestore 프로젝트
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import os

from config import CITIES
from usecases.refresh_kma_cache import refresh_all, refresh_ultra_only


def _setup_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%H:%M:%S",
    )
    for noisy in ("httpx", "google.auth", "google.cloud", "urllib3"):
        logging.getLogger(noisy).setLevel(logging.WARNING)


async def _amain() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["ultra", "full"], required=True)
    parser.add_argument(
        "--cities",
        default=",".join(CITIES),
        help="comma-separated city ids (default: from config.CITIES)",
    )
    args = parser.parse_args()

    _setup_logging()
    project_id = os.environ.get("GCP_PROJECT_ID", "weather-friend-92281")
    city_ids = [c.strip() for c in args.cities.split(",") if c.strip()]

    log = logging.getLogger(__name__)
    log.info("KMA cache refresh — mode=%s cities=%s project=%s",
             args.mode, city_ids, project_id)

    if args.mode == "full":
        await refresh_all(city_ids, project_id)
    else:
        await refresh_ultra_only(city_ids, project_id)


if __name__ == "__main__":
    asyncio.run(_amain())
