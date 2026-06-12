"""KMA 캐시 Firestore 쓰기 어댑터.

컬렉션 레이아웃:
- `kma_short/{city_id}`     — 단기예보 (3시간 갱신)
- `kma_ultra/{city_id}`     — 초단기예보 카드용 (10분 갱신)
- `kma_mid_land/{reg_id}`   — 중기육상 (6시간 갱신)
- `kma_mid_temp/{reg_id}`   — 중기기온 (6시간 갱신)
- `kma_observation/{stn_id}` — ASOS 전일 관측 최저·최고
- `kma_radar/latest`              — 레이더 manifest (bbox + frame 메타)
- `kma_radar/latest/frames/{slot}` — 프레임별 PNG bytes (덮어쓰기)

레이더 PNG는 Firestore subcollection에 1MB 한도 안에서 직접 저장(Spark 플랜 호환).

문서마다 `updated_at` 서버 타임스탬프를 함께 저장 → 클라이언트는 stale 판단에 사용.
"""

from __future__ import annotations

from dataclasses import asdict
from datetime import datetime, timedelta, timezone

from google.cloud import firestore

from adapters.kma_openapi import (
    KmaDailyObservation,
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

    async def save_observation(self, observation: KmaDailyObservation) -> None:
        await self._set(f"kma_observation/{observation.stn_id}", {
            "date": observation.date,
            "stn_id": observation.stn_id,
            "min_c": observation.min_ta,
            "max_c": observation.max_ta,
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

    async def save_radar_manifest(self, payload: dict) -> None:
        """레이더 메타데이터 doc. PNG 자체는 GitHub Pages에서 서빙하므로
        manifest에는 슬롯 메타와 URL만. 클라는 이 doc 1개만 읽으면 끝.

        payload = {
            "base_tm": "202605271500",
            "bounds": {"south": .., "west": .., "north": .., "east": ..},
            "motion_per_hour_deg": {"dlat": .., "dlon": ..},
            "frames": [
                {"slot": "past", "kind": "obs", "tm": "...", "offset_min": -60,
                 "url": "https://.../radar/past.png?v=..."},
                ...
            ]
        }
        """
        await self._set("kma_radar/latest", payload)

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
