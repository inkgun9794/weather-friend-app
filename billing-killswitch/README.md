# Billing Killswitch

GCP Budget 초과 시 자동으로 billing을 분리하는 Cloud Function.

## 동작 흐름

```
청구 누적 → Budget 임계값 도달
  ↓
Pub/Sub 토픽으로 메시지 발행
  ↓
이 Cloud Function이 트리거됨
  ↓
Billing API 호출 → 프로젝트의 billing account 분리
  ↓
모든 결제 API 즉시 중단 → 추가 청구 0
```

## 보호 대상

`weather-friend-genius` 프로젝트 (Gemini API billing 활성화된 곳)

## 배포

`deploy.sh` 참고.
