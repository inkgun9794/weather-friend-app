"""KMA API허브 레이더 합성영상 어댑터.

레이더 합성장 한반도 마스킹 자료 (`nph-rdr_cmp1_api`) 호출.
500m 해상도, 2305×2881 격자, dBZ×100 정수값 binary로 받아 numpy로 파싱.

환경변수:
- KMA_APIHUB_KEY: apihub.kma.go.kr에서 발급받은 authKey
"""

from __future__ import annotations

import asyncio
import logging
import os
from dataclasses import dataclass

import httpx
import numpy as np

log = logging.getLogger(__name__)

_TIMEOUT_SEC = 60.0
_MAX_RETRIES = 3
_RETRY_BASE_DELAY_SEC = 2.0

_BASE = "https://apihub.kma.go.kr/api/typ01/cgi-bin/url"

# KMA HSR 한반도(HB) 마스킹 합성 표준 — docs 명시값.
HSR_NX = 2305
HSR_NY = 2881

# 관측영역 밖 / 에코 없음 (docs 명시값, dBZ×100 정수).
OUT_OF_RANGE = -30000
NO_ECHO = -25000

# 한반도(HB) 합성 영역의 위경도 bbox — 경험적 보정값.
# 격자 자체는 13°×13°지만 Lambert 원점이 격자 중심이 아니라 비대칭 offset (DFS 5km
# 격자 분석 + rain.do 비교로 추정). 중심을 (36.5°N, 127°E)로 잡음.
HSR_BBOX_SOUTH = 30.0
HSR_BBOX_WEST = 120.5
HSR_BBOX_NORTH = 43.0
HSR_BBOX_EAST = 133.5


def _auth_key() -> str:
    key = os.environ.get("KMA_APIHUB_KEY", "").strip()
    if not key:
        raise RuntimeError("KMA_APIHUB_KEY environment variable is not set")
    return key


@dataclass(frozen=True)
class RadarFrame:
    """레이더 합성장 한 시각의 격자값 (HSR HB)."""

    tm: str  # YYYYMMDDHHmm (KST)
    # shape (ny, nx) = (2881, 2305). 좌하단(0,0) → 우상단 순서로 그대로 reshape됨.
    # dtype int16. dBZ×100. OUT_OF_RANGE / NO_ECHO 마커 포함.
    values: np.ndarray


async def fetch_radar_hsr(tm: str) -> RadarFrame:
    """HSR 합성 한반도 마스킹 binary 1프레임.

    Args:
        tm: YYYYMMDDHHmm (5분 단위, KST). 없으면 가장 최근 자동.
    """
    url = f"{_BASE}/nph-rdr_cmp1_api"
    params = {
        "tm": tm,
        "cmp": "HSR",
        "qcd": "MSK",
        "obs": "ECHO",
        "map": "HB",
        "disp": "B",
        "authKey": _auth_key(),
    }
    raw = await _get_bytes(url, params)

    # 처음 4byte: nx(2), ny(2). little-endian uint16.
    if len(raw) < 4:
        raise ValueError(f"too short: {len(raw)}")
    nx = int.from_bytes(raw[0:2], "little")
    ny = int.from_bytes(raw[2:4], "little")
    if (nx, ny) != (HSR_NX, HSR_NY):
        raise ValueError(f"unexpected grid: nx={nx} ny={ny}")

    expected_data = nx * ny * 2  # int16
    if len(raw) - 4 < expected_data:
        raise ValueError(
            f"truncated body: got {len(raw)-4} bytes, expected {expected_data}"
        )

    # int16 little-endian. shape (ny, nx).
    arr = np.frombuffer(raw[4 : 4 + expected_data], dtype="<i2").reshape((ny, nx))
    return RadarFrame(tm=tm, values=arr)


async def _get_bytes(url: str, params: dict[str, str]) -> bytes:
    last_exc: Exception | None = None
    for attempt in range(1, _MAX_RETRIES + 1):
        try:
            async with httpx.AsyncClient(timeout=_TIMEOUT_SEC) as client:
                resp = await client.get(url, params=params)
                resp.raise_for_status()
                # 에러 응답이 JSON으로 올 수 있음 → magic 체크.
                if resp.content.startswith(b"{"):
                    raise ValueError(f"API error: {resp.text[:200]}")
                return resp.content
        except (httpx.TimeoutException, httpx.HTTPStatusError, httpx.NetworkError) as e:
            transient = isinstance(e, (httpx.TimeoutException, httpx.NetworkError)) or (
                isinstance(e, httpx.HTTPStatusError)
                and e.response.status_code in (500, 502, 503, 504)
            )
            if transient and attempt < _MAX_RETRIES:
                wait = _RETRY_BASE_DELAY_SEC * (2 ** (attempt - 1))
                log.warning(
                    "KMA radar %s (attempt %d/%d) — retry in %.0fs",
                    type(e).__name__, attempt, _MAX_RETRIES, wait,
                )
                await asyncio.sleep(wait)
                last_exc = e
                continue
            raise
    assert last_exc is not None
    raise last_exc
