"""FCM 푸시 어댑터.

토픽 단위 발송. 토픽 명명 규칙:
    briefing-{city}-{slot}-{character_id}
    briefing-{city}-{slot}-{character_id}-audio-v2

기존 앱에는 첫 번째 토픽으로 일반 notification을 계속 보내고, 업데이트된 앱에는
두 번째 토픽으로 audio_url이 든 data push를 보내 재생 액션을 표시한다.

인증은 ADC (WIF 또는 GOOGLE_APPLICATION_CREDENTIALS) — 명시적 키 X.
"""

from __future__ import annotations

import asyncio
import logging

import firebase_admin
from firebase_admin import messaging

from domain.briefing import BriefingType, briefing_type_for_hour

log = logging.getLogger(__name__)

_AUDIO_BRIEFING_KIND = "audio_briefing"
_AUDIO_BRIEFING_CATEGORY = "audio_briefing"


def _topic_name(*, city: str, slot: BriefingType, character_id: str) -> str:
    return f"briefing-{city}-{slot.value}-{character_id}"


def _interactive_topic_name(
    *,
    city: str,
    slot: BriefingType,
    character_id: str,
) -> str:
    return f"{_topic_name(city=city, slot=slot, character_id=character_id)}-audio-v2"


def _build_legacy_message(
    *,
    topic: str,
    character_display_name: str,
    transcript: str,
) -> messaging.Message:
    return messaging.Message(
        topic=topic,
        notification=messaging.Notification(
            title=character_display_name,
            body=transcript,
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(sound="default"),
            ),
        ),
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                sound="default",
                channel_id="daily_briefing",
            ),
        ),
    )


def _build_briefing_message(
    *,
    topic: str,
    character_id: str,
    character_display_name: str,
    transcript: str,
    audio_url: str,
) -> messaging.Message:
    """Android는 data push, iOS는 action category가 있는 alert로 전송."""
    return messaging.Message(
        topic=topic,
        data={
            "kind": _AUDIO_BRIEFING_KIND,
            "title": character_display_name,
            "body": transcript,
            "audio_url": audio_url,
            "payload": audio_url,
            "character_id": character_id,
        },
        android=messaging.AndroidConfig(priority="high"),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    alert=messaging.ApsAlert(
                        title=character_display_name,
                        body=transcript,
                    ),
                    sound="default",
                    category=_AUDIO_BRIEFING_CATEGORY,
                ),
                payload=audio_url,
            ),
        ),
    )


class FcmPushClient:
    """FCM 토픽 발사 클라이언트.

    firebase-admin SDK는 동기 API라 asyncio.to_thread로 감싸 비동기 컨텍스트에서 호출.
    initialize_app은 idempotent하지 않아서 모듈 레벨 가드 필요.
    """

    def __init__(self) -> None:
        if not firebase_admin._apps:
            # ADC 사용 — GitHub Actions에서는 WIF SA, 로컬은 gcloud auth ADC
            firebase_admin.initialize_app()

    async def send_briefing(
        self,
        *,
        city: str,
        hour: int,
        character_id: str,
        character_display_name: str,
        transcript: str,
        audio_url: str,
    ) -> str:
        """알람 슬롯 1개 푸시. 성공 시 FCM message ID 반환.

        hour는 6(morning) 또는 21(evening)이어야 함 — 그 외는 ValueError.
        """
        slot = briefing_type_for_hour(hour)
        if slot not in (BriefingType.MORNING, BriefingType.EVENING):
            raise ValueError(f"hour {hour} is not an alarm slot (morning=6, evening=21)")

        legacy_topic = _topic_name(
            city=city,
            slot=slot,
            character_id=character_id,
        )
        topic = _interactive_topic_name(
            city=city,
            slot=slot,
            character_id=character_id,
        )
        legacy_message = _build_legacy_message(
            topic=legacy_topic,
            character_display_name=character_display_name,
            transcript=transcript,
        )
        message = _build_briefing_message(
            topic=topic,
            character_id=character_id,
            character_display_name=character_display_name,
            transcript=transcript,
            audio_url=audio_url,
        )
        legacy_result, interactive_result = await asyncio.gather(
            asyncio.to_thread(messaging.send, legacy_message),
            asyncio.to_thread(messaging.send, message),
            return_exceptions=True,
        )
        if isinstance(legacy_result, Exception):
            log.error("✗ Legacy FCM push failed: %r", legacy_result)
        if isinstance(interactive_result, Exception):
            log.error("✗ Interactive FCM push failed: %r", interactive_result)
        if isinstance(legacy_result, Exception) and isinstance(
            interactive_result,
            Exception,
        ):
            raise RuntimeError(
                "Both legacy and interactive FCM sends failed"
            ) from interactive_result

        log.info(
            "✓ FCM sent: legacy_topic=%s legacy_msg_id=%s "
            "interactive_topic=%s interactive_msg_id=%s",
            legacy_topic,
            legacy_result,
            topic,
            interactive_result,
        )
        if isinstance(interactive_result, str):
            return interactive_result
        assert isinstance(legacy_result, str)
        return legacy_result
