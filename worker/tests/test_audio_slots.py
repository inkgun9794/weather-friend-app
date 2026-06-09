import os
import unittest
from unittest.mock import patch

from adapters.tts_typecast import TypecastClient
from domain.briefing import SEMANTIC_INSTRUCTIONS, BriefingType, is_audio_slot
from usecases.generate_briefing import _typecast_api_key_env_for_hour


class AudioSlotPolicyTest(unittest.TestCase):
    def test_morning_and_evening_are_audio_slots(self) -> None:
        self.assertTrue(is_audio_slot(6))
        self.assertTrue(is_audio_slot(21))
        self.assertFalse(is_audio_slot(11))

    def test_each_audio_slot_uses_its_own_key(self) -> None:
        self.assertEqual(_typecast_api_key_env_for_hour(6), "TYPECAST_API_KEY")
        self.assertEqual(_typecast_api_key_env_for_hour(21), "TYPECAST_API_KEY_B")

    def test_evening_prompt_requests_separate_voice_script(self) -> None:
        prompt = SEMANTIC_INSTRUCTIONS[BriefingType.EVENING]

        self.assertIn("[메시지]", prompt)
        self.assertIn("[음성]", prompt)


class TypecastClientKeySelectionTest(unittest.TestCase):
    def test_resolves_configured_environment_variable(self) -> None:
        with patch.dict(
            os.environ,
            {
                "TYPECAST_API_KEY": "morning-key",
                "TYPECAST_API_KEY_B": "evening-key",
            },
            clear=True,
        ):
            morning = TypecastClient(api_key_env="TYPECAST_API_KEY")
            evening = TypecastClient(api_key_env="TYPECAST_API_KEY_B")

            self.assertEqual(morning._resolve_api_key(), "morning-key")
            self.assertEqual(evening._resolve_api_key(), "evening-key")

    def test_missing_evening_key_does_not_fall_back_to_morning(self) -> None:
        with patch.dict(
            os.environ,
            {"TYPECAST_API_KEY": "morning-key"},
            clear=True,
        ):
            evening = TypecastClient(api_key_env="TYPECAST_API_KEY_B")

            with self.assertRaisesRegex(RuntimeError, "TYPECAST_API_KEY_B"):
                evening._resolve_api_key()


if __name__ == "__main__":
    unittest.main()
