"""기록(다이어리) 리마인더 문구를 Gemini 2.5 Flash로 생성.

오후 7시까지 하늘 일기를 안 쓴 사용자에게 보낼 짧은 푸시 문구 '풀'을 만든다.
하루 1회 cron으로 호출 → Firestore `record_reminder/daily`에 저장 → 앱이 받아
로컬 알림 본문으로 사용한다(앱이 날짜별로 풀에서 하나를 고름).
"""

from __future__ import annotations

import json
import logging
import os

from google import genai
from google.genai import types

log = logging.getLogger(__name__)

# 앱 briefing과 동일 계열의 2.5-flash 사용.
_MODEL = "gemini-2.5-flash"

_SYSTEM = (
    "너는 '날사친'이라는 날씨·감정 일기 앱의 카피라이터야. "
    "사용자가 오늘의 하늘 사진과 '기분 날씨'를 기록하도록 부드럽게 권유하는 "
    "푸시 알림 문구를 쓴다."
)

_PROMPT = (
    "오후 7시까지 아직 오늘의 기록을 남기지 않은 사용자에게 보낼 푸시 알림 본문을 "
    "{n}개 만들어줘.\n\n"
    "조건:\n"
    "- 각 문구는 한국어 한 문장, 35자 이내, 따뜻하고 다정한 말투.\n"
    "- '오늘의 하늘/기분/날씨를 기록해보세요' 같은 행동을 자연스럽게 유도.\n"
    "- 부담이나 죄책감을 주지 말고 산뜻하게. 이모지는 0~1개만, 가끔.\n"
    "- 서로 표현이 겹치지 않게 다양하게.\n"
    "- 정치/종교/광고/외부 링크 금지.\n\n"
    '오직 JSON 문자열 배열로만 답해. 예: ["문구1", "문구2"]'
)


async def generate_reminder_messages(*, count: int = 10, api_key: str | None = None) -> list[str]:
    """리마인더 문구 풀 생성. 실패 시 예외를 그대로 올린다(caller가 fallback)."""
    client = genai.Client(api_key=api_key or os.environ["GEMINI_API_KEY"])
    config = types.GenerateContentConfig(
        system_instruction=_SYSTEM,
        temperature=1.0,
        max_output_tokens=800,
        # 짧은 텍스트엔 thinking이 토큰을 잡아먹어 응답이 잘리므로 비활성화.
        thinking_config=types.ThinkingConfig(thinking_budget=0),
        response_mime_type="application/json",
    )
    response = await client.aio.models.generate_content(
        model=_MODEL,
        contents=_PROMPT.format(n=count),
        config=config,
    )
    return _parse(response.text or "", count)


def _parse(raw: str, count: int) -> list[str]:
    """모델 응답(JSON 배열)을 문자열 리스트로. 코드펜스가 섞여도 견고하게 처리."""
    raw = raw.strip()
    if raw.startswith("```"):
        raw = raw.strip("`")
        newline = raw.find("\n")
        if newline != -1 and raw[:newline].strip().lower() in ("json", ""):
            raw = raw[newline + 1 :]
    try:
        data = json.loads(raw)
    except (ValueError, TypeError) as e:
        log.warning("reminder JSON 파싱 실패: %s — raw=%r", e, raw[:200])
        return []
    if not isinstance(data, list):
        return []
    out: list[str] = []
    for item in data:
        text = str(item).strip()
        if text:
            out.append(text)
    return out[:count]
