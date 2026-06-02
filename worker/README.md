# Worker

매일 자정(KST)에 GitHub Actions가 실행하는 브리핑 생성기.

## What it does

1. Open-Meteo에서 오늘/내일 날씨 조회
2. Gemini로 캐릭터 × 시간대별 스크립트 생성
3. Typecast로 6시 morning 슬롯 × 4 캐릭터 = 4개 음성 합성
4. 결과를 `../docs/`에 저장 → GitHub Pages 배포
5. 메타데이터를 Firestore에 저장

## Local development

```bash
# 의존성 설치
uv sync

# 로컬 실행 (env vars 필요)
uv run python main.py
```

## Required env vars

- `GEMINI_API_KEY` — Gemini Developer API key
- `TYPECAST_API_KEY` — Typecast API key
- `GOOGLE_APPLICATION_CREDENTIALS` — (로컬만) SA JSON 경로

GitHub Actions에서는 WIF로 GCP 인증, secrets로 API 키 주입.

## Architecture

```
domain/      → 순수 데이터 클래스 (외부 의존성 0)
adapters/    → 외부 시스템 어댑터 (Gemini, Typecast, Open-Meteo, Firestore)
usecases/    → 비즈니스 흐름 (도메인 + 어댑터 조합)
main.py      → 엔트리포인트
config.py    → 도시·캐릭터·알람 시간 설정
```
