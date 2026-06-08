"""Gemini API 어댑터 — 캐릭터 페르소나 + 시맨틱으로 스크립트 생성.

진짜 일시적 에러(5xx, timeout)만 자동 재시도. 429(일일 quota 소진 / 선불 고갈)는
초 단위 재시도로 회복되지 않으므로(리셋이 몇 시간~24h 뒤) 재시도하지 않고 즉시
실패시킨다 — 3회 재시도가 한정된 일일 요청 quota를 더 태우는 걸 막기 위함.
"""

from __future__ import annotations

import asyncio
import logging
import os
from datetime import datetime
from zoneinfo import ZoneInfo

from google import genai
from google.genai import types

from domain.briefing import (
    HUMAN_VOICE_RULES,
    RAIN_MM_THRESHOLD,
    SEMANTIC_INSTRUCTIONS,
    BriefingType,
    DayForecast,
    RainBlock,
)
from domain.character import Character

KST = ZoneInfo("Asia/Seoul")

log = logging.getLogger(__name__)

_MAX_RETRIES = 3
_RETRY_BASE_DELAY_SEC = 2.0  # 2 → 4 → 8


def _is_retryable(error: Exception) -> bool:
    """진짜 일시적 에러(5xx, timeout)만 재시도.

    429/RESOURCE_EXHAUSTED(일일 quota 소진·선불 고갈)는 의도적으로 제외 — 초 단위
    재시도로는 회복되지 않고, 3회 재시도 × 15분 backfill로 한정된 일일 요청 quota만
    더 태운다. 즉시 실패시키고 다음 cron에 맡긴다.
    """
    s = str(error)
    return any(
        token in s
        for token in (
            "503", "UNAVAILABLE",
            "500", "INTERNAL",
            "502", "504",
            "DEADLINE_EXCEEDED", "timeout",
        )
    )


def _is_quota_exhausted(error: Exception) -> bool:
    """429 RESOURCE_EXHAUSTED (일일 quota 소진 / 선불 고갈).

    같은 모델을 재시도해봐야 소용없으니, 폴백 모델로 넘어가라는 신호로 쓴다.
    """
    s = str(error)
    return "RESOURCE_EXHAUSTED" in s or "429" in s


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

# 슬롯 타입별 모델 폴백 체인 — 1순위 모델이 일일 quota(per-model-per-day) 소진되면
# 자동으로 다음 모델로 넘어간다. 평소엔 1순위만 쓰지만, storm/스파이크로 한 모델이
# 막혀도 생성이 안 끊기게 함. (일일 한도: 3.1-lite 50 / 2.5-lite 200 / 2.5-flash 100)
# morning(6시)은 음성+푸시 첫인상이라 quality 우선 3.1-lite, 나머지는 비용 우선 2.5-lite.
# CASUAL은 google_search grounding이 필요한데 두 모델 다 지원.
_MODELS_ALARM = ("gemini-3.1-flash-lite", "gemini-2.5-flash")
_MODELS_HOURLY = ("gemini-2.5-flash-lite", "gemini-2.5-flash")
_MODELS_CASUAL = ("gemini-2.5-flash-lite", "gemini-2.5-flash")


def _models_for(briefing_type: BriefingType) -> tuple[str, ...]:
    if briefing_type == BriefingType.MORNING:
        return _MODELS_ALARM
    if briefing_type == BriefingType.CASUAL:
        return _MODELS_CASUAL
    return _MODELS_HOURLY


