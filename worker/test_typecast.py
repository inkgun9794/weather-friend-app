"""Typecast 단일 보이스 테스트.

특정 voice_id + 텍스트로 음성 생성해서 로컬 파일로 저장 → 들어보고 검증.

Usage:
    export TYPECAST_API_KEY="..."
    uv run python test_typecast.py <voice_id> [text]

예시:
    uv run python test_typecast.py tc_672c5f5ce59fac2a48faeaee
    uv run python test_typecast.py tc_xxx "오늘 비 와. 우산 챙겨."
"""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

from adapters.tts_typecast import TypecastClient


DEFAULT_TEXT = "오늘 비가 하루 종일 와. 17도니까 얇은 외투 걸치고 우산 챙겨"


async def amain(voice_id: str, text: str) -> int:
    print(f"voice_id: {voice_id}")
    print(f"text:     {text}")
    print(f"length:   {len(text)} chars")
    print()

    client = TypecastClient()
    print("Synthesizing ...")
    result = await client.synthesize(text, voice_id, output_format="mp3")

    out_path = Path(f"typecast_test_{voice_id}.mp3")
    out_path.write_bytes(result.audio_bytes)

    print(f"✓ Saved: {out_path.absolute()}")
    print(f"  Size:  {len(result.audio_bytes):,} bytes")
    print(f"  Type:  {result.content_type}")
    print("\n터미널에서 재생: open " + str(out_path))
    return 0


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: uv run python test_typecast.py <voice_id> [text]", file=sys.stderr)
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    voice_id = sys.argv[1]
    text = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_TEXT
    sys.exit(asyncio.run(amain(voice_id, text)))


if __name__ == "__main__":
    main()
