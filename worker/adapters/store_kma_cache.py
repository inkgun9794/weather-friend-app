"""KMA 캐시 Firestore 쓰기 어댑터.

컬렉션 레이아웃:
- `kma_short/{city_id}`     — 단기예보 (3시간 갱신)
- `kma_ultra/{city_id}`     — 초단기예보 카드용 (10분 갱신)
- `kma_mid_land/{reg_id}`   — 중기육상 (6시간 갱신)
- `kma_mid_temp/{reg_id}`   — 중기기온 (6시간 갱신)

문서마다 `updated_at` 서버 타임스탬프를 함께 저장 → 클라이언트는 stale 판단에 사용.
"""

from __future__ import annotations

from dataclasses import asdict
from datetime import datetime, timedelta, timezone

from google.cloud import firestore

from adapters.kma_openapi import (
    KmaMidLandForecast,
    KmaMidTempForecast,
    KmaShortForecast,
    KmaUltraShortForecast,
)


class KmaCacheStore:
    """WIF/ADC 자동 인증. Firestore AsyncClient."""

    def __init__(self, project_id: str, *, ttl_days: int = 1) -> None:
        self._db = firestore.AsyncClient(project=project_id)
        self._ttl_days = ttl_days

    async def save_short(self, city_id: str, forecast: KmaShortForecast) -> None:
        await self._set(f"kma_short/{city_id}", {
            "base_date": forecast.base_date,
            "base_time": forecast.base_time,
            "nx": forecast.nx,
            "ny": forecast.ny,
            "hours": [asdict(h) for h in forecast.hours],
        })

    async def save_ultra(self, city_id: str, forecast: KmaUltraShortForecast) -> None:
        await self._set(f"kma_ultra/{city_id}", {
            "base_date": forecast.base_date,
            "base_time": forecast.base_time,
            "nx": forecast.nx,
            "ny": forecast.ny,
            "hours": [asdict(h) for h in forecast.hours],
        })

    async def save_mid_land(self, reg_id: str, forecast: KmaMidLandForecast) -> None:
        await self._set(f"kma_mid_land/{reg_id}", {
            "reg_id": forecast.reg_id,
            "tm_fc": forecast.tm_fc,
            "days": [asdict(d) for d in forecast.days],
        })

    async def save_mid_temp(self, reg_id: str, forecast: KmaMidTempForecast) -> None:
        await self._set(f"kma_mid_temp/{reg_id}", {
            "reg_id": forecast.reg_id,
            "tm_fc": forecast.tm_fc,
            "days": [asdict(d) for d in forecast.days],
        })

    async def save_grid_rain(self, payload: dict) -> None:
        """비구름 지도용 sparse 격자.

        payload = {
            "base_time": "YYYYMMDDHHMM",
            "nx": 149, "ny": 253,
            "hours": [
                {"offset": 1, "tmef": "YYYYMMDDHH",
                 "cells": [{"nx": ..., "ny": ..., "rn1": ...}, ...]},
                ...x6
            ],
        }
        """
        await self._set("kma_grid_rain/latest", payload)

    async def _set(self, path: str, payload: dict) -> None:
        coll, _, doc = path.partition("/")
        ref = self._db.collection(coll).document(doc)
        await ref.set({
            **payload,
            "updated_at": firestore.SERVER_TIMESTAMP,
            "expire_at": datetime.now(timezone.utc) + timedelta(days=self._ttl_days),
        })

    async def close(self) -> None:
        self._db.close()
