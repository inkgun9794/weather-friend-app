"""Firestore의 voice_script를 읽어서 Typecast로 음성 합성.

이미 main.py로 Firestore에 저장된 voice_script를 그대로 사용해
선택한 voice_id로 들어보기 위한 스크립트.

Usage:
    uv run python synth_from_firestore.py <doc_id> <voice_id>

Examples:
    uv run python synth_from_firestore.py seoul_2026-05-21_05_jiyoung \\
        tc_5c789c34dabcfa0008b0a390

    uv run python synth_from_firestore.py seoul_2026-05-21_05_siwon \\
        tc_62849c0bb958a8ed96096c1c
"""

from __future__ import annotations

import asyncio
import os
import sys
from pathlib import Path

from google.cloud import firestore

from adapters.tts_typecast import TypecastClient


async def amain(doc_id: str, voice_id: str) -> int:
    project_id = os.environ.get("GCP_PROJECT_ID", "weather-friend-92281")
    os.environ.setdefault("GOOGLE_CLOUD_PROJECT", project_id)

    db = firestore.AsyncClient(project=project_id)
    typecast = TypecastClient()

    try:
        doc = await db.collection("briefings").document(doc_id).get()
        if not doc.exists:
            print(f"✗ ERROR: 도큐먼트 {doc_id} 없음", file=sys.stderr)
            return 1

        data = doc.to_dict() or {}
        voice_script = data.get("voice_script")
        transcript = data.get("transcript")
        character_id = data.get("character_id", "unknown")
        b_type = data.get("type", "?")

        if not voice_script:
            print(
                f"✗ ERROR: {doc_id}에 voice_script 없음 (type={b_type})",
                file=sys.stderr,
            )
            print(f"  (HOURLY 타입은 음성 X. 6시 morning 도큐먼트만 가능)", file=sys.stderr)
            return 1

        print(f"=== {character_id} ({b_type}) ===")
        print(f"voice_id:     {voice_id}")
        print(f"message:      {transcript}")
        print(f"voice_script: {voice_script}")
        print(f"length:       {len(voice_script)} chars")
        print()
        print("Synthesizing ...")

        result = await typecast.synthesize(voice_script, voice_id, output_format="mp3")
        out = Path(f"voice_{character_id}_{voice_id}.mp3")
        out.write_bytes(result.audio_bytes)

        print(f"✓ Saved: {out.absolute()}")
        print(f"  Size:  {len(result.audio_bytes):,} bytes")
        print()
        print(f"재생: open {out}")
        return 0
    finally:
        db.close()


def main() -> None:
    if len(sys.argv) != 3:
        print("Usage: uv run python synth_from_firestore.py <doc_id> <voice_id>", file=sys.stderr)
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    sys.exit(asyncio.run(amain(sys.argv[1], sys.argv[2])))


if __name__ == "__main__":
    main()
