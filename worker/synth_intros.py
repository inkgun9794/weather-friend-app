"""캐릭터별 자기소개 음성 한 번 생성.

캐릭터 선택 화면(온보딩 / 설정)의 미리듣기 버튼이 재생할 정적 mp3.
앱 번들 자산으로 출하되므로 client/assets/character_intros/{id}.mp3에 저장.
한 번 실행해서 만든 후 client/pubspec.yaml에 등록된 그대로 commit + push.

Usage:
    export TYPECAST_API_KEY="..."
    cd worker
    uv run python synth_intros.py
"""

from __future__ import annotations

import asyncio
import logging
import sys
from pathlib import Path

from adapters.tts_typecast import TypecastClient
from domain.character import CHARACTERS, CHARACTERS_BY_ID

# 음성용으로 정리된 자기소개 — 채팅 의성어(ㅎㅎ)는 빼고 자연 발화로.
_INTROS: dict[str, str] = {
    "jiyoung": "난 지영이야. 앞으로 잘 부탁해.",
    "sohee": "난 소희야. 잘 부탁해.",
    "jihoon": "난 지훈이야. 앞으로 잘 지내보자.",
    "siwon": "난 시원이야. 지금 날씨 궁금하지 않아? 내가 알려줄게!",
}


async def amain(out_root: Path) -> int:
    logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")

    missing = [c.id for c in CHARACTERS if c.id not in _INTROS]
    if missing:
        logging.error("Missing intro line for: %s", missing)
        return 1

    client = TypecastClient()
    for char in CHARACTERS:
        text = _INTROS[char.id]
        logging.info("Synthesizing %s (%s): %r", char.id, char.voice_actor_id, text)
        result = await client.synthesize(text, char.voice_actor_id, output_format="mp3")
        out_path = out_root / f"{char.id}.mp3"
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_bytes(result.audio_bytes)
        logging.info("  → %s (%d bytes)", out_path, len(result.audio_bytes))

    logging.info("Done. Commit and push client/assets/character_intros/*.mp3 to publish.")
    return 0


def main() -> None:
    # client/assets/character_intros/{id}.mp3 으로 저장 — Flutter 앱 번들 자산.
    out_root = (
        Path(__file__).resolve().parent.parent / "client" / "assets" / "character_intros"
    )
    sys.exit(asyncio.run(amain(out_root)))


if __name__ == "__main__":
    main()
