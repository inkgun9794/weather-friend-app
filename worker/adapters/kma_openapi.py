"""KMA 공공데이터포털 OpenAPI 어댑터.

단기예보 (getVilageFcst), 중기육상예보 (getMidLandFcst), 중기기온예보 (getMidTa)
세 엔드포인트를 호출하고 도메인 dataclass로 반환.

환경변수:
- KMA_OPENAPI_KEY: data.go.kr에서 발급받은 service key (URL 인코딩된 상태로 저장)
"""

from __future__ import annotations

import asyncio
import logging
import os
from dataclasses import dataclass
from typing import Any
from urllib.parse import unquote

import httpx

log = logging.getLogger(__name__)

_TIMEOUT_SEC = 30.0
_MAX_RETRIES = 3
_RETRY_BASE_DELAY_SEC = 2.0  # 2 → 4 → 8

_BASE = "https://apis.data.go.kr/1360000"


class KmaOpenApiError(Exception):
    """KMA API가 200으로 반환한 비정상 응답 (resultCode != 00)."""


def _service_key() -> str:
    """data.go.kr 키는 보통 URL-encoded 형태로 발급/저장됨.
    httpx는 params를 다시 인코딩하므로, 원본을 한 번 디코딩한 후 넘김.
    """
    key = os.environ.get("KMA_OPENAPI_KEY", "").strip()
    if not key:
        raise RuntimeError("KMA_OPENAPI_KEY environment variable is not set")
    return unquote(key)


# ────────────────────────────────────────────────────────────────────────
# 도메인
# ────────────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class KmaShortHour:
    """단기예보 1시간 슬롯. 값이 없는 필드는 None."""

    fcst_date: str  # YYYYMMDD
    fcst_time: str  # HHMM (e.g., "0600")
    tmp: float | None  # 1시간 기온 (℃)
    tmx: float | None  # 일 최고기온 (℃) — 하루 1회만 채워짐
    tmn: float | None  # 일 최저기온 (℃) — 하루 1회만 채워짐
    pop: int | None  # 강수확률 (%)
    pty: int | None  # 강수형태 코드 — 0없음, 1비, 2비/눈, 3눈, 4소나기
    pcp: str | None  # 강수량 (raw: "강수없음" / "1mm 미만" / "5.0mm" 등)
    sno: str | None  # 신적설 (raw)
    sky: int | None  # 하늘상태 코드 — 1맑음, 3구름많음, 4흐림
    reh: int | None  # 습도 (%)
    wsd: float | None  # 풍속 (m/s)
    vec: int | None  # 풍향 (deg, 0=북)
    uuu: float | None  # 동서바람성분
    vvv: float | None  # 남북바람성분
    wav: float | None  # 파고 (m)


@dataclass(frozen=True)
class KmaShortForecast:
    base_date: str
    base_time: str
    nx: int
    ny: int
    hours: tuple[KmaShortHour, ...]


@dataclass(frozen=True)
class KmaUltraShortHour:
    """초단기예보 1시간 슬롯 (앞으로 6시간, 단일 좌표)."""

    fcst_date: str  # YYYYMMDD
    fcst_time: str  # HHMM
    t1h: float | None  # 기온 (℃)
    rn1: str | None  # 1시간 강수량 (raw: "강수없음" / "1.0mm" 등)
    pty: int | None  # 강수형태 코드 (초단기: 0없음, 1비, 2비/눈, 3눈, 5빗방울, 6빗방울눈날림, 7눈날림)
    sky: int | None  # 하늘상태
    reh: int | None  # 습도 (%)
    wsd: float | None  # 풍속 (m/s)
    vec: int | None  # 풍향 (deg)
    uuu: float | None
    vvv: float | None
    lgt: int | None  # 낙뢰


@dataclass(frozen=True)
class KmaUltraShortForecast:
    base_date: str
    base_time: str
    nx: int
    ny: int
    hours: tuple[KmaUltraShortHour, ...]


@dataclass(frozen=True)
class KmaMidLandDay:
    """중기육상예보 1일 슬롯.

    4~7일: 오전/오후 분리. 8~10일: 단일 값을 am/pm 양쪽에 동일하게 채움.
    """

    day_offset: int  # 4..10
    am_weather: str | None
    pm_weather: str | None
    am_rain_prob: int | None
    pm_rain_prob: int | None


@dataclass(frozen=True)
class KmaMidLandForecast:
    reg_id: str
    tm_fc: str
    days: tuple[KmaMidLandDay, ...]


@dataclass(frozen=True)
class KmaMidTempDay:
    day_offset: int  # 4..10
    ta_min: float | None
    ta_max: float | None


@dataclass(frozen=True)
class KmaMidTempForecast:
    reg_id: str
    tm_fc: str
    days: tuple[KmaMidTempDay, ...]


# ────────────────────────────────────────────────────────────────────────
# HTTP helpers
# ────────────────────────────────────────────────────────────────────────


