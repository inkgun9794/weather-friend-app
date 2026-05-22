"""브리핑 타입 정의 + 시간대별 시맨틱 지시.

시맨틱:
- MORNING (05/06시): 오늘 하루 forecast — 사용자가 하루를 준비할 수 있게
- EVENING (21/22시): 오늘 회고 + 내일 forecast — 내일 준비 도와줌
- HOURLY  (그 외):  현재 시각 스냅샷 — 텍스트만 (음성 X)
"""

from dataclasses import dataclass
from datetime import datetime
from enum import Enum


class BriefingType(str, Enum):
    MORNING = "morning"   # 05시 - 푸시 + 음성
    EVENING = "evening"   # 21시 - 푸시 + 음성
    HOURLY = "hourly"     # 나머지 22시간 - 텍스트만 (푸시 X, 앱 열어서 확인)


# 음성 슬롯(MORNING/EVENING)에 추가되는 출력 형식 지시.
# 메시지/음성 두 스크립트 분리: 화면에는 인터넷 어투, TTS는 자연 발화.
_VOICE_OUTPUT_SUFFIX = """

【출력 형식 — 반드시 준수】
이 시간은 음성 알람이야. 다음 두 가지 버전을 *모두* 만들어야 해.
정확히 아래 마커로 구분해서 출력:

[메시지]
화면에 보일 텍스트. 평소 페르소나대로 자유롭게.
(이모지, ㅋㅋ, ㄷㄷ, ㄹㅇ, 헐 등 인터넷 어투 OK)

[음성]
TTS가 발음할 텍스트. 다음 규칙 *모두* 지킬 것:
- **반말 유지** (존댓말 절대 X — "~세요", "~십니다", "~해요" 전부 금지)
- 종결어미는 페르소나의 반말 그대로: "~해", "~지", "~네", "~야", "~겠어", "~ㄴ다", "~ㅁ"
- 이모지/특수문자 절대 X (들으면 어색함)
- ㅋㅋ/ㄷㄷ/ㅠㅠ 같은 채팅 의성어 X
- "ㄹㅇ", "ㄱㄱ" 같은 인터넷 줄임말 → "진짜", "그래"
- "헐" → 가볍게 "와", "어머" 같은 자연 감탄사로
- 페르소나 톤은 유지 (따뜻함/시크/안정감/발랄함은 그대로)
- 길이: 50~90자

두 마커([메시지]/[음성]) *모두 포함*해야 함. 빈 줄로 구분.

【예시 — 시원의 경우】
[메시지]
헐 오늘 비 ㄹㅇ 미쳤음 ⛈️ 우산 안 챙기면 큰일남ㄷㄷ

[음성]
와 오늘 비 진짜 많이 온대! 우산 안 챙기면 큰일 나니까 꼭 챙겨야 돼.

【예시 — 지영의 경우】
[메시지]
오늘 비 많이 와. 우산 꼭 챙겨~ 감기 조심해 💕

[음성]
오늘 비 많이 와. 우산 꼭 챙기고, 감기 조심해. 따뜻하게 입고 나가.

(주의: 위 예시에서 "챙기세요" / "조심하세요" / "나가세요" 같은 존댓말은 절대 사용 안 함. 반말 유지.)
"""

# Gemini에 추가로 주는 시간대별 지시
SEMANTIC_INSTRUCTIONS: dict[BriefingType, str] = {
    BriefingType.MORNING: """【이 메시지의 역할】
지금은 새벽 {hour}시야. 사용자가 일어나서 처음 받는 메시지.
오늘 하루 전체 날씨를 가볍게 알려줘 — 옷차림, 우산, 외출 시 주의점 등.
중요한 변화(오후에 비, 갑작스런 한파 등)가 있으면 짧게 강조.
하루를 시작하는 톤으로."""
    + _VOICE_OUTPUT_SUFFIX,
    BriefingType.EVENING: """【이 메시지의 역할】
지금은 밤 {hour}시야. 사용자가 하루를 마무리하는 시점.
오늘 날씨 어땠는지 한 줄 회고 + 내일 날씨 미리 알려줘.
내일 준비할 것(옷차림, 우산 등)을 가볍게 추천.
편안하게 잘 자라는 느낌의 마무리."""
    + _VOICE_OUTPUT_SUFFIX,
    BriefingType.HOURLY: """【이 메시지의 역할】
지금은 {hour}시. 사용자가 앱을 열어서 이 시간대를 확인하는 상황.
현재 시각 날씨를 짧게 알려줘 (기온, 날씨, 강수 등).
정보 위주로 간결하게. 음성은 안 만드니까 메시지 텍스트 1개만 출력.""",
}


@dataclass(frozen=True)
class WeatherSnapshot:
    """Gemini에 전달할 날씨 요약 (캐릭터가 자연스럽게 풀어쓸 재료)."""

    hour: int                    # 0-23
    temperature_c: float         # 기온 (°C)
    feels_like_c: float          # 체감온도
    condition: str               # "맑음" | "흐림" | "비" | "눈" 등
    precipitation_prob: int      # 강수확률 (%)
    wind_speed_kmh: float        # 풍속
    humidity: int                # 습도 (%)
    pm10: int | None = None      # 미세먼지 (㎍/㎥), 옵션


@dataclass(frozen=True)
class DayForecast:
    """하루 전체 forecast — MORNING/EVENING 브리핑에 사용."""

    date: str                    # ISO date "2026-05-21"
    city: str
    high_c: float
    low_c: float
    overall_condition: str       # "대체로 맑음", "오후에 비" 등
    rain_hours: tuple[int, ...]  # 강수 예상 시간대 (있을 경우)
    hourly: tuple[WeatherSnapshot, ...]  # 시간별 상세


def briefing_type_for_hour(hour: int) -> BriefingType:
    """시간 → 브리핑 타입 매핑. config.ALARM_HOURS와 일관성 유지."""
    if hour == 5:
        return BriefingType.MORNING
    if hour == 21:
        return BriefingType.EVENING
    return BriefingType.HOURLY


def is_audio_slot(hour: int) -> bool:
    """이 시간에 음성을 생성할지 (Typecast TTS 호출 여부)."""
    return briefing_type_for_hour(hour) in (BriefingType.MORNING, BriefingType.EVENING)
