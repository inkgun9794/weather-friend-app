"""기록 리마인더 문구 생성 → Firestore 저장. 하루 1회 cron.

Firestore 레이아웃:
    record_reminder/daily = {
        date: "2026-06-10",          # KST 생성일
        title: "오늘의 기록",
        messages: ["문구1", ...],     # Gemini 2.5 Flash 생성 풀
        generated_at: <server ts>,
    }

앱은 이 문서를 읽어 날짜별로 문구 하나를 골라 19시 로컬 알림 본문으로 쓴다.
실패해도 앱에 내장 fallback이 있으므로 치명적이지 않다.

Required env:
- GEMINI_API_KEY
- GCP_PROJECT_ID (default: weather-friend-92281)

Usage:
    uv run python gen_record_reminder.py            # 기본 10개
    uv run python gen_record_reminder.py --count 12
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import os
import sys
import zoneinfo
from datetime import datetime

from google.cloud import firestore

from adapters.ai_reminder import generate_reminder_messages

KST = zoneinfo.ZoneInfo("Asia/Seoul")
log = logging.getLogger(__name__)

# Gemini 실패 시에도 비어 있지 않게 — 앱 내장 fallback과 동일 톤.
_FALLBACK = [
    "오늘 당신의 날씨 기분은 어땠나요? 지금 기록해보세요.",
    "하루가 저물기 전에, 오늘의 하늘을 남겨볼까요?",
    "오늘 마음의 날씨를 한 컷으로 기록해보세요.",
]
_TITLE = "오늘의 기록"


async def _amain(count: int, project_id: str) -> int:
    today = datetime.now(KST).strftime("%Y-%m-%d")

    try:
        messages = await generate_reminder_messages(count=count)
    except Exception as e:  # noqa: BLE001 — 어떤 실패든 fallback으로 계속.
        log.error("Gemini 생성 실패: %r — fallback 사용", e)
        messages = []
    if not messages:
        messages = list(_FALLBACK)

    db = firestore.AsyncClient(project=project_id)
    try:
        await (
            db.collection("record_reminder")
            .document("daily")
            .set(
                {
                    "date": today,
                    "title": _TITLE,
                    "messages": messages,
                    "generated_at": firestore.SERVER_TIMESTAMP,
                }
            )
        )
    finally:
        # firestore.AsyncClient.close()는 미타입(스텁 부재) — strict mypy 우회.
        db.close()  # type: ignore[no-untyped-call]

    log.info("✓ record_reminder/daily 저장: %d개 문구 (date=%s)", len(messages), today)
    for m in messages:
        log.info("   - %s", m)
    return 0


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%H:%M:%S",
    )
    for noisy in ("httpx", "google_genai", "google.auth", "urllib3"):
        logging.getLogger(noisy).setLevel(logging.WARNING)

    parser = argparse.ArgumentParser(description="Generate diary reminder messages")
    parser.add_argument("--count", type=int, default=10, help="생성할 문구 개수")
    parser.add_argument(
        "--project-id",
        default=os.environ.get("GCP_PROJECT_ID", "weather-friend-92281"),
        help="GCP project ID for Firestore",
    )
    args = parser.parse_args()

    os.environ.setdefault("GOOGLE_CLOUD_PROJECT", args.project_id)
    sys.exit(asyncio.run(_amain(args.count, args.project_id)))


if __name__ == "__main__":
    main()
