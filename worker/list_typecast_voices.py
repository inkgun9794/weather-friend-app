"""Typecast 사용 가능 한국어 보이스 목록 조회.

Usage:
    export TYPECAST_API_KEY="..."
    uv run python list_typecast_voices.py
"""

from __future__ import annotations

import os
import sys

import httpx


def main() -> int:
    api_key = os.environ.get("TYPECAST_API_KEY")
    if not api_key:
        print("ERROR: TYPECAST_API_KEY not set", file=sys.stderr)
        return 1

    resp = httpx.get(
        "https://api.typecast.ai/v2/voices",
        params={"model": "ssfm-v30"},
        headers={"X-API-KEY": api_key},
        timeout=30.0,
    )
    resp.raise_for_status()
    voices = resp.json()

    # 응답 형식이 list 또는 {voices: [...]} 일 수 있음 — 둘 다 처리
    if isinstance(voices, dict):
        voices = voices.get("voices", voices.get("data", []))

    # 한국어 보이스만 필터 (다양한 키 시도)
    def is_korean(v: dict) -> bool:
        langs = v.get("supported_languages", []) or v.get("languages", [])
        if any(s.lower().startswith("ko") for s in langs):
            return True
        # fallback: voice_name에 한글 포함
        name = v.get("voice_name", v.get("name", ""))
        return any("가" <= c <= "힣" for c in name)

    korean = [v for v in voices if is_korean(v)]
    if not korean:
        # 한국어 필터가 아무것도 안 잡으면 전체 출력
        korean = voices

    print(f"\n총 {len(korean)}개 한국어 보이스 발견:\n")
    print(f"{'voice_id':<40} {'name':<20} {'gender':<10} {'age':<10}")
    print("-" * 90)
    for v in korean:
        vid = v.get("voice_id", v.get("id", "?"))
        name = v.get("voice_name", v.get("name", "?"))
        gender = v.get("gender", "?")
        age = v.get("age", "?")
        print(f"{vid:<40} {name:<20} {gender:<10} {age:<10}")

    print("\nFull raw response (first item) for reference:")
    if korean:
        import json

        print(json.dumps(korean[0], indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
