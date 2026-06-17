# Weather Friend — 디자인 시스템 스펙 (v1 draft)

> **이 문서의 용도**: claude.ai/design(또는 Claude 대화)에 붙여넣어 "이 앱의 디자인 시스템을 완성해줘"라고 요청하기 위한 소스 문서입니다.
> **표기**: `[실재]` = 코드에 이미 존재 / `[제안]` = 아직 없음, 채워야 함.
> **앱 스택**: Flutter, Material 3(`useMaterial3: true`), 폰트 **Pretendard**. 색은 모두 **OKLCH**로 정의되어 sRGB로 변환됨(`oklch(L, C, H)`).

---

## 1. 앱 개요

날씨 + **캐릭터 동반자** 앱. 사용자가 캐릭터(4종)와 함께 날씨/브리핑/운세/기록을 보는 따뜻하고 부드러운 톤.

- **화면(feature)**: briefing(날씨 브리핑), chat(대화), character(캐릭터), location(위치), radar(레이더), fortune(운세), record(감정/사진 기록), schedule(일정), settings
- **분위기**: 종이질감의 밝은 배경(paper) + 잉크색 텍스트(ink), 시간대에 따라 바뀌는 하늘 그라데이션, 캐릭터별 고유 색.
- **도메인 특이점**: 브리핑 텍스트는 서울 기준(비용), 단 날씨 수치는 선택 도시 기준.

---

## 2. 색 토큰 `[실재]`

> 출처: `client/lib/app/theme/design_tokens.dart`. 전부 코드에 존재하는 실제 값.

### 2.1 중립 — ink / paper

| 토큰 | OKLCH | 역할 |
|---|---|---|
| `ink` | `oklch(0.22 0.018 250)` | 본문 텍스트 |
| `inkSoft` | `oklch(0.38 0.014 250)` | 보조 텍스트 |
| `inkMute` | `oklch(0.58 0.014 250)` | 캡션·메타 |
| `inkFaint` | `oklch(0.74 0.010 250)` | 비활성·플레이스홀더 |
| `paper` | `oklch(0.985 0.004 95)` | 기본 배경 |
| `paper2` | `oklch(0.965 0.006 95)` | 카드 배경 |
| `paper3` | `oklch(0.93 0.008 95)` | 더 깊은 면 |
| `line` | `oklch(0.88 0.008 95)` | 구분선 |
| `hairline` | `oklch(0.92 0.006 95)` | 얇은 경계 |
| `fortuneAccent` | `oklch(0.82 0.13 70)` | 포인트(운세) |

### 2.2 캐릭터 팔레트 (각 hue 고정, soft/base/deep)

| 캐릭터 | hue | soft | base | deep |
|---|---|---|---|---|
| `jiyoung` | 30° | `oklch(0.94 0.04 30)` | `oklch(0.74 0.13 30)` | `oklch(0.54 0.14 30)` |
| `sohee` | 330° | `oklch(0.94 0.03 330)` | `oklch(0.62 0.10 330)` | `oklch(0.42 0.12 330)` |
| `jihoon` | 240° | `oklch(0.94 0.03 240)` | `oklch(0.55 0.11 240)` | `oklch(0.38 0.12 240)` |
| `siwon` | 135° | `oklch(0.95 0.05 135)` | `oklch(0.78 0.14 135)` | `oklch(0.56 0.16 135)` |

### 2.3 시간대별 하늘 (top → mid → bot 그라데이션 + sun + 텍스트색)

| 키 | 시간 | label | top | mid | bot | sun | ink | inkSoft |
|---|---|---|---|---|---|---|---|---|
| `dawn` | 04–08 | 아침 햇살 | `0.78 0.10 30` | `0.86 0.08 70` | `0.93 0.05 90` | `0.86 0.12 70` | `0.28 0.04 30` | `0.42 0.03 30` |
| `day` | 08–17 | 맑은 한낮 | `0.74 0.10 235` | `0.85 0.06 220` | `0.94 0.03 220` | `0.92 0.10 90` | `0.24 0.04 240` | `0.42 0.03 240` |
| `dusk` | 17–21 | 저무는 하늘 | `0.55 0.14 25` | `0.62 0.13 350` | `0.50 0.13 300` | `0.78 0.14 50` | `0.95 0.02 30` | `0.82 0.03 30` |
| `night` | 21–04 | 깊은 밤 | `0.22 0.08 265` | `0.28 0.08 280` | `0.18 0.06 270` | `0.78 0.05 260` | `0.96 0.01 260` | `0.78 0.02 260` |

> 값은 모두 `L C H` 순서.

---

## 3. 타이포그래피 `[제안]`

