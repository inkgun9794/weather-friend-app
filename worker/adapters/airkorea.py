"""한국환경공단(에어코리아) 대기오염정보 OpenAPI 어댑터.

worker가 서버에서 호출해 Firestore에 캐시 → 앱은 키 없이 읽기만.
(이전엔 클라이언트가 폰에서 직접 호출했으나, KMA처럼 worker→Firestore로 이관.)

흐름:
  1) fetch_stations  — 전국 측정소 목록 1회 (getMsrstnList).
  2) nearest_station — 도시 좌표에서 haversine 최근접 측정소.
  3) fetch_realtime  — 측정소 실시간 PM10/PM2.5 + 등급 (getMsrstnAcctoRltmMesureDnsty).

환경변수:
- AIRKOREA_SERVICE_KEY: data.go.kr 발급 키. Encoding/Decoding 어느 형태든 OK —
  httpx가 params를 다시 인코딩하므로 unquote로 한 번 디코딩해 흡수(이중 인코딩 방지).

모든 실패(키 없음/네트워크/HTTP/파싱)는 raise하지 않고 None/[]로 수렴 →
호출부가 KMA 본 흐름을 막지 않는다.
"""

from __future__ import annotations

import logging
import math
import os
from dataclasses import dataclass
from typing import Any
from urllib.parse import unquote

import httpx

log = logging.getLogger(__name__)

_BASE = "https://apis.data.go.kr/B552584"
_TIMEOUT_SEC = 30.0

# 최근접 측정소가 이보다 멀면 신뢰할 수 없어 None(전국 측정소가 촘촘해 정상 좌표면
# 거의 항상 이 거리 내 존재).
_MAX_STATION_KM = 50.0


def _service_key() -> str:
    return unquote(os.environ.get("AIRKOREA_SERVICE_KEY", "").strip())


@dataclass(frozen=True)
class Station:
    name: str
    lat: float
    lon: float


@dataclass(frozen=True)
class AirQuality:
    """측정소 실시간 미세먼지 스냅샷. 농도 ㎍/㎥, 등급 환경부 한국어."""

    pm10: int | None
    pm25: int | None
    pm10_grade: str | None
    pm25_grade: str | None


async def fetch_stations(client: httpx.AsyncClient) -> list[Station]:
    """전국 측정소 목록 — getMsrstnList. numeric dmX/dmY인 항목만 보존.

    ver<1.1 응답은 dmX/dmY(경도/위도)가 뒤바뀌어 오므로, 두 값의 숫자 범위로
    한국 위경도(위도≈33~39, 경도≈124~132)에 맞게 lat/lon을 배정한다.
    """
    key = _service_key()
    if not key:
        return []
    data = await _get_json(client, "/MsrstnInfoInqireSvc/getMsrstnList", {
        "serviceKey": key,
        "returnType": "json",
        "numOfRows": "700",
        "pageNo": "1",
    })
    items = _items(data)
    stations: list[Station] = []
    for raw in items:
        if not isinstance(raw, dict):
            continue
        name = str(raw.get("stationName") or "").strip()
        a = _to_float(raw.get("dmX"))
        b = _to_float(raw.get("dmY"))
        if not name or a is None or b is None:
            continue
        coord = _as_lat_lon(a, b)
        if coord is None:
            continue
        stations.append(Station(name=name, lat=coord[0], lon=coord[1]))
    return stations


def nearest_station(
    stations: list[Station], lat: float, lon: float,
) -> Station | None:
    best: Station | None = None
    best_km = math.inf
    for s in stations:
        km = _haversine_km(lat, lon, s.lat, s.lon)
        if km < best_km:
            best_km = km
            best = s
    if best is None or best_km > _MAX_STATION_KM:
        return None
    return best


async def fetch_realtime(
    client: httpx.AsyncClient, station_name: str,
) -> AirQuality | None:
    """측정소 실시간 PM10/PM2.5 + 등급 — getMsrstnAcctoRltmMesureDnsty(ver=1.3)."""
    key = _service_key()
    if not key:
        return None
    data = await _get_json(
        client,
        "/ArpltnInforInqireSvc/getMsrstnAcctoRltmMesureDnsty",
        {
            "serviceKey": key,
            "returnType": "json",
            "numOfRows": "1",
            "pageNo": "1",
            "stationName": station_name,
            "dataTerm": "DAILY",
            "ver": "1.3",
        },
    )
    items = _items(data)
    if not items or not isinstance(items[0], dict):
        return None
    item = items[0]
    return AirQuality(
        pm10=_parse_pm(item.get("pm10Value")),
        pm25=_parse_pm(item.get("pm25Value")),
        pm10_grade=_grade_ko(item.get("pm10Grade1h")),
        pm25_grade=_grade_ko(item.get("pm25Grade1h")),
    )


# ────────────────────────────────────────────────────────────────────────
# 내부 헬퍼
# ────────────────────────────────────────────────────────────────────────


async def _get_json(
    client: httpx.AsyncClient, path: str, params: dict[str, Any],
) -> dict | None:
    """GET → JSON. 실패는 None (미세먼지는 비치명 보조 데이터)."""
    try:
        resp = await client.get(f"{_BASE}{path}", params=params)
        if resp.status_code != 200:
            log.warning("AirKorea %s HTTP %d", path, resp.status_code)
            return None
        return resp.json()
    except Exception as e:  # noqa: BLE001 — 비치명, 호출부가 None 처리.
        log.warning("AirKorea %s 실패: %s", path, e)
        return None


def _items(data: dict | None) -> list:
    if not data:
        return []
    body = (data.get("response") or {}).get("body") or {}
    return body.get("items") or []


def _as_lat_lon(a: float, b: float) -> tuple[float, float] | None:
    def is_lat(v: float) -> bool:
        return 30 <= v <= 43

    def is_lon(v: float) -> bool:
        return 120 <= v <= 135

    if is_lat(b) and is_lon(a):  # dmX=경도(a), dmY=위도(b) — 정상
        return (b, a)
    if is_lat(a) and is_lon(b):  # 뒤바뀐 경우
        return (a, b)
    return None


def _parse_pm(raw: Any) -> int | None:
    """PM 농도 문자열 → int. '-'/''/비정상은 None (0이나 예외 아님)."""
    s = str(raw).strip() if raw is not None else ""
    if not s or s == "-":
        return None
    try:
        return int(float(s))
    except (TypeError, ValueError):
        return None


def _grade_ko(code: Any) -> str | None:
    """등급 코드 '1'~'4' → 환경부 한국어. 그 외는 None."""
    return {"1": "좋음", "2": "보통", "3": "나쁨", "4": "매우나쁨"}.get(
        str(code).strip() if code is not None else ""
    )


def _to_float(v: Any) -> float | None:
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    earth = 6371.0
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(d_lon / 2) ** 2
    )
    return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
