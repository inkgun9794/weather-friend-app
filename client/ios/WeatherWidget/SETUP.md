# iOS 날씨 위젯 — Xcode 연동 (한 번만)

Flutter/Swift 코드는 모두 준비돼 있어요. Xcode에서 **위젯 확장 타깃을 만들고 App Group을
연결하는 작업만** 아래 순서대로 해주면 됩니다. (10분 정도)

## 1. 위젯 확장 타깃 생성
1. `client/ios/Runner.xcworkspace` 를 Xcode로 엽니다. (`.xcodeproj` 아님)
2. 메뉴 `File > New > Target…`
3. **Widget Extension** 선택 → Next
4. 설정:
   - **Product Name: `WeatherWidget`** (이 이름 그대로 — Swift의 `kind`, Flutter의 `iOSName`과 일치해야 함)
   - "Include Live Activity" **체크 해제**
   - "Include Configuration App Intent" **체크 해제**
   - Team: Runner와 동일하게
5. Finish → "Activate scheme?" 뜨면 **Cancel** (Runner 스킴 유지)

## 2. 생성된 샘플 코드를 우리 코드로 교체
- Xcode가 `WeatherWidget/` 그룹에 `WeatherWidget.swift`, `WeatherWidgetBundle.swift`(또는
  `*Bundle`), `AppIntent.swift`, 애셋 등을 자동 생성합니다.
- 자동 생성된 **`WeatherWidget.swift` 내용을** 이 폴더의
  [`WeatherWidget.swift`](./WeatherWidget.swift) 내용으로 **통째로 덮어씁니다.**
  (우리 파일에 `@main`이 있으므로) 자동 생성된 **`...Bundle.swift`와 `AppIntent.swift`는
  삭제**하세요 (Move to Trash). `@main`이 두 개면 빌드 에러가 납니다.
  - 이미 디스크의 `client/ios/WeatherWidget/WeatherWidget.swift`가 있으니, 타깃 생성 후
    Xcode가 만든 파일을 지우고 이 파일을 그 타깃에 **Add Files…**로 넣어도 됩니다
    (Target Membership: WeatherWidget 체크).

### 2-1. 옷 아이콘 이미지 추가 (위젯 하단 옷추천용)
`client/ios/WeatherWidget/clothes/` 폴더에 옷 PNG들(`oc_*.png`, 약 34개)이 준비돼 있어요.
이 폴더를 **WeatherWidget 타깃에 추가**하세요.
1. Xcode에서 `clothes` 폴더를 위젯 그룹으로 드래그 → **Copy items if needed** 체크,
   **Add to targets: WeatherWidget** 체크 ("Create groups" 선택).
2. 확인: WeatherWidget 타깃 → Build Phases → **Copy Bundle Resources**에 `oc_*.png`들이
   들어가 있어야 합니다. (SwiftUI가 `UIImage(named: "oc_coat")`로 찾음)

## 3. App Group 연결 (앱 ↔ 위젯 데이터 공유의 핵심)
두 타깃 **모두**에 같은 App Group을 켭니다.

**Runner 타깃**
1. 프로젝트 네비게이터에서 Runner 프로젝트 → **Runner** 타깃 → **Signing & Capabilities**
2. `+ Capability` → **App Groups** 추가
3. `group.com.weatherfriend.app` 를 추가하고 **체크**
   - (이미 `Runner.entitlements`에 넣어뒀으니 목록에 보일 겁니다. 없으면 `+`로 추가)

**WeatherWidget 타깃**
1. **WeatherWidget** 타깃 → **Signing & Capabilities**
2. `+ Capability` → **App Groups**
3. 같은 `group.com.weatherfriend.app` 추가 + 체크

> 두 타깃의 App Group 문자열이 **정확히 같아야** 데이터가 공유됩니다.
> Swift(`appGroupId`), Flutter(`kWidgetAppGroupId`) 모두 `group.com.weatherfriend.app`.

## 4. 배포 타깃 확인
- WeatherWidget 타깃의 **Minimum Deployments**를 Runner와 맞추세요 (현재 iOS 15.0).
  코드는 iOS 17 미만도 지원합니다.

## 5. 빌드 & 테스트
```
flutter run            # 앱을 한 번 실행해 날씨 데이터를 App Group에 기록
```
- 앱을 실행/새로고침하면 현재 날씨가 공유 저장소에 써집니다.
- 홈 화면 빈 곳 길게 누르기 → `+` → "현재 날씨" 위젯 추가.
- 비/눈/흐림/맑음(주·야)에 따라 배경색과 SF Symbol 아이콘이 바뀝니다.

## 6. (선택) 앱 안 열어도 위젯이 스스로 갱신되게 — iOS 백그라운드 설정
Android는 `workmanager`가 추가 설정 없이 자동 동작하지만, **iOS는 아래 2가지가 더 필요**
합니다. (`Info.plist`는 이미 코드로 반영됨: `UIBackgroundModes`에 `fetch`/`processing`,
`BGTaskSchedulerPermittedIdentifiers`에 `weatherWidgetRefresh`.)

`ios/Runner/AppDelegate.swift`에 아래를 추가하세요.

1) 파일 상단 import에 추가:
```swift
import workmanager_apple
```

2) `didInitializeImplicitFlutterEngine(_:)` 안, 기존
   `FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { ... }` 옆에 추가
   (백그라운드 isolate에서도 플러그인이 등록되도록):
```swift
WorkmanagerPlugin.setPluginRegistrantCallback { registry in
  GeneratedPluginRegistrant.register(with: registry)
}
```

3) `didFinishLaunchingWithOptions` 안, `return super...` 직전에 태스크 등록:
```swift
WorkmanagerPlugin.registerPeriodicTask(
  withIdentifier: "weatherWidgetRefresh",
  frequency: NSNumber(value: 30 * 60) // 30분(최소 15분). OS가 실제 주기는 조절함
)
```

> iOS 백그라운드 실행은 OS가 배터리/사용패턴에 따라 **기회주의적으로** 돌립니다. 정확한
> 30분 간격은 보장되지 않고, 보통 앱을 자주 쓰는 사용자일수록 더 자주 갱신됩니다. 이는
> 애플 기본 날씨 위젯도 동일한 제약이에요.

## 참고 — "비 애니메이션"
iOS 위젯(WidgetKit)은 실시간 파티클 애니메이션을 지원하지 않아, 비는 **`cloud.rain.fill`
정적 아이콘 + 회색 배경**으로 표현합니다. (앱 안 화면의 빗줄기 애니메이션은 위젯엔 넣을 수
없습니다.) 데이터는 앱 실행/새로고침 또는 위 백그라운드 태스크로 갱신됩니다.
