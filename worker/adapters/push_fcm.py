"""FCM 푸시 어댑터.

토픽 단위 발송. 토픽 명명 규칙:
    briefing-{city}-{slot}-{character_id}
예: briefing-seoul-morning-jiyoung / briefing-seoul-evening-sohee

클라이언트는 선택된 캐릭터의 morning + evening 두 토픽만 구독한다.
서버는 알람 슬롯(5/21시) 생성 성공 시 4 캐릭터 × 2 슬롯 중 해당 슬롯의 4 토픽에 발사
— 각 토픽에 그 캐릭터의 transcript를 notification body로 직접 담아 보낸다.

인증은 ADC (WIF 또는 GOOGLE_APPLICATION_CREDENTIALS) — 명시적 키 X.
"""

from __future__ import annotations

import asyncio
import logging

import firebase_admin
from firebase_admin import messaging

from domain.briefing import BriefingType, briefing_type_for_hour

log = logging.getLogger(__name__)


def _topic_name(*, city: str, slot: BriefingType, character_id: str) -> str:
    return f"briefing-{city}-{slot.value}-{character_id}"


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
    ) -> str:
        """알람 슬롯 1개 푸시. 성공 시 FCM message ID 반환.

        hour는 5(morning) 또는 21(evening)이어야 함 — 그 외는 ValueError.
        """
        slot = briefing_type_for_hour(hour)
        if slot not in (BriefingType.MORNING, BriefingType.EVENING):
            raise ValueError(
                f"hour {hour} is not an alarm slot (morning=5 / evening=21)"
            )

        topic = _topic_name(city=city, slot=slot, character_id=character_id)
        message = messaging.Message(
            topic=topic,
            notification=messaging.Notification(
                title=character_display_name,
                body=transcript,
            ),
            # iOS 알림 사운드/표시 기본값. data payload는 일단 비움 — 필요시 추가.
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
        msg_id = await asyncio.to_thread(messaging.send, message)
        log.info("✓ FCM sent: topic=%s msg_id=%s", topic, msg_id)
        return msg_id
