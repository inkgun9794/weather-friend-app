# 날사친 (Weather Friend) — 개발 HANDOFF

> 새 세션에서 이어서 작업할 때 이 문서를 먼저 읽어주세요.
> Worker 부분은 **완성·자동 가동 중**. 다음 단계는 Flutter 클라이언트.

---

## 한 줄 요약

매일 정해진 시간에 4명의 캐릭터 중 한 명이 *날씨를 브리핑*해주는 보이스 메시지 앱.
서울 거주자 대상 MVP. 알람 시간엔 음성 + 텍스트, 다른 시간엔 텍스트만.

---

## 현재 상태

### ✅ 완료된 것 — Worker 시스템 (자동 가동 중)

```
GitHub Actions cron (매시간 :50 UTC)
   ↓
worker/ Python 코드 실행
   ├─ Open-Meteo: 날씨 forecast (서울)
   ├─ Gemini API: 4 캐릭터 × 시맨틱 텍스트 생성
   ├─ Typecast API: 알람 시간(5/6/21/22) 4개 음성 합성
   ↓
docs/ 자동 commit + push (GitHub Pages 자동 배포)
Firestore에 메타 저장
```

### ⏳ 다음 — Flutter 클라이언트

사용자가 실제로 듣고 보는 앱. 아직 코드 0줄.

---

## 핵심 인프라 정보

| 항목 | 값 |
|---|---|
| GitHub Repo | `inkgun9794/weather-friend-app` (public) |
| Firebase Project | `weather-friend-92281` (Spark) — Firestore만 |
| GCP Gemini Project | `weather-friend-genius` (Blaze, quota cap 200/일) |
| Pages base URL | `https://inkgun9794.github.io/weather-friend-app/` |
| Worker cron | `'50 * * * *'` (매시간 :50 UTC) |
| Gemini model | `gemini-2.5-flash-lite` |
| TTS | Typecast Free (30K credits/월) — 음성은 5시·21시만 (하루 8 합성 = 4 캐릭터 × 2 슬롯) |

### Firestore 스키마

- **Collection**: `briefings`
- **Doc ID 형식**: `{city}_{date}_{hour:02d}_{character_id}`
  - 예: `seoul_2026-05-22_05_jiyoung`
- **Fields**:
  - `city`: "seoul"
  - `date`: "2026-05-22"
  - `hour`: 5 (0-23)
  - `character_id`: "jiyoung" | "sohee" | "jihoon" | "siwon"
  - `type`: "morning" | "evening" | "hourly"
  - `transcript`: 화면 표시용 메시지 (인터넷어투 OK)
  - `voice_script`: TTS용 자연 발화 (알람 슬롯만, 그 외 null)
  - `audio_url`: GitHub Pages URL (음성 있는 슬롯만)
  - `weather_snapshot`: { temperature_c, feels_like_c, condition, precipitation_prob, wind_speed_kmh, humidity }
  - `generated_at`, `expire_at`

### Pages URL 패턴

```
https://inkgun9794.github.io/weather-friend-app/briefings/{city}/{date}/{hour:02d}/{character_id}.mp3
```

### 보안 규칙

- **Firestore**: `briefings/` public read, write 차단 (Admin SDK만 가능)
- **Storage**: 안 씀 (Pages 사용)
- **API 키**: 코드/채팅/스샷에 절대 X. GitHub Secrets만.
- **GCP 인증**: WIF (장기 키 X)

---

## 핵심 설계 결정 (왜 그렇게 했는지)

### 1. 4 캐릭터 (이름 + 톤 + Typecast voice)

