"""KMA 캐시 갱신 유스케이스.

두 종류의 갱신 흐름 (호출량 중복 방지):
- `refresh_short_and_mid(city_ids)` — 단기 + 중기 (base 워크플로, 1시간 주기)
- `refresh_ultra_only(city_ids)`    — 초단기만 (grid 워크플로, 30분 주기)

발표시각 계산도 여기서 (어댑터는 순수 호출만).
"""

from __future__ import annotations

import asyncio
import logging
import pathlib
import zoneinfo
from datetime import datetime, timedelta

import numpy as np

from adapters.extrapolation import estimate_motion_per_hour
from adapters.kma_apihub import NX as GRID_NX
from adapters.kma_apihub import NY as GRID_NY
from adapters.kma_apihub import fetch_vsrt_grid
from adapters.kma_openapi import (
    KmaShortForecast,
    KmaShortHour,
    fetch_mid_land_forecast,
    fetch_mid_temp_forecast,
    fetch_short_term_forecast,
    fetch_ultra_short_term_forecast,
)
from adapters.kma_radar import (
    HSR_BBOX_EAST,
    HSR_BBOX_NORTH,
    HSR_BBOX_SOUTH,
    HSR_BBOX_WEST,
    HSR_NX,
    HSR_NY,
    RadarFrame,
    fetch_radar_hsr,
)
from adapters.radar_renderer import render_dbz_png
from adapters.store_kma_cache import KmaCacheStore
from domain.locations import CITIES_KMA

log = logging.getLogger(__name__)

KST = zoneinfo.ZoneInfo("Asia/Seoul")

# 도시별 호출 동시 실행 한도. KMA API TPS 30 한도 안전선 + 응답 안정성 우선.
# 184개 도시 × ~2초/호출이 순차로 6분 → 병렬 10개로 1분 안에 마무리.
_CITY_CONCURRENCY = 10

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


def yesterday_last_short_base(now: datetime | None = None) -> tuple[str, str]:
    """어제 23시 발표 — 오늘 0시부터의 데이터 커버용.
    23시 발표는 그글피 자정까지 제공이라 오늘 새벽~다음다음날까지 커버.
    """
    t = (now or _now_kst()) - timedelta(days=1)
    return t.strftime("%Y%m%d"), "2300"


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


def latest_grid_tmfc(now: datetime | None = None) -> str:
    """초단기예보 격자 가장 최근 발표시각 tmfc=YYYYMMDDHHMM (10분 단위).

    매 10분 발표. 안전 버퍼 15분 빼고 10분 단위로 내림.
    """
    t = (now or _now_kst()) - timedelta(minutes=15)
    minute = (t.minute // 10) * 10
    return t.strftime("%Y%m%d%H") + f"{minute:02d}"


def grid_tmef(tmfc: str, offset_hours: int) -> str:
    """tmfc(YYYYMMDDHHMM) + offset → tmef(YYYYMMDDHH)."""
    base = datetime.strptime(tmfc, "%Y%m%d%H%M")
    target = base + timedelta(hours=offset_hours)
    return target.strftime("%Y%m%d%H")


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
    *,
    docs_root: str = "_docs",
    pages_base_url: str = "https://inkgun9794.github.io/weather-friend-app",
) -> None:
    """초단기만 갱신. grid 워크플로용 (30분 주기).

    - 도시별 카드용 초단기 (`getUltraSrtFcst`)
    - 비구름 지도용 한반도 격자 (`nph-dfs_vsrt_grd`, RN1) — 도시 무관 1회.
    - 레이더 PNG (과거 1 + 현재 1 = 2장) — `docs_root/radar/`에 저장 후 GitHub Pages 서빙.
    """
    store = KmaCacheStore(project_id=project_id)
    try:
        await asyncio.gather(
            _refresh_ultra(city_ids, store),
            _refresh_grid_rain(store),
            _refresh_radar_frames(store, docs_root=docs_root, pages_base_url=pages_base_url),
        )
    finally:
        await store.close()


# ────────────────────────────────────────────────────────────────────────
# 내부 — 변수별 갱신 흐름
# ────────────────────────────────────────────────────────────────────────


