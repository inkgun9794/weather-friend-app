"""GitHub Pages용 오디오 파일 출력.

`docs/briefings/{city}/{date}/{hour:02d}/{character_id}.{ext}` 로 저장.
Pages URL: https://inkgun9794.github.io/weather-friend-app/...
"""

from __future__ import annotations

from pathlib import Path

_PAGES_BASE_URL = "https://inkgun9794.github.io/weather-friend-app"


class PagesPublisher:
    """docs/ 디렉토리에 audio를 적절한 경로로 쓰고 공개 URL 반환."""

    def __init__(self, docs_root: Path) -> None:
        self._docs_root = docs_root.resolve()
        self._docs_root.mkdir(parents=True, exist_ok=True)

    def save_audio(
        self,
        *,
        city: str,
        date: str,
        hour: int,
        character_id: str,
        audio_bytes: bytes,
        extension: str = "mp3",
    ) -> str:
        rel_path = f"briefings/{city}/{date}/{hour:02d}/{character_id}.{extension}"
        full_path = self._docs_root / rel_path
        full_path.parent.mkdir(parents=True, exist_ok=True)
        full_path.write_bytes(audio_bytes)
        return f"{_PAGES_BASE_URL}/{rel_path}"
