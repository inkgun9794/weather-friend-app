"""비 블록 판단 테스트 — 강수'확률'이 아니라 실제 강수량(mm) 기준이어야 함.

회귀 방지: 흐린 날 강수량 0mm인데 확률만 60~80%인 경우(2026-06-08 실제 케이스)
비 블록이 안 잡혀야 한다.
"""

import unittest

from adapters.weather_open_meteo import _rain_blocks_from
from domain.briefing import WeatherSnapshot


def _snap(hour: int, prob: int, mm: float) -> WeatherSnapshot:
    return WeatherSnapshot(
        hour=hour,
        temperature_c=20.0,
        feels_like_c=20.0,
        condition="흐림",
        precipitation_prob=prob,
        precipitation_mm=mm,
        wind_speed_kmh=5.0,
        humidity=70,
    )


class RainBlockTest(unittest.TestCase):
    def test_high_prob_zero_mm_is_not_rain(self) -> None:
        # 2026-06-08 케이스: 확률 57~78%인데 실제 강수량 0mm → 비 블록 없어야 함.
        snaps = [_snap(h, prob=70, mm=0.0) for h in range(6, 14)]
        self.assertEqual(_rain_blocks_from(snaps), ())

    def test_actual_rain_makes_block(self) -> None:
        # 실제 강수량 있는 시간(10,11)만 한 블록으로 묶임.
        snaps = [
            _snap(9, 50, 0.0),
            _snap(10, 80, 1.2),
            _snap(11, 80, 0.8),
            _snap(12, 30, 0.0),
        ]
        blocks = _rain_blocks_from(snaps)
        self.assertEqual(len(blocks), 1)
        self.assertEqual((blocks[0].start_hour, blocks[0].end_hour), (10, 11))

    def test_trace_below_threshold_is_not_rain(self) -> None:
        # 0.1mm 미만 미량은 비로 안 침.
        snaps = [_snap(10, 90, 0.0), _snap(11, 90, 0.05)]
        self.assertEqual(_rain_blocks_from(snaps), ())


if __name__ == "__main__":
    unittest.main()
