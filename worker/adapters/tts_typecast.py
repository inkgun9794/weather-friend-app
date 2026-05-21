"""Typecast TTS 어댑터.

실제 API 스펙 (https://typecast.ai/docs):
- POST https://api.typecast.ai/v1/text-to-speech
- Header: X-API-KEY: <key>
- Body: { text, voice_id, model, output: { audio_format } }
- Response: binary audio bytes (WAV 또는 MP3)
- voice_id 형식: "tc_" + 24자 hex (예: "tc_672c5f5ce59fac2a48faeaee")
"""

from __future__ import annotations

import os
from dataclasses import dataclass

import httpx

_BASE_URL = "https://api.typecast.ai"
_DEFAULT_MODEL = "ssfm-v30"


@dataclass(frozen=True)
class SynthesisResult:
    audio_bytes: bytes
    content_type: str  # "audio/mpeg", "audio/wav" 등
    extension: str  # "mp3", "wav"


class TypecastClient:
    """Typecast TTS HTTP 클라이언트.

    API 키는 lazy하게 로드 — 인스턴스 생성 시점이 아니라 실제 synthesize 호출 시점에 검증.
    덕분에 보이스 ID가 아직 비어있는 smoke 테스트 단계에서도 인스턴스 생성은 가능.
    """

    def __init__(self, api_key: str | None = None) -> None:
        self._api_key_override = api_key

    def _resolve_api_key(self) -> str:
        if self._api_key_override:
            return self._api_key_override
        key = os.environ.get("TYPECAST_API_KEY")
        if not key:
            raise RuntimeError(
                "TYPECAST_API_KEY environment variable is not set. "
                "Set it before calling synthesize()."
            )
        return key

    async def synthesize(
        self,
        text: str,
        voice_id: str,
        *,
        output_format: str = "mp3",
        model: str = _DEFAULT_MODEL,
    ) -> SynthesisResult:
        """텍스트 → 음성. 실패 시 httpx.HTTPStatusError 전파."""
        api_key = self._resolve_api_key()
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(
                f"{_BASE_URL}/v1/text-to-speech",
                headers={
                    "X-API-KEY": api_key,
                    "Content-Type": "application/json",
                },
                json={
                    "text": text,
                    "voice_id": voice_id,
                    "model": model,
                    "output": {
                        "audio_format": output_format,
                    },
                },
            )
            resp.raise_for_status()

        return SynthesisResult(
            audio_bytes=resp.content,
            content_type=resp.headers.get("content-type", f"audio/{output_format}"),
            extension=output_format,
        )
