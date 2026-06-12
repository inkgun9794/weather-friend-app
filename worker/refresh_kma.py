"""KMA 캐시 갱신 entry point.

Usage:
    uv run python refresh_kma.py --mode ultra   # 초단기만 (grid 워크플로, 30분)
    uv run python refresh_kma.py --mode base    # 단기+중기+전일 관측 (base 워크플로, 1시간)

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

from domain.locations import CITIES_KMA
from usecases.refresh_kma_cache import refresh_short_and_mid, refresh_ultra_only


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
    parser.add_argument("--mode", choices=["ultra", "base"], required=True)
    parser.add_argument(
        "--cities",
        default="",
        help="comma-separated city ids. 빈 값이면 CITIES_KMA 전체.",
    )
    parser.add_argument(
        "--docs-root",
        default="",
        help="레이더 PNG가 쓰일 GitHub Pages 루트. CI는 '../docs', 로컬 디버깅은 '_docs'.",
    )
    parser.add_argument(
        "--pages-base-url",
        default="https://inkgun9794.github.io/weather-friend-app",
        help="레이더 PNG가 서빙될 GitHub Pages 베이스 URL.",
    )
    args = parser.parse_args()

    _setup_logging()
    project_id = os.environ.get("GCP_PROJECT_ID", "weather-friend-92281")
    docs_root = args.docs_root or "_docs"
    city_ids = [c.strip() for c in args.cities.split(",") if c.strip()]
    if not city_ids:
        city_ids = list(CITIES_KMA.keys())

    log = logging.getLogger(__name__)
    log.info("KMA cache refresh — mode=%s cities=%s project=%s docs_root=%s",
             args.mode, city_ids, project_id, docs_root)

    if args.mode == "base":
        await refresh_short_and_mid(city_ids, project_id)
    else:
        await refresh_ultra_only(
            city_ids, project_id,
            docs_root=docs_root,
            pages_base_url=args.pages_base_url,
        )


if __name__ == "__main__":
    asyncio.run(_amain())