| ID | 이름 | 톤 | Typecast voice |
|---|---|---|---|
| `jiyoung` | 다정한 지영 | 따뜻하고 챙기는 누나 | `tc_66ab0e26ec23f325b7ad51df` (Yeseul) |
| `sohee` | 시크한 소희 | 시크하지만 챙기는 누나 | `tc_6568164fe05ddffee8b0e271` (Siyeon) |
| `jihoon` | 듬직한 지훈 | 차분 + 수치 정확한 오빠 | `tc_61f0859907085fc68561c9a1` (Jihoon) |
| `siwon` | 활발한 시원 | 활발하고 외향적인 동생 (인터넷어투 X) | `tc_61f0859907085fc68561c9a1` (Jihoon) |

상세 페르소나는 `worker/domain/character.py`.

### 2. 알림 시간 — 고정 5시·21시

- **푸시 알림 + 음성**: 오전 5시, 오후 9시 (KST). 사용자가 선택하지 않음.
- 그 외 22시간은 worker가 Firestore에 텍스트 메타만 쓰고, 사용자는 *앱을 열어서* 확인 (푸시 X).
- 의도: 우리 앱은 알람(깨우는 기계)이 아니라 알림(notification) 정도라 시간 선택 옵션 자체가 의미 없음.

### 3. 메시지 vs 음성 스크립트 분리

- **메시지** (`transcript`): 이모지, ㅋㅋ, ㄷㄷ 등 인터넷어투 OK
- **음성** (`voice_script`): TTS가 어색하지 않게 자연 발화로 변환 ("ㄹㅇ" → "진짜")
- Gemini가 한 호출에서 둘 다 생성, `[메시지]` / `[음성]` 마커로 분리

### 4. 캐릭터 잠금 — 옵션 B

> **슬롯의 캐릭터는 *알람 발사 시점*에 확정. 그 이후 캐릭터 변경해도 해당 슬롯은 옛 캐릭터로 표시.**

미청취 + 미알람 슬롯은 현재 캐릭터로 자유.

### 5. 위치 — GPS 자동

- 수동 도시 선택 UI **없음**
- GPS로 자동 감지 → 서울 외 한국 도시는 가장 가까운 지원 도시로 매핑
- **해외 감지 시**: 캐릭터별 정적 fallback 메시지 (`assets/audio/overseas/{char_id}.opus`)

### 6. Broadcast 모델

- 같은 도시 사용자 *전원*이 같은 오디오 파일 들음
- 사용자 수가 늘어도 생성 비용 일정
- 사용자별 개인화 X (계정 시스템 없음)

### 7. 채팅 기능 — 제거됨

원래 카톡 스타일 1:1 채팅 구상했으나, 단순화를 위해 *수신 전용*으로 변경.

---

## Flutter 클라이언트 — 만들어야 할 것

### 기술 스택 (확정)

- Flutter Stable + Dart 3.x/4.x (strict null safety)
- **Riverpod 2.x** (코드 생성 방식)
- **Clean Architecture** (Data / Domain / Presentation 엄격 분리)
- **Feature-first** 폴더 구조
- **Material Design 3**
- Firestore SDK + just_audio + geolocator + flutter_local_notifications + workmanager

### 폴더 구조

```
lib/
├── main.dart
├── app/                              # 앱 셸 (라우터·테마·ProviderScope)
│   ├── app.dart
│   ├── router/
│   └── theme/                        # Material 3
├── core/                             # 횡단 관심사
│   ├── constants/
│   ├── error/
│   ├── utils/
│   └── services/                     # 인프라 어댑터
│       ├── notification_service.dart # flutter_local_notifications
│       ├── audio_player_service.dart # just_audio
│       └── database.dart             # 로컬 캐시 (Drift 또는 Hive)
│
├── features/                         # 수직 슬라이스
│   ├── briefing/                     # 메인 화면, 슬롯 표시, 재생
│   ├── character/                    # 4 캐릭터 선택 (전용 화면에서만)
│   ├── location/                     # GPS + 도시 매핑 + 해외 감지
│   ├── schedule/                     # 알람 시간 (5/6/21/22) 설정
│   └── settings/                     # 알림 토글, 캐릭터 진입점
│
└── shared/                           # 공용 위젯·확장
```