async def _get_json(url: str, params: dict[str, Any]) -> dict:
    """재시도 포함 GET. resultCode != 00이면 KmaOpenApiError."""
    last_exc: Exception | None = None
    for attempt in range(1, _MAX_RETRIES + 1):
        try:
            async with httpx.AsyncClient(timeout=_TIMEOUT_SEC) as client:
                resp = await client.get(url, params=params)
                resp.raise_for_status()
                data = resp.json()
                _check_result_code(data)
                return data
        except (httpx.TimeoutException, httpx.HTTPStatusError, httpx.NetworkError) as e:
            transient = isinstance(e, (httpx.TimeoutException, httpx.NetworkError)) or (
                isinstance(e, httpx.HTTPStatusError)
                and e.response.status_code in (500, 502, 503, 504)
            )
            if transient and attempt < _MAX_RETRIES:
                wait = _RETRY_BASE_DELAY_SEC * (2 ** (attempt - 1))
                log.warning(
                    "KMA OpenAPI %s (attempt %d/%d) — retry in %.0fs",
                    type(e).__name__, attempt, _MAX_RETRIES, wait,
                )
                await asyncio.sleep(wait)
                last_exc = e
                continue
            raise
    assert last_exc is not None
    raise last_exc


def _check_result_code(data: dict) -> None:
    header = data.get("response", {}).get("header", {})
    code = header.get("resultCode")
    if code not in ("00", "0"):
        raise KmaOpenApiError(
            f"resultCode={code} msg={header.get('resultMsg', '')}"
        )


def _to_float(v: Any) -> float | None:
    if v is None or v == "":
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def _to_int(v: Any) -> int | None:
    if v is None or v == "":
        return None
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return None


# ────────────────────────────────────────────────────────────────────────
# 단기예보 (getVilageFcst)
# ────────────────────────────────────────────────────────────────────────


async def fetch_short_term_forecast(
    *,
    nx: int,
    ny: int,
    base_date: str,
    base_time: str,
    num_of_rows: int = 1000,
) -> KmaShortForecast:
    """단기예보 (격자 1점). 응답은 시간별 KmaShortHour로 그룹화되어 반환.

    base_time은 1일 8회 발표시각 중 가장 최근(02·05·08·11·14·17·20·23, "HH00").
    """
    url = f"{_BASE}/VilageFcstInfoService_2.0/getVilageFcst"
    params = {
        "serviceKey": _service_key(),
        "pageNo": 1,
        "numOfRows": num_of_rows,
        "dataType": "JSON",
        "base_date": base_date,
        "base_time": base_time,
        "nx": nx,
        "ny": ny,
    }
    data = await _get_json(url, params)
    items = data["response"]["body"]["items"]["item"]
    return _parse_short(items, base_date, base_time, nx, ny)


def _parse_short(
    items: list[dict], base_date: str, base_time: str, nx: int, ny: int,
) -> KmaShortForecast:
    grouped: dict[tuple[str, str], dict[str, Any]] = {}
    for it in items:
        key = (it["fcstDate"], it["fcstTime"])
        bucket = grouped.setdefault(key, {})
        bucket[it["category"]] = it["fcstValue"]

    hours: list[KmaShortHour] = []
    for (fcst_date, fcst_time), v in sorted(grouped.items()):
        hours.append(KmaShortHour(
            fcst_date=fcst_date,
            fcst_time=fcst_time,
            tmp=_to_float(v.get("TMP")),
            tmx=_to_float(v.get("TMX")),
            tmn=_to_float(v.get("TMN")),
            pop=_to_int(v.get("POP")),
            pty=_to_int(v.get("PTY")),
            pcp=v.get("PCP"),
            sno=v.get("SNO"),
            sky=_to_int(v.get("SKY")),
            reh=_to_int(v.get("REH")),
            wsd=_to_float(v.get("WSD")),
            vec=_to_int(v.get("VEC")),
            uuu=_to_float(v.get("UUU")),
            vvv=_to_float(v.get("VVV")),
            wav=_to_float(v.get("WAV")),
        ))
    return KmaShortForecast(
        base_date=base_date, base_time=base_time, nx=nx, ny=ny, hours=tuple(hours),
    )


# ────────────────────────────────────────────────────────────────────────
# 초단기예보 (getUltraSrtFcst)
# ────────────────────────────────────────────────────────────────────────


async def fetch_ultra_short_term_forecast(
    *,
    nx: int,
    ny: int,
    base_date: str,
    base_time: str,
    num_of_rows: int = 100,
) -> KmaUltraShortForecast:
    """초단기예보 (격자 1점, 앞으로 6시간 1시간 간격).

    base_time은 매시 30분 단위 (HHMM 중 분 = 30). 매시 45분 이후 호출.
    """
    url = f"{_BASE}/VilageFcstInfoService_2.0/getUltraSrtFcst"
    params = {
        "serviceKey": _service_key(),
        "pageNo": 1,
        "numOfRows": num_of_rows,
        "dataType": "JSON",
        "base_date": base_date,
        "base_time": base_time,
        "nx": nx,
        "ny": ny,
    }
    data = await _get_json(url, params)
    items = data["response"]["body"]["items"]["item"]
    return _parse_ultra_short(items, base_date, base_time, nx, ny)


