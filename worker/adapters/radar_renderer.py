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

from .kma_radar import HSR_NX, HSR_NY, NO_ECHO, OUT_OF_RANGE

# 출력 해상도 — HSR는 디테일 잘 살리고, RN1은 원본이 거치니까 좀 더 작게.
_HSR_OUT = (1024, 1280)
_RN1_OUT = (480, 640)
_WEBP_QUALITY = 85

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
    """mm/hr 2D → (h, w, 4) uint8 RGBA. 강수 없는 영역은 alpha=0."""
    h, w = mmhr.shape
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    prev_thresh = 0.05  # noise floor — 더 작으면 안 보이게
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


def _render_webp(mmhr: np.ndarray, *, output_size: tuple[int, int]) -> bytes:
    """mm/hr 2D (0,0 좌하단) → WebP bytes. Flip + 다운샘플."""
    rgba = _mmhr_to_rgba(mmhr)
    rgba = np.flipud(rgba)
    img = Image.fromarray(rgba, mode="RGBA")
    img = img.resize(output_size, Image.Resampling.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="WEBP", quality=_WEBP_QUALITY)
    return buf.getvalue()


def render_radar_webp(values: np.ndarray) -> bytes:
    """HSR 합성 (dBZ×100 int16 2305×2881) → WebP."""
    if values.shape != (HSR_NY, HSR_NX):
        raise ValueError(f"unexpected shape {values.shape}, expected ({HSR_NY}, {HSR_NX})")
    dbz = values.astype(np.float32) / 100.0
    missing = (values == OUT_OF_RANGE) | (values == NO_ECHO) | (values < 0)
    mmhr = dbz_to_mmhr(dbz)
    mmhr[missing] = 0.0
    return _render_webp(mmhr, output_size=_HSR_OUT)


def render_rn1_webp(values: np.ndarray) -> bytes:
    """DFS 초단기예보 격자 RN1 (mm/hr float 149×253) → WebP.

    RN1은 이미 mm/hr이라 Marshall-Palmer 환산 없음. 거친 5km 격자라 작은 해상도로 렌더.
    """
    # values shape: (ny, nx). 음수(missing)는 0 처리.
    mmhr = np.where(values < 0, 0.0, values).astype(np.float32)
    return _render_webp(mmhr, output_size=_RN1_OUT)
