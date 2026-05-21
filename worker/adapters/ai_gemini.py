"""Gemini API 어댑터 — 캐릭터 페르소나 + 시맨틱으로 스크립트 생성.

Transient 에러(5xx, 429, timeout) 자동 재시도 포함.
"""

from __future__ import annotations

import asyncio
import logging
import os

from google import genai
from google.genai import types

from domain.briefing import (
    SEMANTIC_INSTRUCTIONS,
    BriefingType,
    DayForecast,
)
from domain.character import Character

log = logging.getLogger(__name__)

_MAX_RETRIES = 3
_RETRY_BASE_DELAY_SEC = 2.0  # 2 → 4 → 8


def _is_retryable(error: Exception) -> bool:
    s = str(error)
    return any(
        token in s
        for token in (
            "503", "UNAVAILABLE",
            "429", "RESOURCE_EXHAUSTED",
            "500", "INTERNAL",
            "502", "504",
            "DEADLINE_EXCEEDED", "timeout",
        )
    )


def _parse_dual_output(raw: str) -> tuple[str, str | None]:
    """Gemini 응답에서 (메시지, 음성) 추출.

    [메시지]/[음성] 마커가 모두 있으면 두 섹션으로 분리.
    한쪽이라도 없으면 전체를 메시지로 fallback, 음성은 None.
    """
    if "[메시지]" not in raw or "[음성]" not in raw:
        return raw.strip(), None

    parts = raw.split("[음성]", 1)
    message = parts[0].replace("[메시지]", "").strip()
    voice = parts[1].strip() if len(parts) > 1 else ""

    if not message:
        return raw.strip(), None
    return message, (voice or None)

# gemini-2.5-flash는 무료 RPD 20밖에 안 됨. lite로 가야 우리 96/일 워크로드 가능.
# 짧은 한국어 페르소나 텍스트 생성엔 lite도 품질 충분.
_MODEL = "gemini-2.5-flash-lite"


def _weather_brief(
    briefing_type: BriefingType,
    hour: int,
    today: DayForecast,
    tomorrow: DayForecast | None,
) -> str:
    """캐릭터에게 줄 '재료' — 날씨 데이터를 자연어 요약으로."""
    if briefing_type == BriefingType.MORNING:
        return (
            f"【오늘({today.date}) 날씨】\n"
            f"- 전반: {today.overall_condition}\n"
            f"- 최고/최저: {today.high_c:.0f}°C / {today.low_c:.0f}°C\n"
            f"- 강수 예상 시간대: "
            f"{', '.join(f'{h}시' for h in today.rain_hours) or '없음'}\n"
        )

    if briefing_type == BriefingType.EVENING:
        assert tomorrow is not None, "EVENING briefing requires tomorrow's forecast"
        return (
            f"【오늘({today.date}) 요약】\n"
            f"- 전반: {today.overall_condition}\n"
            f"- 최고/최저: {today.high_c:.0f}°C / {today.low_c:.0f}°C\n\n"
            f"【내일({tomorrow.date}) 예보】\n"
            f"- 전반: {tomorrow.overall_condition}\n"
            f"- 최고/최저: {tomorrow.high_c:.0f}°C / {tomorrow.low_c:.0f}°C\n"
            f"- 강수 예상 시간대: "
            f"{', '.join(f'{h}시' for h in tomorrow.rain_hours) or '없음'}\n"
        )

    # HOURLY
    s = today.hourly[hour]
    return (
        f"【지금 {hour}시 날씨】\n"
        f"- {s.condition}, {s.temperature_c:.0f}°C "
        f"(체감 {s.feels_like_c:.0f}°C)\n"
        f"- 강수확률 {s.precipitation_prob}%, 풍속 {s.wind_speed_kmh:.1f}km/h, "
        f"습도 {s.humidity}%"
    )


class GeminiScriptGenerator:
    """Gemini 호출 한 곳에 캡슐화. 인스턴스 1개를 모든 호출에 재사용."""

    def __init__(self, api_key: str | None = None) -> None:
        self._client = genai.Client(api_key=api_key or os.environ["GEMINI_API_KEY"])

    async def generate(
        self,
        *,
        character: Character,
        briefing_type: BriefingType,
        hour: int,
        today: DayForecast,
        tomorrow: DayForecast | None = None,
    ) -> tuple[str, str | None]:
        """캐릭터의 메시지/음성 스크립트 생성.

        Returns:
            (message_script, voice_script_or_none).
            HOURLY 타입은 voice_script가 None.
        """
        semantic = SEMANTIC_INSTRUCTIONS[briefing_type].format(hour=hour)
        system_instruction = f"{character.persona_prompt}\n\n{semantic}"
        contents = _weather_brief(briefing_type, hour, today, tomorrow)

        config = types.GenerateContentConfig(
            system_instruction=system_instruction,
            temperature=0.9,
            max_output_tokens=500,
            # gemini-2.5-flash는 기본으로 thinking 모드. 짧은 텍스트 생성엔
            # thinking이 토큰 예산을 잡아먹어 응답이 잘리므로 비활성화.
            thinking_config=types.ThinkingConfig(thinking_budget=0),
        )

        last_exc: Exception | None = None
        for attempt in range(1, _MAX_RETRIES + 1):
            try:
                response = await self._client.aio.models.generate_content(
                    model=_MODEL,
                    contents=contents,
                    config=config,
                )
                return _parse_dual_output(response.text or "")
            except Exception as e:
                if not _is_retryable(e) or attempt == _MAX_RETRIES:
                    raise
                last_exc = e
                wait = _RETRY_BASE_DELAY_SEC * (2 ** (attempt - 1))
                log.warning(
                    "Gemini transient error (attempt %d/%d): %s — retry in %.0fs",
                    attempt, _MAX_RETRIES, e.__class__.__name__, wait,
                )
                await asyncio.sleep(wait)

        # 도달 불가능하지만 mypy/타입체커 만족용
        assert last_exc is not None
        raise last_exc