def _parse_ultra_short(
    items: list[dict], base_date: str, base_time: str, nx: int, ny: int,
) -> KmaUltraShortForecast:
    grouped: dict[tuple[str, str], dict[str, Any]] = {}
    for it in items:
        key = (it["fcstDate"], it["fcstTime"])
        bucket = grouped.setdefault(key, {})
        bucket[it["category"]] = it["fcstValue"]

    hours: list[KmaUltraShortHour] = []
    for (fcst_date, fcst_time), v in sorted(grouped.items()):
        hours.append(KmaUltraShortHour(
            fcst_date=fcst_date,
            fcst_time=fcst_time,
            t1h=_to_float(v.get("T1H")),
            rn1=v.get("RN1"),
            pty=_to_int(v.get("PTY")),
            sky=_to_int(v.get("SKY")),
            reh=_to_int(v.get("REH")),
            wsd=_to_float(v.get("WSD")),
            vec=_to_int(v.get("VEC")),
            uuu=_to_float(v.get("UUU")),
            vvv=_to_float(v.get("VVV")),
            lgt=_to_int(v.get("LGT")),
        ))
    return KmaUltraShortForecast(
        base_date=base_date, base_time=base_time, nx=nx, ny=ny, hours=tuple(hours),
    )


# ────────────────────────────────────────────────────────────────────────
# 중기육상예보 (getMidLandFcst)
# ────────────────────────────────────────────────────────────────────────


async def fetch_mid_land_forecast(*, reg_id: str, tm_fc: str) -> KmaMidLandForecast:
    """중기육상예보. 발표시각은 매일 06·18시 (tm_fc=YYYYMMDDHHmm)."""
    url = f"{_BASE}/MidFcstInfoService/getMidLandFcst"
    params = {
        "serviceKey": _service_key(),
        "pageNo": 1,
        "numOfRows": 10,
        "dataType": "JSON",
        "regId": reg_id,
        "tmFc": tm_fc,
    }
    data = await _get_json(url, params)
    item = data["response"]["body"]["items"]["item"][0]
    return _parse_mid_land(item, reg_id, tm_fc)


def _parse_mid_land(item: dict, reg_id: str, tm_fc: str) -> KmaMidLandForecast:
    days: list[KmaMidLandDay] = []
    # 4~7일: am/pm 분리 (06시 발표는 4일부터, 18시 발표는 5일부터)
    for offset in range(4, 8):
        days.append(KmaMidLandDay(
            day_offset=offset,
            am_weather=item.get(f"wf{offset}Am"),
            pm_weather=item.get(f"wf{offset}Pm"),
            am_rain_prob=_to_int(item.get(f"rnSt{offset}Am")),
            pm_rain_prob=_to_int(item.get(f"rnSt{offset}Pm")),
        ))
    # 8~10일: 단일 (am/pm 양쪽에 같은 값)
    for offset in range(8, 11):
        wf = item.get(f"wf{offset}")
        rn = _to_int(item.get(f"rnSt{offset}"))
        days.append(KmaMidLandDay(
            day_offset=offset,
            am_weather=wf, pm_weather=wf,
            am_rain_prob=rn, pm_rain_prob=rn,
        ))
    return KmaMidLandForecast(reg_id=reg_id, tm_fc=tm_fc, days=tuple(days))


# ────────────────────────────────────────────────────────────────────────
# 중기기온예보 (getMidTa)
# ────────────────────────────────────────────────────────────────────────


async def fetch_mid_temp_forecast(*, reg_id: str, tm_fc: str) -> KmaMidTempForecast:
    """중기기온예보. 4~10일 일별 최저/최고."""
    url = f"{_BASE}/MidFcstInfoService/getMidTa"
    params = {
        "serviceKey": _service_key(),
        "pageNo": 1,
        "numOfRows": 10,
        "dataType": "JSON",
        "regId": reg_id,
        "tmFc": tm_fc,
    }
    data = await _get_json(url, params)
    item = data["response"]["body"]["items"]["item"][0]
    return _parse_mid_temp(item, reg_id, tm_fc)


def _parse_mid_temp(item: dict, reg_id: str, tm_fc: str) -> KmaMidTempForecast:
    days: list[KmaMidTempDay] = []
    for offset in range(4, 11):
        days.append(KmaMidTempDay(
            day_offset=offset,
            ta_min=_to_float(item.get(f"taMin{offset}")),
            ta_max=_to_float(item.get(f"taMax{offset}")),
        ))
    return KmaMidTempForecast(reg_id=reg_id, tm_fc=tm_fc, days=tuple(days))
