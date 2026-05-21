# Weather Friend (날사친)

매일 그 시간, 너만의 캐릭터가 날씨를 알려주는 보이스 브리핑 앱.

## Structure

```
.
├── worker/   # Python worker — daily audio + text briefing generator (GitHub Actions)
├── docs/     # GitHub Pages source — generated audio files
├── client/   # Flutter app (coming later)
└── .github/  # CI/CD workflows
```

## Stack

- **AI**: Gemini Developer API (script generation)
- **TTS**: Typecast API (Korean character voices)
- **Storage**: GitHub Pages (audio files)
- **Database**: Firestore (metadata)
- **CI/CD**: GitHub Actions + Workload Identity Federation

## Status

MVP 개발 중. Worker → Flutter 순서로 진행.
