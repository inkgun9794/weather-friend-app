"""Firestore 메타데이터 저장 어댑터.

도큐먼트 키: `{city}_{date}_{hour:02d}_{character_id}`
예: `seoul_2026-05-21_05_jiyoung`
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone

from google.cloud import firestore


@dataclass(frozen=True)
class BriefingMetadata:
    city: str
    date: str  # ISO "2026-05-21"
    hour: int
    character_id: str
    type: str  # BriefingType value
    transcript: str  # 메시지 화면용 텍스트 (이모지/ㅋㅋ OK)
    voice_script: str | None  # TTS용 자연 발화 (알람 시간만, 그 외 None)
    audio_url: str | None  # 음성 파일 URL (None = 텍스트만)
    weather_snapshot: dict


class FirestoreMetadataStore:
    """Firestore briefings 컬렉션에 메타 저장.

    WIF 또는 ADC를 통한 자동 인증 — 명시적 키 X.
    """

    def __init__(self, project_id: str, *, ttl_days: int = 2) -> None:
        self._db = firestore.AsyncClient(project=project_id)
        self._ttl_days = ttl_days

    async def save(self, meta: BriefingMetadata) -> None:
        doc_id = f"{meta.city}_{meta.date}_{meta.hour:02d}_{meta.character_id}"
        doc_ref = self._db.collection("briefings").document(doc_id)
        payload = {
            **asdict(meta),
            "generated_at": firestore.SERVER_TIMESTAMP,
            "expire_at": datetime.now(timezone.utc) + timedelta(days=self._ttl_days),
        }
        await doc_ref.set(payload)

    async def close(self) -> None:
        # firestore.AsyncClient는 명시적 close가 권장됨
        self._db.close()
