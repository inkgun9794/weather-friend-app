"""KMA 캐시 갱신 유스케이스.

두 종류의 갱신 흐름 (호출량 중복 방지):
- `refresh_short_and_mid(city_ids)` — 단기 + 중기 (base 워크플로, 1시간 주기)
- `refresh_ultra_only(city_ids)`    — 초단기만 (grid 워크플로, 30분 주기)

발표시각 계산도 여기서 (어댑터는 순수 호출만).
"""

from __future__ import annotations

import asyncio
import logging
import zoneinfo
from datetime import datetime, timedelta

from adapters.kma_openapi import (
    fetch_mid_land_forecast,
    fetch_mid_temp_forecast,
    fetch_short_term_forecast,
    fetch_ultra_short_term_forecast,
)
from adapters.store_kma_cache import KmaCacheStore
from domain.locations import CITIES_KMA

log = logging.getLogger(__name__)

KST = zoneinfo.ZoneInfo("Asia/Seoul")

# 단기예보 발표시각 (1일 8회 KST)
_SHORT_ISSUE_HOURS = (2, 5, 8, 11, 14, 17, 20, 23)

# 발표 후 호출 가능까지 버퍼
_SHORT_BUFFER_MIN = 15   # 가이드 +10분 → 안전마진
_MID_BUFFER_MIN = 15
_ULTRA_BUFFER_MIN = 50   # 가이드 +45분 → 안전마진


# ────────────────────────────────────────────────────────────────────────
# 발표시각 계산
# ────────────────────────────────────────────────────────────────────────


def _now_kst() -> datetime:
    return datetime.now(KST)


def latest_short_base(now: datetime | None = None) -> tuple[str, str]:
    """단기예보 가장 최근 발표시각. (base_date, base_time HHMM)."""
    t = (now or _now_kst()) - timedelta(minutes=_SHORT_BUFFER_MIN)
    for h in reversed(_SHORT_ISSUE_HOURS):
        if t.hour >= h:
            return t.strftime("%Y%m%d"), f"{h:02d}00"
    y = t - timedelta(days=1)
    return y.strftime("%Y%m%d"), "2300"


def latest_mid_tm_fc(now: datetime | None = None) -> str:
    """중기예보 가장 최근 발표시각 tmFc=YYYYMMDD0600 또는 1800."""
    t = (now or _now_kst()) - timedelta(minutes=_MID_BUFFER_MIN)
    if t.hour >= 18:
        return t.strftime("%Y%m%d") + "1800"
    if t.hour >= 6:
        return t.strftime("%Y%m%d") + "0600"
    y = t - timedelta(days=1)
    return y.strftime("%Y%m%d") + "1800"


def latest_ultra_base(now: datetime | None = None) -> tuple[str, str]:
    """초단기예보 가장 최근 발표시각. (base_date, base_time HHMM).

    매시 30분 발표, +45분 이후 호출 가능. 안전 버퍼 50분 빼고 직전 30분 슬롯.
    """
    t = (now or _now_kst()) - timedelta(minutes=_ULTRA_BUFFER_MIN)
    # base_time 후보: t보다 작거나 같은 가장 최근의 ":30"
    # 예: t = 14:25 → 13:30, t = 14:35 → 14:30
    if t.minute >= 30:
        base_h = t.hour
    elif t.hour > 0:
        base_h = t.hour - 1
    else:
        base_h = 23
        t = t - timedelta(days=1)
    return t.strftime("%Y%m%d"), f"{base_h:02d}30"


# ────────────────────────────────────────────────────────────────────────
# 유스케이스
# ────────────────────────────────────────────────────────────────────────


async def refresh_short_and_mid(
    city_ids: list[str],
    project_id: str,
) -> None:
    """단기 + 중기 갱신. 초단기는 별도 워크플로(refresh_ultra_only)에서 처리하여
    호출 중복 방지. base 워크플로 (매 1시간) 용도."""
    store = KmaCacheStore(project_id=project_id)
    try:
        await asyncio.gather(
            _refresh_short(city_ids, store),
            _refresh_mid(city_ids, store),
        )
    finally:
        await store.close()


async def refresh_ultra_only(
    city_ids: list[str],
    project_id: str,
) -> None:
    """초단기만 갱신. 10분 워크플로용."""
    store = KmaCacheStore(project_id=project_id)
    try:
        await _refresh_ultra(city_ids, store)
    finally:
        await store.close()


# ────────────────────────────────────────────────────────────────────────
# 내부 — 변수별 갱신 흐름
# ────────────────────────────────────────────────────────────────────────


async def _refresh_short(city_ids: list[str], store: KmaCacheStore) -> None:
    base_date, base_time = latest_short_base()
    log.info("단기예보 갱신 시작 (base=%s %s, cities=%s)", base_date, base_time, city_ids)
    for cid in city_ids:
        city = CITIES_KMA[cid]
        try:
            fc = await fetch_short_term_forecast(
                nx=city.short_nx, ny=city.short_ny,
                base_date=base_date, base_time=base_time,
            )
            await store.save_short(cid, fc)
            log.info("  단기 %s: %d시간 저장", cid, len(fc.hours))
        except Exception as e:
            log.error("  단기 %s 실패: %s", cid, e)


async def _refresh_ultra(city_ids: list[str], store: KmaCacheStore) -> None:
    base_date, base_time = latest_ultra_base()
    log.info("초단기예보 갱신 시작 (base=%s %s, cities=%s)", base_date, base_time, city_ids)
    for cid in city_ids:
        city = CITIES_KMA[cid]
        try:
            fc = await fetch_ultra_short_term_forecast(
                nx=city.short_nx, ny=city.short_ny,
                base_date=base_date, base_time=base_time,
            )
            await store.save_ultra(cid, fc)
            log.info("  초단기 %s: %d시간 저장", cid, len(fc.hours))
        except Exception as e:
            log.error("  초단기 %s 실패: %s", cid, e)


async def _refresh_mid(city_ids: list[str], store: KmaCacheStore) -> None:
    tm_fc = latest_mid_tm_fc()
    # 광역구역은 중복되니 set으로 unique
    land_regs = {CITIES_KMA[c].mid_land_reg_id for c in city_ids}
    temp_regs = {CITIES_KMA[c].mid_temp_reg_id for c in city_ids}
    log.info("중기예보 갱신 시작 (tmFc=%s, land=%s, temp=%s)", tm_fc, land_regs, temp_regs)

    for reg in land_regs:
        try:
            fc = await fetch_mid_land_forecast(reg_id=reg, tm_fc=tm_fc)
            await store.save_mid_land(reg, fc)
            log.info("  중기육상 %s: %d일 저장", reg, len(fc.days))
        except Exception as e:
            log.error("  중기육상 %s 실패: %s", reg, e)

    for reg in temp_regs:
        try:
            fc = await fetch_mid_temp_forecast(reg_id=reg, tm_fc=tm_fc)
            await store.save_mid_temp(reg, fc)
            log.info("  중기기온 %s: %d일 저장", reg, len(fc.days))
        except Exception as e:
            log.error("  중기기온 %s 실패: %s", reg, e)
