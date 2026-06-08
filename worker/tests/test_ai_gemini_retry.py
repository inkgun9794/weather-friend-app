"""ai_gemini의 에러 재시도 분류 테스트.

retry storm 재발 방지의 핵심: 429(일일 quota 소진 / 선불 고갈)는 *재시도 대상이
아니어야* 한다. 진짜 일시적 에러(5xx/timeout)만 재시도한다.
"""

import unittest

from adapters.ai_gemini import _is_quota_exhausted, _is_retryable

# 실제 GitHub Actions 로그에서 가져온 429 메시지들
DAILY_QUOTA_429 = (
    "429 RESOURCE_EXHAUSTED. {'error': {'code': 429, 'message': 'You exceeded "
    "your current quota. Quota exceeded for metric: generativelanguage."
    "googleapis.com/generate_requests_per_model_per_day, limit: 50, model: "
    "gemini-3.1-flash-lite'}}"
)
PREPAY_DEPLETED_429 = (
    "429 RESOURCE_EXHAUSTED. {'error': {'code': 429, 'message': 'Your "
    "prepayment credits are depleted. Please go to AI Studio...'}}"
)


class RetryableClassificationTest(unittest.TestCase):
    def test_429_is_not_retryable(self) -> None:
        # 핵심 회귀 방지: 429를 재시도하면 한정된 일일 요청 quota를 더 태운다.
        self.assertFalse(_is_retryable(Exception(DAILY_QUOTA_429)))
        self.assertFalse(_is_retryable(Exception(PREPAY_DEPLETED_429)))

    def test_5xx_and_timeout_still_retryable(self) -> None:
        for msg in ("503 UNAVAILABLE", "500 INTERNAL", "502", "504",
                    "DEADLINE_EXCEEDED", "request timeout"):
            self.assertTrue(_is_retryable(Exception(msg)), msg)


class QuotaExhaustedClassificationTest(unittest.TestCase):
    """폴백 트리거: 429(일일 quota/선불 고갈)는 quota 소진으로 분류돼야 다음 모델로 넘어감."""

    def test_429_is_quota_exhausted(self) -> None:
        self.assertTrue(_is_quota_exhausted(Exception(DAILY_QUOTA_429)))
        self.assertTrue(_is_quota_exhausted(Exception(PREPAY_DEPLETED_429)))

    def test_transient_is_not_quota_exhausted(self) -> None:
        for msg in ("503 UNAVAILABLE", "500 INTERNAL", "request timeout"):
            self.assertFalse(_is_quota_exhausted(Exception(msg)), msg)


if __name__ == "__main__":
    unittest.main()
