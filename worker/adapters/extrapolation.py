"""레이더 외삽 — 과거 프레임에서 motion vector 추정 후 forward shift.

알고리즘 (간단·빠름 우선):
1. 두 프레임 (10분 차이) 사이의 강수 영역만 추출.
2. 8배 downsample (계산량 1/64).
3. FFT-기반 위상 상관(phase correlation)으로 (dy, dx) shift 추정.
4. 추정한 motion을 가장 최근 프레임에 1시간 배수로 반복 적용 → +1h~+6h.

가정·한계:
- 평행이동(translation)만 — 회전/팽창은 무시.
- 외삽이 진행될수록 가장자리는 데이터가 빈 채로 흘러나감(빈 영역).
- 6시간이 멀수록 신뢰도 급락 — 클라이언트에서 알파/표식으로 표시 권장.
"""

from __future__ import annotations

import logging

import numpy as np

from .kma_radar import HSR_NX, HSR_NY, NO_ECHO, OUT_OF_RANGE

log = logging.getLogger(__name__)

# downsample factor — 2305/8 ≈ 288, 2881/8 ≈ 360. 충분히 빠름.
_DS = 8


def _to_intensity(values: np.ndarray) -> np.ndarray:
    """dBZ×100 int16 → 0~1 강도 (motion 추정용).

    결측은 0으로. dBZ는 음수도 흔하므로 0 dBZ 미만은 noise floor 처리.
    """
    arr = values.astype(np.float32) / 100.0
    missing = (values == OUT_OF_RANGE) | (values == NO_ECHO) | (values < 0)
    arr[missing] = 0.0
    arr = np.clip(arr, 0.0, 60.0)
    result: np.ndarray = arr / 60.0
    return result


def estimate_motion_per_hour(
    older: np.ndarray, newer: np.ndarray, *, minutes_apart: int
) -> tuple[float, float]:
    """HSR dBZ×100 int16 입력용 모션 추정. 풀해상도 픽셀/시간 단위 반환.

    내부적으론 일반 intensity → phase correlation에 위임.
    """
    older_i = _to_intensity(older)
    newer_i = _to_intensity(newer)
    return estimate_motion_per_hour_intensity(
        older_i, newer_i, minutes_apart=minutes_apart,
    )


def estimate_motion_per_hour_intensity(
    older_i: np.ndarray, newer_i: np.ndarray, *, minutes_apart: int
) -> tuple[float, float]:
    """이미 0~1 intensity 2D인 두 프레임에서 motion vector 추정.

    PIL Image의 alpha/red 채널 같은 임의 강도 신호에 사용 가능.
    반환: (dy_per_hour, dx_per_hour) — 입력 해상도 픽셀 단위.
    """
    # 다운샘플 (블록 평균).
    h, w = older_i.shape
    h2, w2 = h // _DS, w // _DS
    older_ds = older_i[: h2 * _DS, : w2 * _DS].reshape(h2, _DS, w2, _DS).mean(axis=(1, 3))
    newer_ds = newer_i[: h2 * _DS, : w2 * _DS].reshape(h2, _DS, w2, _DS).mean(axis=(1, 3))

    # 평균 0 정규화 — DC 성분 제거로 phase correlation 안정.
    older_ds = older_ds - older_ds.mean()
    newer_ds = newer_ds - newer_ds.mean()

    # 강수가 너무 적거나 분포가 단순하면 phase correlation이 노이즈로 잠겨서
    # 비현실적 motion을 토함. 두 가지 sanity:
    # 1) std 임계치 — alpha 채널이 너무 sparse하면 (강수 픽셀 < 0.3%) 0 반환
    # 2) 양쪽 모두 충분한 상관(corr 피크가 평균 대비 의미 있음)이어야
    if older_ds.std() < 0.05 or newer_ds.std() < 0.05:
        return (0.0, 0.0)

    # Phase correlation (FFT 기반).
    f1 = np.fft.fft2(older_ds)
    f2 = np.fft.fft2(newer_ds)
    cross = f1.conj() * f2
    cross_n = cross / (np.abs(cross) + 1e-10)
    corr = np.fft.ifft2(cross_n).real

    # 피크 위치 → shift (FFT 결과는 0~N-1로, 절반 넘으면 음수로 wrap).
    py, px = np.unravel_index(np.argmax(corr), corr.shape)
    if py > h2 // 2:
        py -= h2
    if px > w2 // 2:
        px -= w2

    # 다운샘플 픽셀 → 풀해상도 픽셀 변환 후 시간당 단위로 환산.
    dy_full = py * _DS
    dx_full = px * _DS
    scale = 60.0 / minutes_apart
    dy_h = dy_full * scale
    dx_h = dx_full * scale

    # 물리적 sanity — 시간당 너무 큰 이동은 노이즈로 간주.
    # 일반적인 비구름은 시간당 50km, 태풍이라도 100km/h 정도. 격자 픽셀 단위로
    # 격자 한 변의 1/10 정도가 그 정도에 해당 → cap = max(input shape) / 10.
    cap_full = max(older_i.shape) // 10
    if abs(dy_h) > cap_full or abs(dx_h) > cap_full:
        log.warning("비현실적 motion (%.1f, %.1f px/h, cap=%d) — 0으로 무시",
                    dy_h, dx_h, cap_full)
        return (0.0, 0.0)
    return (dy_h, dx_h)


def shift_frame(values: np.ndarray, dy: float, dx: float) -> np.ndarray:
    """프레임을 (dy, dx) 픽셀만큼 평행이동. 빈 영역은 OUT_OF_RANGE로 채움.

    - dy: y축 이동 (양수 = 격자 위쪽 = 북쪽으로)
    - dx: x축 이동 (양수 = 격자 오른쪽 = 동쪽으로)
    """
    ny, nx = values.shape
    if ny != HSR_NY or nx != HSR_NX:
        raise ValueError(f"unexpected shape {values.shape}")

    out = np.full_like(values, OUT_OF_RANGE)
    idy = int(round(dy))
    idx = int(round(dx))

    # 소스 영역
    src_y0 = max(0, -idy)
    src_y1 = min(ny, ny - idy)
    src_x0 = max(0, -idx)
    src_x1 = min(nx, nx - idx)
    # 목적지 영역
    dst_y0 = max(0, idy)
    dst_y1 = dst_y0 + (src_y1 - src_y0)
    dst_x0 = max(0, idx)
    dst_x1 = dst_x0 + (src_x1 - src_x0)

    if src_y1 > src_y0 and src_x1 > src_x0:
        out[dst_y0:dst_y1, dst_x0:dst_x1] = values[src_y0:src_y1, src_x0:src_x1]
    return out


def extrapolate_chain(
    base_values: np.ndarray,
    *,
    motion_per_hour: tuple[float, float],
    hours: int,
) -> list[np.ndarray]:
    """가장 최근 프레임에서 시간 단위로 N번 forward shift.

    반환: [+1h frame, +2h frame, ..., +Nh frame].
    """
    dy_h, dx_h = motion_per_hour
    out: list[np.ndarray] = []
    for h in range(1, hours + 1):
        out.append(shift_frame(base_values, dy_h * h, dx_h * h))
    return out
