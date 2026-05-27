"""KMA API허브 레이더 합성영상(CAPPI) probe — 1프레임 fetch 후 메타데이터 출력.

목적: 본 구현에 들어가기 전에 응답 포맷, 이미지 크기, 시간 파라미터 형식 확인.

실행:
    cd worker
    set -a && source ../.env && set +a
    uv run python scripts/probe_radar.py
"""

from __future__ import annotations

import asyncio
import os
import sys
import zoneinfo
from datetime import datetime, timedelta
from pathlib import Path

import httpx

KST = zoneinfo.ZoneInfo("Asia/Seoul")
_BASE = "https://apihub.kma.go.kr/api/typ01/cgi-bin/url"


def _auth_key() -> str:
    key = os.environ.get("KMA_APIHUB_KEY", "").strip()
    if not key:
        raise RuntimeError("KMA_APIHUB_KEY 환경변수가 없어요")
    return key


def _latest_radar_tm() -> str:
    """레이더 합성영상은 5분 단위. 안전 버퍼 10분 빼고 직전 5분 슬롯."""
    t = datetime.now(KST) - timedelta(minutes=10)
    minute = (t.minute // 5) * 5
    return t.strftime("%Y%m%d%H") + f"{minute:02d}"


async def _probe(endpoint: str, params: dict, label: str) -> None:
    url = f"{_BASE}/{endpoint}"
    print(f"\n=== {label} ===")
    print(f"URL: {url}")
    print(f"Params (key 가림): { {**params, 'authKey': '***'} }")
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.get(url, params=params)
            print(f"Status: {resp.status_code}")
            print(f"Content-Type: {resp.headers.get('content-type')}")
            print(f"Bytes: {len(resp.content)}")
            head = resp.content[:16]
            print(f"Magic: {head.hex()}")
            is_png = head.startswith(b"\x89PNG\r\n\x1a\n")
            print(f"PNG?  {is_png}")
            if is_png:
                # IHDR chunk: bytes 16~24가 width, height (big-endian uint32)
                width = int.from_bytes(resp.content[16:20], "big")
                height = int.from_bytes(resp.content[20:24], "big")
                print(f"PNG 크기: {width} × {height}")
            else:
                # 텍스트 응답이면 앞부분 미리보기 (에러 메시지일 가능성)
                try:
                    print(f"본문 미리보기: {resp.text[:500]!r}")
                except Exception:
                    pass
            # 저장
            out = Path(f"/tmp/probe_{label.replace(' ', '_')}.bin")
            out.write_bytes(resp.content)
            print(f"저장: {out}")
    except Exception as e:
        print(f"ERROR: {type(e).__name__}: {e}")


async def main() -> None:
    tm = _latest_radar_tm()
    key = _auth_key()
    print(f"target tm: {tm}")

    # 2.2.1 본 데이터 — HSR 마스킹 한반도, Binary (속도 우선)
    await _probe(
        "nph-rdr_cmp1_api",
        {
            "tm": tm,
            "cmp": "HSR",
            "qcd": "MSK",
            "obs": "ECHO",
            "map": "HB",
            "disp": "B",
            "authKey": key,
        },
        "rdr_cmp1_hsr_msk_bin",
    )
    # 같은 데이터 ASCII (앞부분만 확인)
    await _probe(
        "nph-rdr_cmp1_api",
        {
            "tm": tm,
            "cmp": "HSR",
            "qcd": "MSK",
            "obs": "ECHO",
            "map": "HB",
            "disp": "A",
            "authKey": key,
        },
        "rdr_cmp1_hsr_msk_ascii",
    )
    # 4.1 격자→위경도 매핑 — URL 변형들
    await _probe(
        "nph-rdr_latlon_api",
        {"cmp": "HSR", "latlon": "lon", "disp": "A", "authKey": key},
        "rdr_latlon_lon_ascii",
    )
    await _probe(
        "nph-rdr_latlon_api",
        {"cmp": "HSR", "latlon": "lon", "disp": "B", "authKey": key},
        "rdr_latlon_lon_bin",
    )
    await _probe(
        "nph-rdr_latlon_api",
        {"cmp": "HSR", "latlon": "lat", "disp": "B", "authKey": key},
        "rdr_latlon_lat_bin",
    )
    # 가능한 다른 endpoint 이름들
    await _probe(
        "nph-rdr_latlon",
        {"cmp": "HSR", "latlon": "lon", "disp": "B", "authKey": key},
        "rdr_latlon_alt1",
    )
    await _probe(
        "nph-rdr_latlon_inf",
        {"cmp": "HSR", "latlon": "lon", "disp": "B", "authKey": key},
        "rdr_latlon_alt2",
    )


if __name__ == "__main__":
    asyncio.run(main())