- **폰트: Pretendard** `[실재]` (`PretendardVariable.ttf` 번들됨). 그 외 스케일은 아직 정의 안 됨.
- 아래는 *초안 제안* — 부드러운 날씨 동반앱 톤에 맞춰 확정 필요.

| 토큰 | size | weight | line-height | 용도 |
|---|---|---|---|---|
| `display` | 32 | 700 | 1.1 | 큰 수치(기온 등) |
| `title` | 22 | 700 | 1.2 | 화면 제목 |
| `headline` | 18 | 600 | 1.3 | 섹션 헤더 |
| `body` | 15 | 400 | 1.5 | 본문 |
| `bodyStrong` | 15 | 600 | 1.5 | 강조 본문 |
| `label` | 13 | 500 | 1.3 | 버튼·탭 |
| `caption` | 12 | 400 | 1.4 | 메타·보조 |
| `micro` | 11 | 500 | 1.3 | 초소형 라벨 |

---

## 4. 간격 · 모서리 · 그림자 `[제안]`

전부 아직 정의 안 됨 (위젯에 하드코딩 추정). 초안 제안:

- **Spacing (4pt 기반)**: `2, 4, 8, 12, 16, 20, 24, 32, 40, 48`
- **Radius**: `sm 8 · md 12 · lg 16 · xl 20 · pill 999`
- **Elevation**: 현재 앱은 **그림자보다 hairline 보더 중심의 플랫** 스타일. → 그림자 토큰 최소화하고 보더/배경 단차(paper→paper2→paper3)로 깊이 표현 제안. 필요시 `e1`(카드), `e2`(시트/모달) 정도만.

---

## 5. 컴포넌트 인벤토리

### 5.1 현재 공통 위젯 `[실재]` — `client/lib/shared/widgets/`
- `audio_bubble.dart`, `character_intro_button.dart`, `character_portrait.dart`, `weather_bg.dart`, `weather_icons.dart`

### 5.2 화면에 흩어진 위젯 `[실재]` (공통화 후보)
- record: `photo_dump`, `mood_widgets`, `streak_card`, `image_source_sheet`
- briefing: `ultra_short_section`, `outfit_recommendation_section`
- fortune: `fortune_result_card`, `birth_wheel_pickers`, `birth_input_form`, `score_chart_card`

### 5.3 정의가 필요한 핵심 컴포넌트 `[제안]`
- **Button**: primary / secondary / ghost · size(sm/md/lg) · 상태(default/pressed/disabled)
- **Card**: 기본 카드(paper2 + hairline) · 강조 카드
- **Chip / Tag**: 필터·라벨
- **Input / Form field**: 텍스트, 휠 피커(이미 birth_wheel 있음)
- **Sheet / Modal**: bottom sheet 패턴
- **List item / Section header**

---

## 6. 핵심 이슈 — 토큰과 테마의 단절 `[중요]`

`client/lib/app/theme/app_theme.dart`는 위 2장의 풍부한 OKLCH 토큰을 **전혀 쓰지 않고**, 시드 색 하나로만 테마를 만듭니다:

```dart
static const _seed = Color(0xFF7CB9E8); // 연한 하늘색
ColorScheme.fromSeed(seedColor: _seed, brightness: ...);
```

→ 즉 디자인 토큰이 있어도 실제 Material `ColorScheme`/컴포넌트에 연결되어 있지 않음. 이게 가장 먼저 풀 문제.

---

## 7. claude.ai/design에 요청할 것 (asks)

1. **타입 스케일 확정** — 3장의 제안을 이 앱 톤에 맞게 다듬어줘 (Pretendard 기준).
2. **spacing / radius / elevation 토큰 확정** — 플랫·hairline 미감 유지.
3. **핵심 컴포넌트 스펙 + 변형** — Button/Card/Chip/Input/Sheet (상태 포함). 가능하면 시각 카드로.
4. **다크 모드 전략** — 현재 light/dark를 fromSeed로만 처리. 토큰 기반(ink/paper 반전 등)으로 어떻게 설계할지.
5. **OKLCH 토큰 → Material `ColorScheme` 매핑** — ink/paper/character/sky 토큰을 primary/surface/onSurface 등에 어떻게 연결할지 (6번 이슈 해결).
6. **캐릭터/하늘 색의 역할 정의** — 어디까지 UI에 쓰고 어디부터는 배경 전용인지 가이드.

> 결과(스펙/컴포넌트)는 다시 Flutter 코드로 옮겨야 함. claude.ai/design은 repo 접근이 없으니, 산출물을 받아오면 코드 반영은 Claude Code에서 진행.
