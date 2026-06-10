import unittest

from adapters.push_fcm import _build_briefing_message, _interactive_topic_name
from domain.briefing import BriefingType


class PushFcmTest(unittest.TestCase):
    def test_evening_uses_its_own_audio_topic(self) -> None:
        self.assertEqual(
            _interactive_topic_name(
                city="seoul",
                slot=BriefingType.EVENING,
                character_id="jihoon",
            ),
            "briefing-seoul-evening-jihoon-audio-v2",
        )

    def test_audio_url_is_in_data_payload(self) -> None:
        message = _build_briefing_message(
            topic="briefing-seoul-morning-jihoon",
            character_id="jihoon",
            character_display_name="지훈",
            transcript="아가씨, 오늘은 우산을 챙기셔야 합니다.",
            audio_url="https://example.com/jihoon.mp3",
        )

        self.assertIsNone(message.notification)
        self.assertEqual(message.data["kind"], "audio_briefing")
        self.assertEqual(
            message.data["audio_url"],
            "https://example.com/jihoon.mp3",
        )
        self.assertEqual(message.android.priority, "high")
        self.assertEqual(message.apns.payload.aps.category, "audio_briefing")
        self.assertEqual(
            message.apns.payload.custom_data["payload"],
            "https://example.com/jihoon.mp3",
        )


if __name__ == "__main__":
    unittest.main()
