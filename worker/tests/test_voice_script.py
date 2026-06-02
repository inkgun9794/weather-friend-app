import unittest

from domain.voice_script import normalize_voice_script_for_tts


class VoiceScriptNormalizationTest(unittest.TestCase):
    def test_glues_short_conversational_phrase(self) -> None:
        self.assertEqual(
            normalize_voice_script_for_tts(
                "안녕? 나는 코덱스야. 조금 있다가 봐."
            ),
            "안녕? 나는 코덱스야. 조금있다가봐.",
        )

    def test_glues_weather_auxiliary_phrases(self) -> None:
        self.assertEqual(
            normalize_voice_script_for_tts(
                "오후에 비 올 수 있어. 우산 챙겨 가."
            ),
            "오후에 비 올수있어. 우산 챙겨가.",
        )

    def test_glues_outfit_and_negative_auxiliary_phrases(self) -> None:
        self.assertEqual(
            normalize_voice_script_for_tts(
                "아침엔 쌀쌀해. 따뜻하게 입고 나가고, 무리하지 마."
            ),
            "아침엔 쌀쌀해. 따뜻하게 입고나가고, 무리하지마.",
        )

    def test_does_not_glue_every_korean_word(self) -> None:
        self.assertEqual(
            normalize_voice_script_for_tts("좋은 아침이야. 나는 지영이야."),
            "좋은 아침이야. 나는 지영이야.",
        )


if __name__ == "__main__":
    unittest.main()
