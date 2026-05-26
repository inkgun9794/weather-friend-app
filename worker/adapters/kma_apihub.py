"""KMA API허브 어댑터.

초단기예보 격자 (nph-dfs_vsrt_grd) 호출. 한반도 149×253 격자를 텍스트 CSV로
받아 KmaGrid 객체로 파싱.

환경변수:
- KMA_APIHUB_KEY: apihub.kma.go.kr에서 발급받은 authKey
"""

from __future__ import annotations

import asyncio
import logging
import os
import re
from dataclasses import dataclass

import httpx

log = logging.getLogger(__name__)

_TIMEOUT_SEC = 60.0
_MAX_RETRIES = 3
_RETRY_BASE_DELAY_SEC = 2.0

_BASE = "https://apihub.kma.go.kr/api/typ01/cgi-bin/url"

NX = 149
NY = 253
MISSING_VALUE = -99.0

# 응답에는 실수만 들어있으나 부호 + 소수점 안전하게 매칭.
_NUMBER_RE = re.compile(r"-?\d+\.\d+|-?\d+")


def _auth_key() -> str:
    key = os.environ.get("KMA_APIHUB_KEY", "").strip()
    if not key:
        raise RuntimeError("KMA_APIHUB_KEY environment variable is not set")
    return key


@dataclass(frozen=True)
class KmaGrid:
    """한반도 동네예보 격자 (149×253). 1-based 좌표.

    저장 순서는 좌측하단 → 우측 → 다음 행 (PDF '동네예보격자영역정보' 명시).
    `values[(ny-1) * 149 + (nx-1)]` 로 (nx, ny) 조회.
    """

    var: str            # 예보변수 이름 (e.g. "RN1", "T1H", "PTY")
    tmfc: str           # 발표시각 YYYYMMDDHHMM
    tmef: str           # 발효시각 YYYYMMDDHH
    values: tuple[float, ...]   # 길이 = NX * NY = 37697

    @property
    def nx_size(self) -> int:
        return NX

    @property
    def ny_size(self) -> int:
        return NY

    def at(self, nx: int, ny: int) -> float | None:
        """1-based 좌표로 값 조회. 비관측영역(-99)이면 None."""
        if not (1 <= nx <= NX and 1 <= ny <= NY):
            raise ValueError(f"out of range: nx={nx} ny={ny}")
        v = self.values[(ny - 1) * NX + (nx - 1)]
        return None if v == MISSING_VALUE else v


async def fetch_vsrt_grid(*, var: str, tmfc: str, tmef: str) -> KmaGrid:
    """초단기예보 격자 1개 변수 조회.

    Args:
        var: 단일 변수명 (RN1, T1H, PTY, SKY 등). 한 호출에 한 변수.
        tmfc: 발표시각 YYYYMMDDHHMM (10분 간격, 매시 00·10·20·30·40·50분)
        tmef: 발효시각 YYYYMMDDHH (tmfc 기준 +1 ~ +6시간)
    """
    url = f"{_BASE}/nph-dfs_vsrt_grd"
    params = {
        "tmfc": tmfc,
        "tmef": tmef,
        "vars": var,
        "authKey": _auth_key(),
    }
    text = await _get_text(url, params)
    values = _parse_grid_csv(text)
    if len(values) != NX * NY:
        raise ValueError(
            f"Unexpected grid size: got {len(values)}, expected {NX * NY} "
            f"(var={var} tmfc={tmfc} tmef={tmef})"
        )
    return KmaGrid(var=var, tmfc=tmfc, tmef=tmef, values=tuple(values))


async def _get_text(url: str, params: dict) -> str:
    last_exc: Exception | None = None
    for attempt in range(1, _MAX_RETRIES + 1):
        try:
            async with httpx.AsyncClient(timeout=_TIMEOUT_SEC) as client:
                resp = await client.get(url, params=params)
                resp.raise_for_status()
                return resp.text
        except (httpx.TimeoutException, httpx.HTTPStatusError, httpx.NetworkError) as e:
            transient = isinstance(e, (httpx.TimeoutException, httpx.NetworkError)) or (
                isinstance(e, httpx.HTTPStatusError)
                and e.response.status_code in (500, 502, 503, 504)
            )
            if transient and attempt < _MAX_RETRIES:
                wait = _RETRY_BASE_DELAY_SEC * (2 ** (attempt - 1))
                log.warning(
                    "KMA API허브 %s (attempt %d/%d) — retry in %.0fs",
                    type(e).__name__, attempt, _MAX_RETRIES, wait,
                )
                await asyncio.sleep(wait)
                last_exc = e
                continue
            raise
    assert last_exc is not None
    raise last_exc


def _parse_grid_csv(text: str) -> list[float]:
    """텍스트에서 모든 실수 값을 평탄하게 추출 (줄바꿈 무시).

    응답은 한 격자 행이 여러 텍스트 줄에 걸쳐 출력됨 (보통 줄당 20개 + 9개).
    """
    return [float(m.group()) for m in _NUMBER_RE.finditer(text)]
