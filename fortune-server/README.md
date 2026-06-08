# Fortune server

Cloud Run의 `weather-friend-llm` 서비스 소스입니다.

## Local verification

```bash
npm install
npm test
```

## Deploy

```bash
gcloud run deploy weather-friend-llm \
  --source . \
  --project weather-friend-genius \
  --region asia-northeast3 \
  --allow-unauthenticated
```

`GEMINI_API_KEY`와 기존 서비스 환경 변수는 배포 전에 Cloud Run 설정에서
유지되는지 확인합니다.
