import unittest

from adapters.ai_gemini import _style_rules_for
from domain.briefing import BUTLER_VOICE_RULES, WEATHERCASTER_VOICE_RULES
from domain.character import JIHOON, JIYOUNG, SOHEE
from synth_intros import _api_key_env_for_character


class CharacterStyleTest(unittest.TestCase):
    def test_sohee_uses_weathercaster_voice_and_formal_style(self) -> None:
        self.assertEqual(
            SOHEE.voice_actor_id,
            "tc_62849ce44b8771d984838066",
        )
        self.assertTrue(SOHEE.is_weathercaster)
        self.assertIn("존댓말", SOHEE.persona_prompt)
        self.assertEqual(_style_rules_for(SOHEE), WEATHERCASTER_VOICE_RULES)
        self.assertEqual(
            _api_key_env_for_character(SOHEE.id),
            "TYPECAST_API_KEY_B",
        )

    def test_other_characters_keep_friend_style(self) -> None:
        self.assertFalse(JIYOUNG.is_weathercaster)
        self.assertNotEqual(_style_rules_for(JIYOUNG), WEATHERCASTER_VOICE_RULES)

    def test_jihoon_uses_butler_voice_and_formal_style(self) -> None:
        self.assertTrue(JIHOON.is_butler)
        self.assertIn("가명은 '흑표범'", JIHOON.persona_prompt)
        self.assertIn('"아가씨"', JIHOON.persona_prompt)
        self.assertEqual(_style_rules_for(JIHOON), BUTLER_VOICE_RULES)


if __name__ == "__main__":
    unittest.main()
