"""Weather Friend hourly briefing generator — entry point.

매시간 :50에 GitHub Actions에서 실행. 다음 시각(:00)의 4 캐릭터 브리핑 생성.

Required env vars:
- GEMINI_API_KEY
- TYPECAST_API_KEY (6시 morning 음성 합성)
- TYPECAST_API_KEY_B (21시 evening 음성 합성)
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

from adapters.weather_open_meteo import fetch_two_day_forecast
from config import ALL_HOURS, CITIES
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


async def _amain(
    cities: list[str],
    target_hours: list[int],
    docs_root: Path,
    project_id: str,
) -> int:
    total_ok = 0
    total_fail = 0
    total_skip = 0
    for city in cities:
        # Open-Meteo는 도시당 한 번만 — fill-today에서 hour마다 같은 forecast를
        # 24번 fetch하던 게 진짜 비효율이었음. 5배 빠르고 ConnectTimeout 노출도 1/24.
        try:
            logging.info("Fetching forecast for %s (once for all hours) ...", city)
            forecast = await fetch_two_day_forecast(city)
            today, tomorrow = forecast
            logging.info("✓ forecast: today=%s / tomorrow=%s", today.overall_condition, tomorrow.overall_condition)
        except Exception as e:
            logging.error("✗ %s — forecast fetch failed: %r (skipping city)", city, e)
            total_fail += 4 * len(target_hours)
            continue

        for target_hour in target_hours:
            logging.info("=" * 60)
            logging.info("Starting: %s @ %02d시", city, target_hour)
            try:
                result = await generate_for_city_hour(
                    city=city,
                    target_hour=target_hour,
                    docs_root=docs_root,
                    project_id=project_id,
                    forecast=forecast,
                )
            except Exception as e:
                # 한 시간 슬롯 실패가 fill-today 전체를 중단시키지 않게 격리.
                # 다음 cron 또는 재실행이 따라잡음 (idempotent).
                logging.error(
                    "✗ %s @ %02d시 — fatal: %r (continuing to next hour)",
                    city, target_hour, e,
                )
                total_fail += 4  # 4 캐릭터 전부 실패로 간주
                continue
            total_ok += result["ok"]
            total_fail += result["fail"]
            total_skip += result.get("skip", 0)
            logging.info(
                "Done: %s @ %02d시 — ok=%d skip=%d fail=%d / %d",
                city,
                target_hour,
                result["ok"],
                result.get("skip", 0),
                result["fail"],
                result["total"],
            )

    logging.info("=" * 60)
    logging.info(
        "Summary: ok=%d skip=%d fail=%d", total_ok, total_skip, total_fail
    )
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
        "--fill-today",
        action="store_true",
        help=(
            "Fill all empty slots from 00시 to current KST hour. "
            "Idempotent — already-saved slots are skipped. "
            "Overrides --target-hour."
        ),
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

    if args.fill_today:
        # cron 시점 + 15분의 hour까지 처리 — :45 즈음 cron이 다음 hour를 미리 만들도록.
        # 6시 정각 푸시가 도래할 때 슬롯이 이미 준비돼있어야 하기 때문.
        # idempotent라 이미 만든 hour는 skip — 매 15분 cron이 4번 시도해도 호출 1번.
        upper = _next_target_hour()
        target_hours = [h for h in ALL_HOURS if h <= upper]
    elif args.target_hour is not None:
        target_hours = [args.target_hour]
    else:
        target_hours = [_next_target_hour()]

    _setup_env_defaults(args.project_id)
    sys.exit(
        asyncio.run(_amain(cities, target_hours, docs_root, args.project_id))
    )


if __name__ == "__main__":
    main()
