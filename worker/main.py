"""Weather Friend hourly briefing generator — entry point.

매시간 :50에 GitHub Actions에서 실행. 다음 시각(:00)의 4 캐릭터 브리핑 생성.

Required env vars:
- GEMINI_API_KEY
- TYPECAST_API_KEY (알람 시간만 — 5/6/21/22시)
- GCP_PROJECT_ID (default: weather-friend-92281)

Usage:
    uv run python main.py                              # 다음 시간 자동 계산 (KST 기준)
    uv run python main.py --target-hour 5              # 특정 시간 명시
    uv run python main.py --cities seoul --target-hour 21
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import os
import sys
import zoneinfo
from datetime import datetime, timedelta
from pathlib import Path

from config import CITIES
from usecases.generate_briefing import generate_for_city_hour

KST = zoneinfo.ZoneInfo("Asia/Seoul")


def _setup_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%H:%M:%S",
    )
    # 외부 라이브러리의 노이즈 INFO 로그 억제 (HTTP 요청 / AFC enabled 등)
    for noisy in ("httpx", "google_genai", "google.auth", "urllib3"):
        logging.getLogger(noisy).setLevel(logging.WARNING)


def _setup_env_defaults(project_id: str) -> None:
    # 일부 GCP 라이브러리가 명시적 project 설정 외에 env var도 참조 — 경고 제거용
    os.environ.setdefault("GOOGLE_CLOUD_PROJECT", project_id)


def _next_target_hour() -> int:
    """현재 KST + 15분에 해당하는 시각.

    cron이 HH:50에 발사되면 HH:50 + 15min = (HH+1):05 → target = HH+1.
    HH:00에 사용자에게 도달해야 하므로 적절.
    """
    return (datetime.now(KST) + timedelta(minutes=15)).hour


async def _amain(cities: list[str], target_hour: int, docs_root: Path, project_id: str) -> int:
    total_ok = 0
    total_fail = 0
    for city in cities:
        logging.info("=" * 60)
        logging.info("Starting: %s @ %02d시", city, target_hour)
        result = await generate_for_city_hour(
            city=city,
            target_hour=target_hour,
            docs_root=docs_root,
            project_id=project_id,
        )
        total_ok += result["ok"]
        total_fail += result["fail"]
        logging.info(
            "Done: %s @ %02d시 — ok=%d fail=%d / %d",
            city,
            target_hour,
            result["ok"],
            result["fail"],
            result["total"],
        )

    logging.info("=" * 60)
    logging.info("Summary: ok=%d fail=%d", total_ok, total_fail)
    return 0 if total_fail == 0 else 1


def main() -> None:
    _setup_logging()

    parser = argparse.ArgumentParser(description="Generate hourly weather briefings")
    parser.add_argument(
        "--cities",
        default=",".join(CITIES),
        help="Comma-separated city names",
    )
    parser.add_argument(
        "--target-hour",
        type=int,
        default=None,
        help="Target hour 0-23 (KST). Default: next hour (now + 15min).",
    )
    parser.add_argument(
        "--docs-root",
        default="../docs",
        help="GitHub Pages source root (default: ../docs)",
    )
    parser.add_argument(
        "--project-id",
        default=os.environ.get("GCP_PROJECT_ID", "weather-friend-92281"),
        help="GCP project ID for Firestore",
    )
    args = parser.parse_args()

    cities = [c.strip() for c in args.cities.split(",") if c.strip()]
    docs_root = Path(args.docs_root).resolve()
    target_hour = args.target_hour if args.target_hour is not None else _next_target_hour()

    _setup_env_defaults(args.project_id)
    sys.exit(asyncio.run(_amain(cities, target_hour, docs_root, args.project_id)))


if __name__ == "__main__":
    main()
