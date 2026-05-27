"""레이더 dBZ 격자 → 컬러 PNG 렌더.

KMA HSR 합성장 (2305×2881, dBZ×100 int16) 을 모바일 친화 해상도 PNG로 변환.
- 다운샘플링 (anti-alias)
- Marshall-Palmer (Z=200 R^1.6) 로 dBZ → mm/hr
- 클라이언트 _colorFor와 동일한 5단계 팔레트
- 강수 없는 영역은 완전 투명 (지도 보이게)
"""

from __future__ import annotations

import io

import numpy as np
from PIL import Image

from .kma_radar import HSR_NX, HSR_NY, NO_ECHO, OUT_OF_RANGE

# 출력 해상도 — 원본 2305×2881의 약 1/2.25. 모바일 화질·전송량 균형.
OUT_W = 1024
OUT_H = 1280

# 클라이언트 _colorFor와 동일 (radar_screen.dart 263-267).
# 임계값은 mm/hr.
_PALETTE: list[tuple[float, tuple[int, int, int]]] = [
    (1.0, (0x67, 0xD4, 0xFF)),   # 약
    (5.0, (0x3A, 0x98, 0xFF)),   # 보통
    (15.0, (0x1B, 0x53, 0xD6)),  # 강
    (30.0, (0x81, 0x29, 0xD9)),  # 매우 강
]
_PALETTE_TOP = (0xE6, 0x39, 0x60)  # 폭우 (>= 30 mm/hr 이후 한 단계 위)


def dbz_to_mmhr(dbz: np.ndarray) -> np.ndarray:
    """Marshall-Palmer 환산: R = (10^(dBZ/10) / 200)^(1/1.6).

    음수/0 dBZ는 거의 0 mm/hr가 되도록 자연 처리됨.
    """
    z = np.power(10.0, dbz / 10.0)
    return np.power(z / 200.0, 1.0 / 1.6)


def render_dbz_png(values: np.ndarray) -> bytes:
    """dBZ×100 int16 (ny, nx) → RGBA PNG bytes.

    - 좌하단(0,0) 시작이므로 vertical flip 적용 (이미지는 좌상단 시작).
    - 결측·관측외는 alpha=0.
    """
    if values.shape != (HSR_NY, HSR_NX):
        raise ValueError(f"unexpected shape {values.shape}, expected ({HSR_NY}, {HSR_NX})")

    # 1) 결측 마스킹 + dBZ 환산
    dbz = values.astype(np.float32) / 100.0
    missing = (values == OUT_OF_RANGE) | (values == NO_ECHO) | (values < 0)
    mmhr = dbz_to_mmhr(dbz)
    mmhr[missing] = 0.0

    # 2) 컬러맵 적용 — RGBA 직접 채움.
    rgba = np.zeros((HSR_NY, HSR_NX, 4), dtype=np.uint8)

    prev_thresh = 0.0
    for thresh, (r, g, b) in _PALETTE:
        sel = (mmhr >= prev_thresh) & (mmhr < thresh) & (mmhr > 0.05)
        rgba[sel, 0] = r
        rgba[sel, 1] = g
        rgba[sel, 2] = b
        rgba[sel, 3] = 220  # ~86% — 지도 살짝 비침
        prev_thresh = thresh
    # 최상위 구간
    sel = mmhr >= _PALETTE[-1][0]
    rgba[sel, 0] = _PALETTE_TOP[0]
    rgba[sel, 1] = _PALETTE_TOP[1]
    rgba[sel, 2] = _PALETTE_TOP[2]
    rgba[sel, 3] = 230

    # 3) 좌하단 기준 → 이미지(좌상단 기준)로 flip.
    rgba = np.flipud(rgba)

    # 4) 다운샘플링 (LANCZOS) → PNG.
    img = Image.fromarray(rgba, mode="RGBA")
    img = img.resize((OUT_W, OUT_H), Image.Resampling.LANCZOS)

    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    return buf.getvalue()
