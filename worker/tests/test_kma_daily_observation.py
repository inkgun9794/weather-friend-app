from __future__ import annotations

import asyncio

from adapters import kma_openapi
from domain.locations import CITIES_KMA


def test_fetch_asos_daily_observation_parses_min_and_max(monkeypatch) -> None:
    captured: dict = {}

    async def fake_get_json(url: str, params: dict) -> dict:
        captured["url"] = url
        captured["params"] = params
        return {
            "response": {
                "header": {"resultCode": "00"},
                "body": {
                    "items": {
                        "item": [
                            {
                                "tm": "2026-06-11",
                                "stnId": "108",
                                "minTa": "18.4",
                                "maxTa": "27.6",
                            }
                        ]
                    }
                },
            }
        }

    monkeypatch.setattr(kma_openapi, "_get_json", fake_get_json)
    monkeypatch.setattr(kma_openapi, "_service_key", lambda: "test-key")

    result = asyncio.run(
        kma_openapi.fetch_asos_daily_observation(
            stn_id="108",
            date="20260611",
        )
    )

    assert result.date == "2026-06-11"
    assert result.stn_id == "108"
    assert result.min_ta == 18.4
    assert result.max_ta == 27.6
    assert captured["url"].endswith("/AsosDalyInfoService/getWthrDataList")
    assert captured["params"]["dataCd"] == "ASOS"
    assert captured["params"]["dateCd"] == "DAY"
    assert captured["params"]["startDt"] == "20260611"
    assert captured["params"]["endDt"] == "20260611"


def test_every_city_has_an_asos_station() -> None:
    station_ids = {city.asos_stn_id for city in CITIES_KMA.values()}

    assert len(station_ids) == 18