async def _refresh_short(city_ids: list[str], store: KmaCacheStore) -> None:
    # 두 발표를 받아 merge — 새벽 시간 데이터 누락 방지.
    # - earlier(어제 23시): 오늘 0시부터의 과거~새벽 시간 커버
    # - recent(가장 최근): 가장 신선한 미래 예보
    # 같은 시각은 recent 우선 (더 최신).
    recent_date, recent_time = latest_short_base()
    earlier_date, earlier_time = yesterday_last_short_base()
    same_base = (recent_date, recent_time) == (earlier_date, earlier_time)
    log.info(
        "단기예보 갱신 시작 (recent=%s %s, earlier=%s %s, same=%s, cities=%d)",
        recent_date, recent_time, earlier_date, earlier_time, same_base, len(city_ids),
    )

    sem = asyncio.Semaphore(_CITY_CONCURRENCY)

    async def _one(cid: str) -> None:
        async with sem:
            city = CITIES_KMA[cid]
            try:
                recent = await fetch_short_term_forecast(
                    nx=city.short_nx, ny=city.short_ny,
                    base_date=recent_date, base_time=recent_time,
                )
                if same_base:
                    merged = recent
                else:
                    earlier = await fetch_short_term_forecast(
                        nx=city.short_nx, ny=city.short_ny,
                        base_date=earlier_date, base_time=earlier_time,
                    )
                    merged = _merge_short(earlier, recent)
                await store.save_short(cid, merged)
                log.info("  단기 %s: %d시간 저장", cid, len(merged.hours))
            except Exception as e:
                log.error("  단기 %s 실패: %s", cid, e)

    await asyncio.gather(*(_one(cid) for cid in city_ids))


def _merge_short(
    earlier: KmaShortForecast, recent: KmaShortForecast,
) -> KmaShortForecast:
    """두 단기예보를 (fcst_date, fcst_time) 기준 merge. 같은 시각은 recent 우선."""
    by_time: dict[tuple[str, str], KmaShortHour] = {}
    for h in earlier.hours:
        by_time[(h.fcst_date, h.fcst_time)] = h
    for h in recent.hours:  # 더 최신 발표 — 같은 시각 덮어쓰기
        by_time[(h.fcst_date, h.fcst_time)] = h
    sorted_hours = tuple(
        sorted(by_time.values(), key=lambda h: (h.fcst_date, h.fcst_time))
    )
    return KmaShortForecast(
        base_date=recent.base_date,
        base_time=recent.base_time,
        nx=recent.nx,
        ny=recent.ny,
        hours=sorted_hours,
    )


async def _refresh_ultra(city_ids: list[str], store: KmaCacheStore) -> None:
    base_date, base_time = latest_ultra_base()
    log.info(
        "초단기예보 갱신 시작 (base=%s %s, cities=%d)",
        base_date, base_time, len(city_ids),
    )

    sem = asyncio.Semaphore(_CITY_CONCURRENCY)

    async def _one(cid: str) -> None:
        async with sem:
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

    await asyncio.gather(*(_one(cid) for cid in city_ids))


async def _refresh_grid_rain(store: KmaCacheStore) -> None:
    """비구름 지도용 한반도 RN1 격자 1~6시간 fetch + sparse 저장.

    - 한 번 호출에 37,697 격자값 (실수). 도시 무관 1회 fetch만 필요.
    - 강수 있는 셀만 (rn1 > 0) 추출해서 sparse JSON으로 저장.
      비 안 오는 날: cells ≈ 0개. 비 오는 날에도 한반도 일부만 → 1MB 안전.
    """
    tmfc = latest_grid_tmfc()
    log.info("비구름 격자 갱신 시작 (tmfc=%s)", tmfc)
    hours_payload: list[dict] = []
    for offset in range(1, 7):
        tmef = grid_tmef(tmfc, offset)
        try:
            grid = await fetch_vsrt_grid(var="RN1", tmfc=tmfc, tmef=tmef)
            cells: list[dict] = []
            for ny in range(1, GRID_NY + 1):
                for nx in range(1, GRID_NX + 1):
                    v = grid.at(nx, ny)
                    if v is not None and v > 0:
                        cells.append({"nx": nx, "ny": ny, "rn1": round(v, 2)})
            hours_payload.append({"offset": offset, "tmef": tmef, "cells": cells})
            log.info("  +%dh (%s): %d개 강수 셀", offset, tmef, len(cells))
        except Exception as e:
            log.error("  +%dh 실패: %s", offset, e)

    if not hours_payload:
        log.warning("비구름 격자: 모든 시간 실패 → 저장 스킵")
        return

    await store.save_grid_rain({
        "base_time": tmfc,
        "nx": GRID_NX,
        "ny": GRID_NY,
        "hours": hours_payload,
    })
    total_cells = sum(len(h["cells"]) for h in hours_payload)
    log.info("비구름 격자 저장 완료 — 총 %d 셀 (6시간)", total_cells)


# 레이더 합성영상은 매시 :00, :05, :10, ..., :55 (5분 단위 native).
# 최신 슬롯은 보통 +5~7분 지나야 사이트에 올라옴 → 안전 10분 버퍼.
_RADAR_BUFFER_MIN = 10


