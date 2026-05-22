"""Open-Meteo 날씨 forecast 어댑터.

무료, 인증 불필요. 2일치 시간별 forecast 조회.
"""

from __future__ import annotations

import asyncio
import logging

import httpx

from domain.briefing import DayForecast, WeatherSnapshot

log = logging.getLogger(__name__)

_TIMEOUT_SEC = 60.0
_MAX_RETRIES = 3
_RETRY_BASE_DELAY_SEC = 2.0  # 2 → 4 → 8

# MVP: 서울만. 도시 추가 시 좌표만 등록하면 됨.
CITY_COORDS: dict[str, tuple[float, float]] = {
    "seoul": (37.5665, 126.9780),
}

# WMO weather code → 한국어 (간단 매핑)
_WEATHER_CODE_KO: dict[int, str] = {
    0: "맑음",
    1: "대체로 맑음",
    2: "구름 조금",
    3: "흐림",
    45: "안개",
    48: "짙은 안개",
    51: "약한 이슬비",
    53: "이슬비",
    55: "강한 이슬비",
    61: "약한 비",
    63: "비",
    65: "강한 비",
    71: "약한 눈",
    73: "눈",
    75: "강한 눈",
    77: "싸락눈",
    80: "소나기",
    81: "강한 소나기",
    82: "매우 강한 소나기",
    85: "약한 눈 소나기",
    86: "강한 눈 소나기",
    95: "천둥번개",
    96: "천둥번개 (우박)",
    99: "강한 천둥번개",
}


def _condition_text(code: int) -> str:
    return _WEATHER_CODE_KO.get(code, "알 수 없음")


async def fetch_two_day_forecast(city: str) -> tuple[DayForecast, DayForecast]:
    """오늘 + 내일 forecast를 반환. (today, tomorrow). Timeout/5xx 재시도 포함."""
    if city not in CITY_COORDS:
        raise ValueError(f"Unsupported city: {city}")

    lat, lng = CITY_COORDS[city]
    last_exc: Exception | None = None

    for attempt in range(1, _MAX_RETRIES + 1):
        try:
            async with httpx.AsyncClient(timeout=_TIMEOUT_SEC) as client:
                resp = await client.get(
                    "https://api.open-meteo.com/v1/forecast",
                    params={
                        "latitude": lat,
                        "longitude": lng,
                        "hourly": (
                            "temperature_2m,apparent_temperature,precipitation_probability,"
                            "wind_speed_10m,relative_humidity_2m,weather_code"
                        ),
                        "daily": (
                            "temperature_2m_max,temperature_2m_min,weather_code,"
                            "precipitation_probability_max"
                        ),
                        "timezone": "Asia/Seoul",
                        "forecast_days": 2,
                    },
                )
                resp.raise_for_status()
                return _parse(resp.json(), city)
        except (httpx.TimeoutException, httpx.HTTPStatusError, httpx.NetworkError) as e:
            transient = isinstance(e, (httpx.TimeoutException, httpx.NetworkError)) or (
                isinstance(e, httpx.HTTPStatusError)
                and e.response.status_code in (500, 502, 503, 504)
            )
            if transient and attempt < _MAX_RETRIES:
                wait = _RETRY_BASE_DELAY_SEC * (2 ** (attempt - 1))
                log.warning(
                    "Open-Meteo %s (attempt %d/%d) — retry in %.0fs",
                    type(e).__name__, attempt, _MAX_RETRIES, wait,
                )
                await asyncio.sleep(wait)
                last_exc = e
                continue
            raise

    assert last_exc is not None
    raise last_exc


def _parse(data: dict, city: str) -> tuple[DayForecast, DayForecast]:
    daily = data["daily"]
    hourly = data["hourly"]

    days: list[DayForecast] = []
    for day_idx in range(2):
        date = daily["time"][day_idx]
        hour_start = day_idx * 24

        snapshots: list[WeatherSnapshot] = []
        rain_hours: list[int] = []
        for h in range(24):
            i = hour_start + h
            s = WeatherSnapshot(
                hour=h,
                temperature_c=float(hourly["temperature_2m"][i]),
                feels_like_c=float(hourly["apparent_temperature"][i]),
                condition=_condition_text(int(hourly["weather_code"][i])),
                precipitation_prob=int(hourly["precipitation_probability"][i] or 0),
                wind_speed_kmh=float(hourly["wind_speed_10m"][i]),
                humidity=int(hourly["relative_humidity_2m"][i]),
            )
            snapshots.append(s)
            if s.precipitation_prob >= 60:
                rain_hours.append(h)

        days.append(
            DayForecast(
                date=date,
                city=city,
                high_c=float(daily["temperature_2m_max"][day_idx]),
                low_c=float(daily["temperature_2m_min"][day_idx]),
                overall_condition=_condition_text(int(daily["weather_code"][day_idx])),
                rain_hours=tuple(rain_hours),
                hourly=tuple(snapshots),
            )
        )

    return days[0], days[1]