def _format_rain_blocks(blocks: tuple[RainBlock, ...]) -> str:
    """비 블록을 의미 단위 자연어로 — LLM이 톤을 조절할 수 있게.

    예: "9-10시 (2시간, 잠깐) / 14-19시 (6시간, 지속)"
        "9시 (1시간, 잠깐)"
        "없음"
    """
    if not blocks:
        return "없음"
    parts: list[str] = []
    for b in blocks:
        tone = "잠깐" if b.is_brief else "지속"
        if b.length == 1:
            parts.append(f"{b.start_hour}시 ({b.length}시간, {tone})")
        else:
            parts.append(f"{b.start_hour}-{b.end_hour}시 ({b.length}시간, {tone})")
    return " / ".join(parts)


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
            f"- 비 블록: {_format_rain_blocks(today.rain_blocks)}\n"
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
            f"- 비 블록: {_format_rain_blocks(tomorrow.rain_blocks)}\n"
        )

    # HOURLY — 비 여부는 강수"확률"이 아니라 실제 강수량(mm)으로 판단.
    # 확률만 보면 흐린 날 0mm인데도 "비 온다"고 오판함.
    s = today.hourly[hour]
    if s.precipitation_mm >= RAIN_MM_THRESHOLD:
        rain = f"강수 {s.precipitation_mm:.1f}mm 예상 (우산 챙길 만함)"
    else:
        rain = "강수 없음 (비 안 옴 — 확률은 높아도 실제론 안 와)"
    return (
        f"【지금 {hour}시 날씨】\n"
        f"- {s.condition}, {s.temperature_c:.0f}°C "
        f"(체감 {s.feels_like_c:.0f}°C)\n"
        f"- {rain}, 풍속 {s.wind_speed_kmh:.1f}km/h, 습도 {s.humidity}%"
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
        today: DayForecast | None = None,
        tomorrow: DayForecast | None = None,
        recent_topics: list[str] | None = None,
    ) -> tuple[str, str | None]:
        """캐릭터의 메시지/음성 스크립트 생성.

        Returns:
            (message_script, voice_script_or_none).
            HOURLY/CASUAL 타입은 voice_script가 None.
            CASUAL 타입은 today/tomorrow 불필요 (날씨 무관 잡담).

        Args:
            recent_topics: CASUAL 전용. 같은 도시·오늘의 이전 casual 메시지들.
                Gemini가 같은 토픽 안 반복하도록 prompt에 주입.
        """
        semantic = SEMANTIC_INSTRUCTIONS[briefing_type].format(hour=hour)
        system_instruction = (
            f"{character.persona_prompt}\n\n{HUMAN_VOICE_RULES}\n\n{semantic}"
        )

        # CASUAL은 날씨 데이터 대신 "지금 핫토픽 찾아서 친구톡 만들어" 요청.
        # google_search tool로 Gemini가 직접 트렌드 검색하게 함.
        config_kwargs: dict[str, object] = {
            "system_instruction": system_instruction,
            "temperature": 0.9,
            "max_output_tokens": 500,
            # gemini-2.5-flash는 기본으로 thinking 모드. 짧은 텍스트 생성엔
            # thinking이 토큰 예산을 잡아먹어 응답이 잘리므로 비활성화.
            "thinking_config": types.ThinkingConfig(thinking_budget=0),
        }
        if briefing_type == BriefingType.CASUAL:
            today_kst = datetime.now(KST).strftime("%Y년 %m월 %d일")
            prior_block = ""
            if recent_topics:
                # 같은 도시·오늘 이미 다룬 메시지들 — Gemini가 다른 토픽 고르도록.
                joined = "\n".join(f"  - {t}" for t in recent_topics)
                prior_block = (
                    "\n\n【오늘 이미 다룬 메시지들 (같은 토픽·표현 절대 반복 금지)】\n"
                    f"{joined}\n\n"
                    "위 메시지에 등장한 인물/그룹/사건과는 *다른* 토픽을 골라야 함. "
                    "예: 위에 BTS 얘기 있으면 다른 K-팝 그룹이나 다른 카테고리(스포츠/푸드/드라마 등)로."
                )
            contents = (
                f"오늘은 {today_kst}. 한국에서 지금 화제인 토픽 1개를 google_search로 "
                f"찾아서, 위 지침에 따라 친구가 카톡 보내듯 짧은 메시지 1개 만들어줘. "
                f"날씨 얘기 절대 X.\n\n"
                f"【허용 토픽 카테고리 — 이 안에서만 골라. 젠지/20대 관심사 위주】\n"
                f"  - K-pop / 아이돌 (컴백, 콘서트, MV, 멤버 근황·이슈)\n"
                f"  - 드라마 / 영화 / 웹툰 / 예능 (최근 핫한 거)\n"
                f"  - 카페 / 디저트 / 맛집 (신상, 핫플, 굿즈 콜라보)\n"
                f"  - 패션 / 뷰티 (트렌드 아이템, 브랜드, OOTD)\n"
                f"  - SNS 트렌드 / 밈 (인스타·틱톡·X에서 유행하는 거)\n"
                f"  - 게임 (롤·발로란트·신작·이스포츠 등)\n"
                f"  - 연애 / 자취 / 일상 (썸, 데이트, 친구 관계, 직장 썰)\n"
                f"  - 펫 / 라이프스타일 (강아지·고양이·운동·취미)\n"
                f"  - 여행 / 핫플레이스 (성수·연남·해외여행 등)\n"
                f"  - 음악 신곡 / 아티스트 / 페스티벌\n"
                f"  - 스포츠 가십 (선수 근황·하이라이트 정도, 정치적 X)\n\n"
                f"【절대 금지 토픽 — 해당하면 다른 카테고리에서 다시 골라】\n"
                f"  - 정치 (선거·정책·정당·대통령·국회·시위·정치인 발언)\n"
                f"  - 공부 / 시험 (수능·토픽·토익·자격증·학원·합격발표·입시)\n"
                f"  - 시사 / 사회 이슈 / 사건사고 / 범죄\n"
                f"  - 종교 / 군대 / 노동 분쟁\n"
                f"  - 주식 / 코인 / 부동산 / 투자\n"
                f"  - 의료 / 질병 / 사망 소식"
                f"{prior_block}"
            )
            config_kwargs["tools"] = [types.Tool(google_search=types.GoogleSearch())]
        else:
            assert today is not None, "weather briefing requires today forecast"
            contents = _weather_brief(briefing_type, hour, today, tomorrow)

        config = types.GenerateContentConfig(**config_kwargs)

        # 모델 폴백 체인: 1순위가 일일 quota 소진(429)되면 다음 모델로 자동 전환.
        models = _models_for(briefing_type)
        quota_exc: Exception | None = None
        for mi, model in enumerate(models):
            for attempt in range(1, _MAX_RETRIES + 1):
                try:
                    response = await self._client.aio.models.generate_content(
                        model=model,
                        contents=contents,
                        config=config,
                    )
                    return _parse_dual_output(response.text or "")
                except Exception as e:
                    # 일일 quota 소진(429): 같은 모델 재시도 무의미 → 다음 폴백 모델로.
                    if _is_quota_exhausted(e):
                        quota_exc = e
                        if mi < len(models) - 1:
                            log.warning(
                                "Gemini '%s' 일일 quota 소진 — 폴백 '%s' 시도",
                                model, models[mi + 1],
                            )
                        break  # 재시도 루프 탈출 → 다음 model
                    # 진짜 일시적 에러(5xx/timeout)만 같은 모델 재시도, 그 외 즉시 raise.
                    if not _is_retryable(e) or attempt == _MAX_RETRIES:
                        raise
                    wait = _RETRY_BASE_DELAY_SEC * (2 ** (attempt - 1))
                    log.warning(
                        "Gemini transient error (attempt %d/%d): %s — retry in %.0fs",
                        attempt, _MAX_RETRIES, e.__class__.__name__, wait,
                    )
                    await asyncio.sleep(wait)

        # 폴백 체인의 모든 모델이 quota 소진.
        assert quota_exc is not None
        raise quota_exc
