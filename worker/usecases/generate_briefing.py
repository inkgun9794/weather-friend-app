"""특정 시각 1시간치 브리핑 생성 오케스트레이션.

매시간 :50에 cron이 호출 → 다음 시각(HH:00)의 4 캐릭터 브리핑 생성.
실시간 forecast로 데이터 신선도 ↑, Gemini RPM 한도 안전.

6시 morning과 21시 evening은 Typecast 음성 합성 + FCM 발송.
21시 evening은 별도 Typecast 계정으로 합성한다.
"""

from __future__ import annotations

import asyncio
import logging
from pathlib import Path

import httpx

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
from domain.voice_script import normalize_voice_script_for_tts

log = logging.getLogger(__name__)

# Gemini 무료 한도(15 RPM) 보호용 동시 호출 제한
GEMINI_CONCURRENCY = 8
# Typecast Free 플랜은 동시 호출에서 429가 발생하므로 계정별 요청을 직렬화.
TYPECAST_CONCURRENCY = 1


def _is_typecast_auth_error(exc: BaseException) -> bool:
    """Return True only for permanent Typecast credential failures."""
    return (
        isinstance(exc, httpx.HTTPStatusError)
        and exc.response.status_code in (401, 403)
    )


def _typecast_api_key_env_for_hour(hour: int) -> str:
    """시간대별 Typecast 계정 키를 명시적으로 선택."""
    btype = briefing_type_for_hour(hour)
    if btype == BriefingType.EVENING:
        return "TYPECAST_API_KEY_B"
    return "TYPECAST_API_KEY"


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

    # CASUAL: 같은 도시·오늘의 직전 casual 메시지들 fetch → Gemini에 "이미 다룬 토픽" 컨텍스트로 전달.
    # 같은 BTS·컴백 등 인기 토픽 반복 방지 + 캐릭터끼리도 다양화.
    recent_topics: list[str] = []
    if btype == BriefingType.CASUAL:
        try:
            recent_topics = await store.recent_casual_transcripts(
                city=city, date=today.date, before_hour=hour, limit=10,
            )
        except Exception as e:
            log.warning("이전 casual 토픽 fetch 실패 (계속 진행): %s", e)

    # 1) 스크립트 생성 (Gemini) — 세마포어로 동시 호출 제한
    #    MORNING/EVENING: (message, voice_script) 둘 다.
    #    HOURLY: (message, None), today 필요.
    #    CASUAL: (message, None), today/tomorrow 없음 + 직전 토픽 list 전달
    async with gemini_sem:
        message_script, voice_script = await gemini.generate(
            character=character,
            briefing_type=btype,
            hour=hour,
            today=today if use_weather else None,
            tomorrow=tomorrow if btype == BriefingType.EVENING else None,
            recent_topics=recent_topics if btype == BriefingType.CASUAL else None,
        )

    # 2) 음성 합성 — 알람 슬롯 + voice_id 지정됐을 때
    audio_url: str | None = None
    if is_audio_slot(hour) and character.voice_actor_id:
        tts_text = normalize_voice_script_for_tts(voice_script or message_script)
        if voice_script:
            voice_script = tts_text
        try:
            async with typecast_sem:
                synth = await typecast.synthesize(
                    tts_text, character.voice_actor_id
                )
            audio_url = publisher.save_audio(
                city=city,
                date=today.date,
                hour=hour,
                character_id=character.id,
                audio_bytes=synth.audio_bytes,
                extension=synth.extension,
            )
        except httpx.HTTPStatusError as exc:
            if not _is_typecast_auth_error(exc):
                raise
            # An expired/revoked key cannot recover within this run. Persist the
            # text briefing so fill-today does not retry the same slot forever
            # and emit a GitHub Actions failure notification every 15 minutes.
            log.error(
                "Typecast 인증 실패(%d) — %s %02d시 %s 음성을 생략하고 "
                "텍스트 브리핑을 저장합니다. GitHub secret %s를 갱신하세요.",
                exc.response.status_code,
                city,
                hour,
                character.id,
                _typecast_api_key_env_for_hour(hour),
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

    # 4) FCM push — morning/evening 오디오 생성 성공 시에만.
    #    푸시 실패가 브리핑 저장을 무효화하면 안 됨 (이미 Firestore에 저장됐고
    #    다음 cron 재시도는 idempotent하게 skip할 것).
    if fcm is not None and audio_url and is_audio_slot(hour):
        try:
            await fcm.send_briefing(
                city=city,
                hour=hour,
                character_id=character.id,
                character_display_name=character.display_name,
                transcript=message_script,
                audio_url=audio_url,
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
    typecast = TypecastClient(
        api_key_env=_typecast_api_key_env_for_hour(target_hour)
    )
    typecast_sem = asyncio.Semaphore(TYPECAST_CONCURRENCY)
    publisher = PagesPublisher(docs_root)
    store = FirestoreMetadataStore(project_id)

    # FCM은 morning/evening 오디오 슬롯에서만 필요.
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
