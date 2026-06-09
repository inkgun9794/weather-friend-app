"""캐릭터별 자기소개 음성 한 번 생성.

캐릭터 선택 화면(온보딩 / 설정)의 미리듣기 버튼이 재생할 정적 mp3.
앱 번들 자산으로 출하되므로 client/assets/character_intros/{id}.mp3에 저장.
한 번 실행해서 만든 후 client/pubspec.yaml에 등록된 그대로 commit + push.

Usage:
    export TYPECAST_API_KEY="..."
    export TYPECAST_API_KEY_B="..."
    cd worker
    uv run python synth_intros.py --character sohee
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import sys
from pathlib import Path

from adapters.tts_typecast import TypecastClient
from domain.character import CHARACTERS, CHARACTERS_BY_ID

# 음성용으로 정리된 자기소개 — 채팅 의성어(ㅎㅎ)는 빼고 자연 발화로.
_INTROS: dict[str, str] = {
    "jiyoung": "난 지영이야. 앞으로 잘 부탁해.",
    "sohee": "안녕하세요. 정확하고 자세한 날씨를 전해드리겠습니다.",
    "jihoon": (
        "아가씨, 흑표범이라는 가명으로 불리는 집사 지훈입니다. "
        "오늘의 날씨는 제가 세심히 살펴드리겠습니다."
    ),
    "siwon": "난 시원이야. 지금 날씨 궁금하지 않아? 내가 알려줄게!",
}


def _api_key_env_for_character(character_id: str) -> str:
    if character_id == "sohee":
        return "TYPECAST_API_KEY_B"
    return "TYPECAST_API_KEY"


async def amain(out_root: Path, character_id: str | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")

    missing = [c.id for c in CHARACTERS if c.id not in _INTROS]
    if missing:
        logging.error("Missing intro line for: %s", missing)
        return 1

    characters = (
        [CHARACTERS_BY_ID[character_id]]
        if character_id is not None
        else CHARACTERS
    )
    for char in characters:
        client = TypecastClient(
            api_key_env=_api_key_env_for_character(char.id)
        )
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
    parser = argparse.ArgumentParser(description="Synthesize character intro audio")
    parser.add_argument(
        "--character",
        choices=tuple(CHARACTERS_BY_ID),
        help="Generate one character only. Default: all characters.",
    )
    parser.add_argument(
        "--out-root",
        type=Path,
        default=(
            Path(__file__).resolve().parent.parent
            / "client"
            / "assets"
            / "character_intros"
        ),
    )
    args = parser.parse_args()

    # client/assets/character_intros/{id}.mp3 으로 저장 — Flutter 앱 번들 자산.
    sys.exit(asyncio.run(amain(args.out_root, args.character)))


if __name__ == "__main__":
    main()
