"""특정 시각 1시간치 브리핑 생성 오케스트레이션.

매시간 :50에 cron이 호출 → 다음 시각(HH:00)의 4 캐릭터 브리핑 생성.
실시간 forecast로 데이터 신선도 ↑, Gemini RPM 한도 안전.

알람 시간(5/6/21/22)인 경우 추가로 Typecast 음성 합성.
"""

from __future__ import annotations

import asyncio
import logging
from pathlib import Path

from adapters.ai_gemini import GeminiScriptGenerator
from adapters.pages_publisher import PagesPublisher
from adapters.push_fcm import FcmPushClient
from adapters.store_firestore import BriefingMetadata, FirestoreMetadataStore
from adapters.tts_typecast import TypecastClient
from adapters.weather_open_meteo import fetch_two_day_forecast
from domain.briefing import (
    BriefingType,
    DayForecast,
    briefing_type_for_hour,
    is_audio_slot,
    needs_weather_context,
)
from domain.character import CHARACTERS, Character

log = logging.getLogger(__name__)

# Gemini 무료 한도(15 RPM) 보호용 동시 호출 제한
GEMINI_CONCURRENCY = 8
# Typecast Free 플랜 RPM이 낮아서 더 보수적으로
TYPECAST_CONCURRENCY = 2


async def _generate_one(
    *,
    city: str,
    hour: int,
    character: Character,
    today: DayForecast,
    tomorrow: DayForecast,
    gemini: GeminiScriptGenerator,
    gemini_sem: asyncio.Semaphore,
    typecast: TypecastClient,
    typecast_sem: asyncio.Semaphore,
    publisher: PagesPublisher,
    store: FirestoreMetadataStore,
    fcm: FcmPushClient | None,
    skip_existing: bool = True,
) -> bool:
    """슬롯 1개 생성. 이미 존재하면 skip하고 False 반환."""
    if skip_existing and await store.exists(
        city=city, date=today.date, hour=hour, character_id=character.id
    ):
        log.info("⊘ %s %02d시 %s — already exists, skip", city, hour, character.id)
        return False

    btype = briefing_type_for_hour(hour)
    use_weather = needs_weather_context(hour)

    # 1) 스크립트 생성 (Gemini) — 세마포어로 동시 호출 제한
    #    MORNING/EVENING: (message, voice_script) 둘 다, today/tomorrow 필요
    #    HOURLY: (message, None), today 필요
    #    CASUAL: (message, None), today/tomorrow 없음 (google_search로 트렌드 검색)
    async with gemini_sem:
        message_script, voice_script = await gemini.generate(
            character=character,
            briefing_type=btype,
            hour=hour,
            today=today if use_weather else None,
            tomorrow=tomorrow if btype == BriefingType.EVENING else None,
        )

    # 2) 음성 합성 — 알람 슬롯 + voice_id 지정됐을 때
    audio_url: str | None = None
    if is_audio_slot(hour) and character.voice_actor_id:
        tts_text = voice_script or message_script
        async with typecast_sem:
            synth = await typecast.synthesize(tts_text, character.voice_actor_id)
        audio_url = publisher.save_audio(
            city=city,
            date=today.date,
            hour=hour,
            character_id=character.id,
            audio_bytes=synth.audio_bytes,
            extension=synth.extension,
        )

    # 3) Firestore에 메타 저장. CASUAL은 weather_snapshot=None.
    weather_snapshot: dict | None = None
    if use_weather:
        snap = today.hourly[hour]
        weather_snapshot = {
            "temperature_c": snap.temperature_c,
            "feels_like_c": snap.feels_like_c,
            "condition": snap.condition,
            "precipitation_prob": snap.precipitation_prob,
            "wind_speed_kmh": snap.wind_speed_kmh,
            "humidity": snap.humidity,
        }
    await store.save(
        BriefingMetadata(
            city=city,
            date=today.date,
            hour=hour,
            character_id=character.id,
            type=btype.value,
            transcript=message_script,
            voice_script=voice_script,
            audio_url=audio_url,
            weather_snapshot=weather_snapshot,
        )
    )

    log.info(
        "✓ %s %02d시 %s (%s)%s",
        city,
        hour,
        character.id,
        btype.value,
        " +audio" if audio_url else "",
    )

    # 4) FCM push — 알람 슬롯 + 오디오 생성 성공 시에만.
    #    푸시 실패가 브리핑 저장을 무효화하면 안 됨 (이미 Firestore에 저장됐고
    #    다음 cron 재시도는 idempotent하게 skip할 것).
    if fcm is not None and audio_url and btype in (BriefingType.MORNING, BriefingType.EVENING):
        try:
            await fcm.send_briefing(
                city=city,
                hour=hour,
                character_id=character.id,
                character_display_name=character.display_name,
                transcript=message_script,
            )
        except Exception as e:
            log.error(
                "✗ FCM push failed for %s %02d시 %s: %r",
                city, hour, character.id, e,
            )

    return True


async def generate_for_city_hour(
    *,
    city: str,
    target_hour: int,
    docs_root: Path,
    project_id: str,
    skip_existing: bool = True,
    forecast: tuple[DayForecast, DayForecast] | None = None,
) -> dict[str, int]:
    """특정 도시 × 특정 시간 × 4 캐릭터 = 4 브리핑 생성. 성공/실패 카운트 반환.

    fill-today처럼 같은 도시의 여러 hour를 처리할 때는 caller가 forecast를
    한 번 fetch해서 inject하면 Open-Meteo 호출 수를 1/N로 줄일 수 있음.
    """
    if not 0 <= target_hour <= 23:
        raise ValueError(f"target_hour must be 0-23, got {target_hour}")

    if forecast is None:
        log.info("Fetching forecast for %s @ %02d시 ...", city, target_hour)
        today, tomorrow = await fetch_two_day_forecast(city)
        log.info("✓ forecast: today=%s / tomorrow=%s", today.overall_condition, tomorrow.overall_condition)
    else:
        today, tomorrow = forecast

    gemini = GeminiScriptGenerator()
    gemini_sem = asyncio.Semaphore(GEMINI_CONCURRENCY)
    typecast = TypecastClient()
    typecast_sem = asyncio.Semaphore(TYPECAST_CONCURRENCY)
    publisher = PagesPublisher(docs_root)
    store = FirestoreMetadataStore(project_id)

    # FCM은 알람 슬롯에서만 필요 — hourly 슬롯에는 비용 안 들이고 None 전달.
    fcm: FcmPushClient | None = (
        FcmPushClient() if is_audio_slot(target_hour) else None
    )

    try:
        tasks = [
            _generate_one(
                city=city,
                hour=target_hour,
                character=char,
                today=today,
                tomorrow=tomorrow,
                gemini=gemini,
                gemini_sem=gemini_sem,
                typecast=typecast,
                typecast_sem=typecast_sem,
                publisher=publisher,
                store=store,
                fcm=fcm,
                skip_existing=skip_existing,
            )
            for char in CHARACTERS
        ]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        created = sum(1 for r in results if r is True)
        skipped = sum(1 for r in results if r is False)
        failed = sum(1 for r in results if isinstance(r, BaseException))
        for r in results:
            if isinstance(r, BaseException):
                log.error("  ✗ failure: %r", r)
        return {
            "ok": created,
            "fail": failed,
            "skip": skipped,
            "total": len(results),
        }
    finally:
        await store.close()
