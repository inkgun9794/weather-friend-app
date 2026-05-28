"""레이더/예보 격자 → 컬러 WebP 렌더.

두 입력 지원:
- HSR 레이더 (2305×2881, dBZ×100 int16) → Marshall-Palmer로 mm/hr 변환 후 렌더
- DFS 초단기예보 격자 RN1 (149×253, mm/hr float) → 직접 렌더 (5km, 거침)

WebP는 PNG 대비 약 60% 작아서 GitHub Pages 대역폭 부담 ↓.
"""

from __future__ import annotations

import io

import numpy as np
from PIL import Image

from .kma_radar import (
    HSR_BBOX_EAST,
    HSR_BBOX_NORTH,
    HSR_BBOX_SOUTH,
    HSR_BBOX_WEST,
    HSR_NX,
    HSR_NY,
    NO_ECHO,
    OUT_OF_RANGE,
)

# 출력 해상도 — HSR/RN1 모두 같은 캔버스로 통일해서 클라이언트가 cross-fade할 때
# 두 anchor PNG의 bbox가 동일하게.
_OUT_W = 1024
_OUT_H = 1280
_WEBP_QUALITY = 85

# DFS 5km 격자 (149×253)가 덮는 위경도 영역 — KMA Lambert 역변환 결과.
# RN1은 이 범위 안에서만 데이터가 있고, HSR 캔버스의 더 큰 영역 중 일부에 paste.
RN1_BBOX_SOUTH = 31.6518
RN1_BBOX_WEST = 123.3102
RN1_BBOX_NORTH = 43.3935
RN1_BBOX_EAST = 132.7750

# 클라이언트 _colorFor와 동일 (radar_screen.dart).
_PALETTE: list[tuple[float, tuple[int, int, int]]] = [
    (1.0, (0x67, 0xD4, 0xFF)),
    (5.0, (0x3A, 0x98, 0xFF)),
    (15.0, (0x1B, 0x53, 0xD6)),
    (30.0, (0x81, 0x29, 0xD9)),
]
_PALETTE_TOP = (0xE6, 0x39, 0x60)


def dbz_to_mmhr(dbz: np.ndarray) -> np.ndarray:
    z = np.power(10.0, dbz / 10.0)
    return np.power(z / 200.0, 1.0 / 1.6)


def _mmhr_to_rgba(mmhr: np.ndarray) -> np.ndarray:
    """mm/hr 2D → (h, w, 4) uint8 RGBA. 강수 없는 영역은 alpha=0.

    KMA rain.do와 동일한 임계값 사용 — 0.5 mm/h 미만은 노이즈로 간주.
    """
    h, w = mmhr.shape
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    prev_thresh = 0.5  # noise floor (rain.do 기준과 동일)
    for thresh, (r, g, b) in _PALETTE:
        sel = (mmhr >= prev_thresh) & (mmhr < thresh)
        rgba[sel, 0] = r
        rgba[sel, 1] = g
        rgba[sel, 2] = b
        rgba[sel, 3] = 220
        prev_thresh = thresh
    sel = mmhr >= _PALETTE[-1][0]
    rgba[sel, 0] = _PALETTE_TOP[0]
    rgba[sel, 1] = _PALETTE_TOP[1]
    rgba[sel, 2] = _PALETTE_TOP[2]
    rgba[sel, 3] = 230
    return rgba


def _mmhr_to_image(mmhr: np.ndarray) -> Image.Image:
    """mm/hr 2D (0,0 좌하단) → PIL RGBA Image (PNG/WebP encoder 입력용). Flip 포함."""
    rgba = _mmhr_to_rgba(mmhr)
    rgba = np.flipud(rgba)
    return Image.fromarray(rgba, mode="RGBA")


def _encode_webp(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.save(buf, format="WEBP", quality=_WEBP_QUALITY)
    return buf.getvalue()


def render_radar_webp(values: np.ndarray) -> bytes:
    """HSR 합성 (dBZ×100 int16 2305×2881) → WebP (HSR 전체 bbox 캔버스)."""
    if values.shape != (HSR_NY, HSR_NX):
        raise ValueError(f"unexpected shape {values.shape}, expected ({HSR_NY}, {HSR_NX})")
    dbz = values.astype(np.float32) / 100.0
    missing = (values == OUT_OF_RANGE) | (values == NO_ECHO) | (values < 0)
    mmhr = dbz_to_mmhr(dbz)
    mmhr[missing] = 0.0
    img = _mmhr_to_image(mmhr)
    img = img.resize((_OUT_W, _OUT_H), Image.Resampling.LANCZOS)
    return _encode_webp(img)


def render_rn1_on_hsr_canvas(values: np.ndarray) -> bytes:
    """DFS 초단기예보 격자 RN1 (149×253 at 5km) → HSR bbox 캔버스 WebP.

    7-anchor cross-fade를 위해 모든 anchor PNG가 같은 bbox(=HSR)에서 정렬돼야 함.
    RN1 데이터는 그 안의 sub-rectangle에 paste, 나머지는 투명.
    """
    # 1) RN1 → RGBA (149×253 dimensions)
    mmhr = np.where(values < 0, 0.0, values).astype(np.float32)
    rn1_img = _mmhr_to_image(mmhr)

    # 2) HSR 캔버스 안에서의 RN1 sub-rectangle 위치 계산
    lon_span = HSR_BBOX_EAST - HSR_BBOX_WEST
    lat_span = HSR_BBOX_NORTH - HSR_BBOX_SOUTH
    x_start = round((RN1_BBOX_WEST - HSR_BBOX_WEST) / lon_span * _OUT_W)
    x_end = round((RN1_BBOX_EAST - HSR_BBOX_WEST) / lon_span * _OUT_W)
    # y는 위쪽이 north라 invert.
    y_start = round((HSR_BBOX_NORTH - RN1_BBOX_NORTH) / lat_span * _OUT_H)
    y_end = round((HSR_BBOX_NORTH - RN1_BBOX_SOUTH) / lat_span * _OUT_H)
    x_start = max(0, x_start)
    x_end = min(_OUT_W, x_end)
    y_start = max(0, y_start)
    y_end = min(_OUT_H, y_end)
    sub_w = x_end - x_start
    sub_h = y_end - y_start

    # 3) RN1을 sub-rectangle 크기로 리샘플
    rn1_img = rn1_img.resize((sub_w, sub_h), Image.Resampling.LANCZOS)

    # 4) 투명 HSR 캔버스에 paste
    canvas = Image.new("RGBA", (_OUT_W, _OUT_H), (0, 0, 0, 0))
    canvas.paste(rn1_img, (x_start, y_start), rn1_img)
    return _encode_webp(canvas)