각 feature는 자기 `data/domain/presentation`을 모두 가짐.

### 핵심 기능 체크리스트

- [ ] 프로젝트 init + Firebase 설정 (`flutterfire configure --project=weather-friend-92281`)
- [ ] Riverpod 2.x + 코드 생성 셋업
- [ ] **Briefing feature**:
  - Firestore에서 `seoul_{date}_{hour}_{char_id}` 도큐먼트 조회
  - 오디오 URL에서 mp3 다운로드 (just_audio) + 로컬 캐시
  - 카톡 스타일 메시지 버블 + 재생 컨트롤
  - 슬롯별 잠금 상태 (이미 발사된/들은 슬롯의 캐릭터 고정)
- [ ] **Character feature**:
  - 4 캐릭터 선택 화면 (전용)
  - 메인 화면에서 빠른 전환 X
  - 변경은 미래 슬롯에만 영향
- [ ] **Location feature**:
  - GPS 권한 + 위치 조회
  - 한국 본토 bounding box 안인지 체크
  - 해외 감지 시 캐릭터별 fallback 메시지 재생
- [ ] **Schedule feature** (단순화):
  - 시간 선택 UI **없음** (5시·21시 고정)
  - 알림 받기 on/off 토글만
  - `flutter_local_notifications`로 5시·21시 푸시 예약 (KST)
  - `workmanager`로 알림 직전 prefetch (해당 슬롯 미리 다운)
- [ ] **Onboarding**: 위치 권한 → 알림 권한 → 캐릭터 선택 → 알람 시간 → 완료
- [ ] **Settings**: 알림 토글, 캐릭터 변경 진입점, 앱 정보

### 캐싱 정책 (egress 절약)

- 알람 시간 10분 전에 워크매니저로 그 슬롯 prefetch
- 한 번 다운로드한 mp3는 로컬 캐시 유지 (LRU, 최대 50개 / 100MB)
- Firestore 메타도 캐싱 (오프라인 대응)

### 해외 fallback 메시지 (assets/)

```
assets/audio/overseas/
├── jiyoung.opus
├── sohee.opus
├── jihoon.opus
└── siwon.opus
```

각 ~50KB, 캐릭터별 톤으로 "여행 잘 다녀와, 거기 날씨는 잘 몰라" 식 메시지.
스크립트는 `worker/domain/character.py`의 각 캐릭터 `overseas_message` 필드 참조.

---

## 새 세션 시작 방법

1. 새 채팅에 다음 첫 메시지:
   > "weather-friend-app 프로젝트 Flutter 클라이언트 작업하려고 합니다.
   > `/Users/gun0/weather/HANDOFF.md` 먼저 읽어주세요."

2. 그 후 Claude가 HANDOFF 읽고 → 어떤 부분부터 시작할지 제안

3. 추천 시작점: `client/` 폴더 init + Firebase 설정 + 핵심 의존성 설치

---

## 운영 중인 시스템 — 건드리면 안 되는 것

- `worker/` (가동 중. 톤 미세 조정 외엔 손대지 말 것)
- `.github/workflows/generate-briefing.yml` (cron 가동 중)
- GitHub Secrets (절대 채팅에 노출 X)
- Firestore 보안 규칙 (read-only 유지)

---

## 비용 현황 ($0/월)

- Gemini Tier 1 무료 한도 + quota cap 200 RPD = $0
- Typecast Free 30K credits/월 = $0
- Firestore Spark = $0 hard cap
- GitHub Pages public repo = $0
- GitHub Actions 2000분/월 = $0 (사용 ~50분/월)

---

## 모르는 게 있으면

핵심 파일들 (`worker/domain/`, `worker/adapters/`, `worker/usecases/`, `worker/main.py`) 읽으면 의도와 데이터 흐름 파악 가능. README는 `worker/README.md` 참고.