def latest_radar_tm(now: datetime | None = None) -> str:
    """레이더 합성 가장 최근 가용 시각 — KST, 5분 내림. YYYYMMDDHHmm."""
    t = (now or _now_kst()) - timedelta(minutes=_RADAR_BUFFER_MIN)
    minute = (t.minute // 5) * 5
    return t.strftime("%Y%m%d%H") + f"{minute:02d}"


def _shift_tm(tm: str, minutes: int) -> str:
    """tm(YYYYMMDDHHmm) + minutes → 같은 포맷."""
    t = datetime.strptime(tm, "%Y%m%d%H%M") + timedelta(minutes=minutes)
    return t.strftime("%Y%m%d%H%M")


async def _refresh_radar_frames(
    store: KmaCacheStore,
    *,
    docs_root: str,
    pages_base_url: str,
) -> None:
    """1시간 전 1장(실측) + 현재 1장(외삽 base) = 2 PNG.

    PNG는 `{docs_root}/radar/{slot}.png` 파일로 저장 → 워크플로가 commit/push →
    GitHub Pages가 서빙. 클라이언트는 manifest의 url(NetworkImage)로 fetch.

    미래 36장은 클라이언트가 `current` PNG의 bounds를 motion vector만큼 shift해
    시각화 — 서버는 렌더 안 함.
    """
    current_tm = latest_radar_tm()
    prev_tm = _shift_tm(current_tm, -10)   # motion 추정용
    past_tm = _shift_tm(current_tm, -60)   # 슬라이더 -60m 슬롯
    log.info(
        "레이더 갱신 시작 — current=%s, prev=%s, past=%s, docs=%s",
        current_tm, prev_tm, past_tm, docs_root,
    )

    # 1) 세 시각 병렬 fetch.
    fetch_tms = [past_tm, prev_tm, current_tm]
    results = await asyncio.gather(
        *(fetch_radar_hsr(tm) for tm in fetch_tms),
        return_exceptions=True,
    )
    frames: list[RadarFrame | None] = []
    for tm, res in zip(fetch_tms, results, strict=True):
        if isinstance(res, RadarFrame):
            frames.append(res)
        else:
            log.error("레이더 fetch 실패 (%s): %s", tm, res)
            frames.append(None)
    past_frame, prev_frame, current_frame = frames

    if current_frame is None:
        log.error("현재 레이더 프레임 누락 — 저장 스킵")
        return

    # 2) Motion vector — prev → current (10분 차) → px/h.
    motion_per_hour_px: tuple[float, float] = (0.0, 0.0)
    if prev_frame is not None:
        motion_per_hour_px = estimate_motion_per_hour(
            prev_frame.values,
            current_frame.values,
            minutes_apart=10,
        )
    log.info("motion (px/h) = (dy=%.1f, dx=%.1f)", *motion_per_hour_px)

    # 3) px/h → deg/h.
    deg_per_px_lon = (HSR_BBOX_EAST - HSR_BBOX_WEST) / HSR_NX
    deg_per_px_lat = (HSR_BBOX_NORTH - HSR_BBOX_SOUTH) / HSR_NY
    motion_per_hour_deg = {
        "dlat": motion_per_hour_px[0] * deg_per_px_lat,
        "dlon": motion_per_hour_px[1] * deg_per_px_lon,
    }

    # 4) PNG 렌더 + 파일 저장.
    def _render(values: np.ndarray) -> bytes:
        return render_dbz_png(values)

    radar_dir = pathlib.Path(docs_root) / "radar"
    radar_dir.mkdir(parents=True, exist_ok=True)

    saved_slots: set[str] = set()
    if past_frame is not None:
        png = await asyncio.to_thread(_render, past_frame.values)
        (radar_dir / "past.png").write_bytes(png)
        saved_slots.add("past")
    current_png = await asyncio.to_thread(_render, current_frame.values)
    (radar_dir / "current.png").write_bytes(current_png)
    saved_slots.add("current")
    log.info("PNG 파일 저장 완료 — %s, slots=%s", radar_dir, sorted(saved_slots))

    # 5) Manifest — 37 슬라이더 + GitHub Pages URL (cache-bust 위해 ?v= 붙임).
    offsets = [-60, *range(10, 361, 10)]
    frame_entries: list[dict] = []
    for off in offsets:
        slot = "past" if off == -60 else "current"
        if slot not in saved_slots:
            continue
        frame_entries.append({
            "slot": slot,
            "kind": "obs" if off <= 0 else "fcst",
            "tm": _shift_tm(current_tm, off),
            "offset_min": off,
            "url": f"{pages_base_url}/radar/{slot}.png?v={current_tm}",
        })
    await store.save_radar_manifest({
        "base_tm": current_tm,
        "motion_per_hour_px": {
            "dy": motion_per_hour_px[0], "dx": motion_per_hour_px[1],
        },
        "motion_per_hour_deg": motion_per_hour_deg,
        "bounds": {
            "south": HSR_BBOX_SOUTH,
            "west": HSR_BBOX_WEST,
            "north": HSR_BBOX_NORTH,
            "east": HSR_BBOX_EAST,
        },
        "frames": frame_entries,
    })
    log.info(
        "레이더 manifest 저장 완료 — %d/%d 슬라이더, motion_deg=%s",
        len(frame_entries), len(offsets), motion_per_hour_deg,
    )


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
