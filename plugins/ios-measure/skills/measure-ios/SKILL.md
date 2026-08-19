---
name: measure-ios
description: iOS 앱의 성능·동작을 추측이 아니라 수치로 확인한다. "느리다", "왜 이렇게 오래 걸리지", "성능 개선", "이거 재봐", "전후 비교", "계측 붙여줘" 에 답한다. 고치기 전에 재고, 고친 뒤에 다시 재서 전후를 남긴다.
argument-hint: "[느린 화면·동작. 예: '목록 스크롤', '진입 지연']"
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# iOS 수치 측정

성능 문제를 **추측으로 고치지 않기 위한** 절차다. 순서가 핵심이다 —
**재현 → 계측 → 측정 → 수정 → 재측정.** 중간을 건너뛰면 무엇을 고쳤는지 말할 수 없다.

## 원칙 셋

1. **고치기 전에 잰다.** 잰 뒤에 고치면 개선폭을 말할 수 있고, 안 재고 고치면 "빨라진 것 같다" 밖에 남지 않는다
2. **첫 가설은 대개 틀린다.** 눈에 보이는 원인(메인 스레드 디코딩, 무거운 레이아웃)이 실제 원인인 경우는 절반도 안 된다. 측정이 가설을 이긴다
3. **가설이 반례를 만나면 버린다.** 측정값이 가설과 다르면 측정을 의심하기 전에 가설을 버린다

---

## 어떻게 쓰나 — 실제 흐름

```
사용자: "목록 화면이 느려"
   │
   ├─ 1단계  재현 조건을 적고 실제로 재현한다
   │          기기·구성·데이터 규모·조작 순서
   │
   ├─ 2단계  무엇을 잴지 고르고 그 이유를 말한다 ──▶ 사용자가 승인
   │          "네트워크 요청 수부터 본다. 항목 수에      ■ 여기서 멈춘다
   │           비례해 늘면 캐시 부재다"
   │
   ├─ 3단계  계측을 붙인다 (릴리즈에 남지 않는 형태로)
   │
   ├─ 4단계  수치를 뽑아 보여준다 ─────────────────▶ 사용자가 본다
   │          가설이 틀렸으면 여기서 버린다             ■ 원인 특정 전에는 안 고친다
   │
   ├─ 5단계  고치고 같은 절차로 다시 잰다
   │          전후를 같은 표에
   │
   └─ 6단계  계측을 걷어냈는지 확인 + 커밋 후보 ────▶ 사용자가 판단
```

**멈추는 지점이 셋이다.** 무엇을 잴지 승인 전, **원인 특정 전(여기서 고치면 안 된다)**, 커밋 전.

4단계 뒤에 멈추는 이유가 이 스킬의 존재 이유다. 수치를 보기 전에 고치기 시작하면
고친 것이 원인이었는지 알 수 없다. **첫 가설은 대개 틀린다.**

### 측정 기록은 파일로 남긴다 — 재개 지점

`.claude/measure/<대상>.md` 에 적는다. **추적되는 경로에 두지 않는다.** `.gitignore` 에 `.claude/` 가 있는지 먼저 확인한다
(`git check-ignore -q .claude/x && echo 무시됨`). 없으면 먼저 추가한다 — 없으면 작업 파일이 커밋 후보로 뜬다.

측정은 여러 번 돌리고 그 사이에 코드가 바뀐다. 대화가 끊기면 "개선 전 값이 얼마였는지" 가
사라지고, 그러면 전후 비교가 불가능해진다. 기억으로 이어가지 않는다.

```markdown
## 재현 조건
기기 / 구성(Debug|Release) / 데이터 규모 / 조작 순서 / 캐시 상태

## 개선 전 (2026-08-18 측정)
| 항목 | 값 |
|---|---|
| 네트워크 요청 수 | 219 |
| 메인 스레드 점유 | 31ms |

## 기각한 가설
- 메인 스레드 디코딩 → 재보니 1~2ms 백그라운드. 버림

## 진행
- [x] 계측 삽입
- [x] 개선 전 측정
- [ ] 수정          ← 여기서 멈췄다
- [ ] 개선 후 재측정
- [ ] 계측 제거 확인 (strings 로 0건)
```

### 다른 절차로 넘기는 지점

**아래는 지켜야 할 원칙이고, 같은 이름의 스킬은 그 원칙을 절차로 풀어놓은 것이다.**
스킬이 설치돼 있으면 `Skill` 로 부르고, **없으면 원칙만 지키고 그대로 진행한다.**

| 이런 게 나오면 | 지킬 원칙 | 절차가 있는 스킬 |
|---|---|---|
| 느린 원인이 구조라서 화면을 옮겨야 한다 | 측정과 구조 변경을 같은 커밋에 섞지 않는다 | `ios-modernize:legacy-port` |
| 고친 것을 지킬 테스트가 없다 | 수치를 지키는 테스트를 붙인다 | `ios-modernize:test-seams` |
| 빌드 시간이 문제다 | 앱 성능과 빌드 성능을 섞지 않는다 | `ios-modernize:modularize-ios` |

다른 플러그인의 스킬은 `플러그인:스킬` 형식이다. **호출에 실패하면 원칙만 적용하고 계속 간다.**

---

## 1단계 — 재현 절차를 못 박는다 (먼저, 5분)

전후 비교의 전제는 **같은 조작을 같은 조건에서 반복하는 것**이다. 이게 고정되지 않으면
뒤의 수치 전부가 무의미하다.

### 실기기가 기준선이다

**시뮬레이터 수치로 실기기를 말하지 않는다.** 시뮬레이터는 맥 CPU·GPU 로 돌기 때문에
계산은 빠르고 I/O 는 다르다. 그리고 **써멀 스로틀링·메모리 압박·실제 네트워크 지연이 없다.**

| | 시뮬레이터 | 실기기 |
|---|---|---|
| 쓰는 때 | 개선 방향을 빠르게 훑을 때 | **수치를 주장할 때** |
| 신뢰도 | 상대 비교만 (전/후) | 절대값을 말할 수 있다 |
| 안 나오는 것 | 써멀·메모리 압박·저사양 기기 | — |

보고에 쓸 수치는 실기기에서 뽑는다. 실기기가 없으면 **"시뮬레이터 측정" 이라고 적는다.**

적어 둘 것:

- 기기·OS 버전 (시뮬레이터인지 실기인지 — **어느 쪽인지 반드시 적는다**)
- 빌드 구성 (Debug / Release) — **Release 는 최적화가 켜져서 수치가 크게 다르다**
- 데이터 규모 (목록 몇 건, 이미지 몇 장)
- 조작 순서 (앱 실행 → 탭 2 → 스크롤 3회)
- 캐시 상태 (첫 실행인지, 두 번째인지)

```sh
xcrun simctl shutdown all && xcrun simctl boot <UDID> && xcrun simctl bootstatus <UDID>
xcrun simctl uninstall <UDID> <bundle-id>   # 캐시까지 지운 첫 실행 조건
```

---

## 2단계 — 무엇을 잴지 고른다

계층별로 "이 층이 원인이면 어떤 수치가 튀는가" 를 먼저 정한다. 전부 재려 하면 아무것도 못 잰다.

| 계층 | 재는 수치 | 이 층이 원인일 때 |
|---|---|---|
| **네트워크** | 요청 수, **중복 요청 수**, 응답 시간, 응답 크기 | 요청 수가 화면에 보이는 항목 수와 비례해서 늘어난다 |
| **직렬화** | 디코딩 시간, **어느 스레드에서 도는지** | 디코딩이 메인에서 돈다 |
| **메인 스레드** | 한 이벤트당 점유 시간 | **16.7ms** 를 넘으면 프레임을 놓친다 (60Hz 기준) |
| **렌더** | 셀 구성 횟수, 스냅샷 적용 시간, self-sizing 계산 횟수 | 화면에 안 보이는 셀까지 구성된다 |
| **객체 생성** | 반복 경로에서 만들어지는 무거운 객체 수 | 포매터·정규식·인코더가 루프 안에서 생성된다 |
| **메모리** | 캐시 히트/미스, 캐시 크기, 화면 해제 여부 | 뒤로 가도 메모리가 안 준다 |
| **동시성** | 순차 대기 구간 | 독립적인 두 호출이 순차로 붙어 있다 |
| **정적** | 빌드 시간, 린트 경고 수, 파일·줄 수, 테스트 수 | (문서에 적는 수치. 6단계 참조) |
| **접근성** | 텍스트 대비비, 탭 영역 크기 | 대비 4.5:1 · 탭 영역 44×44pt 미달 |

**가장 값어치 있는 셋**: 네트워크 중복 요청 수, 메인 스레드 점유 시간, 반복 경로의 객체 생성 수.
나머지는 Instruments 가 더 잘한다.

---

## 3단계 — 계측을 붙인다

### 요건

- **릴리즈 빌드에 남지 않는다.** 문자열 조립조차 하지 않아야 한다 → `@autoclosure` + `#if DEBUG`
- **끄고 켤 수 있다.** 환경변수로 제어해서 재빌드 없이 조건을 바꾼다
- **한 곳에 모은다.** 계측 코드가 열 파일에 흩어지면 걷어낼 때 남는다

### 시간 측정

`Diagnostics/Measure.swift`

```swift
import Foundation

public enum Measure {
    /// 라벨을 @autoclosure 로 받는다 → 릴리즈에서는 문자열을 만들지도 않는다.
    public static func mark(_ label: @autoclosure () -> String) {
        #if DEBUG
        print("[PERF] \(label())")
        #endif
    }

    public static func time<T>(_ label: @autoclosure () -> String,
                               _ body: () throws -> T) rethrows -> T {
        #if DEBUG
        let start = DispatchTime.now().uptimeNanoseconds
        defer {
            let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            let thread = Thread.isMainThread ? "main" : "bg"
            print("[PERF] \(label()) \(String(format: "%.1f", ms))ms (\(thread))")
        }
        #endif
        return try body()
    }
}
```

`print` 를 쓰는 이유는 4단계에서 **파일로 뽑아 세기 쉽기 때문**이다.
Instruments 타임라인에 올리고 싶으면 `OSSignposter` 로 구간을 감싼다 (iOS 15+).

### 횟수 측정

시간보다 **횟수**가 원인을 더 정확히 가리킬 때가 많다. 요청 수·객체 생성 수는 실행마다 흔들리지 않아
전후 비교가 깔끔하다.

```swift
public actor Counter {
    public static let shared = Counter()
    private var counts: [String: Int] = [:]

    public func bump(_ key: String) { counts[key, default: 0] += 1 }
    public func snapshot() -> [String: Int] { counts }
    public func reset() { counts.removeAll() }
}
```

**세는 지점을 고르는 규칙**: 고치려는 계층 **바로 그 자리**에서 센다.
캐시를 넣어 요청을 줄이려면 캐시 **뒤**(실제 네트워크 호출부)에서 세야 한다.
캐시 앞에서 세면 캐시를 넣어도 숫자가 그대로라 개선이 안 보인다. (→ 함정 1)

---

## 4단계 — 수치를 꺼낸다

### 앱을 직접 돌려서

```sh
# 콘솔을 파일로 받는다. 로그는 stderr 로 가는 경우가 많으니 둘 다 받는다
xcrun simctl launch --stdout=/tmp/out.log --stderr=/tmp/err.log \
    --terminate-running-process <UDID> <bundle-id>

# 계측을 환경변수로 켠다 — SIMCTL_CHILD_ 접두사가 앱 환경으로 전달된다
SIMCTL_CHILD_PERF=1 xcrun simctl launch --console-pty <UDID> <bundle-id>

# 세기
grep -c '\[PERF\] image-request' /tmp/err.log
grep '\[PERF\]' /tmp/err.log | grep -oE '[0-9.]+ms' | sort -n | tail -5   # 최악 5개
```

### 실기기에서 뽑을 때 — `devicectl`

`simctl` 은 시뮬레이터 전용이다. 실기기는 `devicectl` 을 쓴다 (Xcode 15+, `Device Hub` 의 CLI 기반).

```sh
# 기기 목록에서 Identifier 를 얻는다. State 가 connected 인 것만 쓸 수 있다
xcrun devicectl list devices

# 계측을 켜고 실기기에서 앱을 띄운다 — DEVICECTL_CHILD_ 접두사가 앱 환경으로 전달된다
DEVICECTL_CHILD_PERF=1 xcrun devicectl device process launch \
    --device <Identifier> <번들ID>

# JSON 으로 직접 주입해도 된다 (이쪽을 쓰면 DEVICECTL_CHILD_ 는 무시된다)
xcrun devicectl device process launch --device <Identifier> \
    -e '{"PERF":"1"}' <번들ID>
```

**실기기에서는 콘솔 스트리밍에 기대지 않는다.** 대신 **계측을 파일로 쓰고 꺼낸다.**

```sh
# 앱이 Documents/perf.log 에 남기게 만들고, 조작이 끝난 뒤 꺼낸다
xcrun devicectl device copy from --device <Identifier> \
    --domain-type appDataContainer --domain-identifier <번들ID> \
    --source Documents/perf.log --destination ./perf.log

# 컨테이너에 무엇이 있는지 먼저 보려면
xcrun devicectl device info files --device <Identifier> \
    --domain-type appDataContainer --domain-identifier <번들ID> --recurse
```

**확인한 것** — 실기기에서 `list devices` · `info files`(컨테이너 453개 나열) ·
`copy to`/`copy from` 왕복(내용 그대로 회수)이 동작하는 것을 확인했다.
**`process launch` 는 실행해 보지 않았다** — 옵션 표면만 확인했다.

세 가지를 미리 알아 둔다.

| 알아 둘 것 | 왜 |
|---|---|
| `Failed to load provisioning paramter list ... No provider was found` 가 **매 호출마다** 뜬다 | 무해하다. 실패로 판단하지 않는다 |
| 기기가 잠겨 있으면 일부 명령이 막힌다 | `device info lockState` 로 먼저 본다 |
| 화면 배율·크기는 기기마다 다르다 | `device info displays` 가 `bounds` 와 `pointScale` 을 준다. 셀 크기 계산의 전제다 |

### 실기기에서만 잴 수 있는 것

시뮬레이터에서 재현되지 않는 조건을 인공적으로 만들 수 있다.

```sh
# 메모리 압박을 준다 — 캐시가 비워지는 경로를 재현한다
xcrun devicectl device process sendMemoryWarning --device <Identifier> <pid 또는 번들ID>

# 백그라운드 전환 재현
xcrun devicectl device process suspend --device <Identifier> ...
xcrun devicectl device process resume  --device <Identifier> ...

# 화면 방향 (get / rotate / set)
xcrun devicectl device orientation get --device <Identifier>
```

**이 셋은 존재만 확인했고 실행해 보지 않았다.** 쓸 때 동작을 먼저 확인한다.

### 테스트에서 뽑을 때

**`print` 는 `xcodebuild test` 표준 출력에 섞여 나오지 않는다.** 결과 번들에서 꺼낸다.

```sh
xcodebuild test -workspace App.xcworkspace -scheme App \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -resultBundlePath /tmp/res.xcresult

xcrun xcresulttool get log --path /tmp/res.xcresult --type console | grep '\[PERF\]'
```

`--type` 은 `build` / `action` / `console` 세 개고, 테스트 콘솔 출력은 `console` 이다.

### 실행 횟수·통과 여부

```sh
xcodebuild test ... 2>&1 | grep 'Test run with'   # 실제 실행 개수
```

**테스트 파일을 새로 만들었으면 프로젝트를 재생성한다.** 프로젝트 생성 도구(Tuist 등)를 쓰는
저장소에서 파일만 추가하면 타깃에 안 붙어서 **조용히 실행되지 않는다.** 개수를 눈으로 확인한다.

---

## 5단계 — 고치고 다시 잰다

같은 재현 절차로 다시 돌리고 **같은 표에 나란히** 적는다.

```
                      전       후
이미지 요청 수         219       12
캐시 히트               0      207
메인 스레드 점유     31ms      7ms
포매터 생성 수        219        1
```

**시뮬레이터 시간 수치는 실행마다 흔들린다.** 3회 돌려 중위값을 쓰고, 첫 실행은 버린다
(캐시가 비어 있고 최초 로딩이 섞인다). 횟수 수치는 흔들리지 않으니 1회로 충분하다.

---

## 6단계 — 계측을 걷어냈는지, 문서 수치가 맞는지

```sh
# 릴리즈 바이너리에 계측 문자열이 남지 않았는지 — 0 이어야 한다
strings <App>.app/<App> | grep -c 'PERF'

# 계측 호출부가 남아 있어도 되지만, 임시로 넣은 것은 지웠는지
grep -rn 'Measure\.\|Counter.shared' --include='*.swift' . | wc -l
```

**문서에 적은 수치는 마지막에 전부 다시 잰다.** 잰 뒤에 코드가 또 움직이면 문서가 거짓이 된다.

```sh
git rev-list --count HEAD                       # 커밋 수
grep -rc '@Test\|func test' Tests/*.swift       # 테스트 수 (실행 수와 다를 수 있음)
swiftlint --quiet | grep -c warning             # 린트 경고 수
wc -l <문서에서 언급한 파일들>
```

---

## 함정 — 실제로 틀렸던 것들

1. **세는 지점이 틀리면 전후가 같게 나온다.** 뷰가 이미지를 요청하는 자리에서 세면 캐시를 넣어도
   숫자가 그대로다. 캐시 뒤 네트워크 호출부에서 세야 줄어드는 게 보인다
2. **`print` 는 테스트 표준 출력에 안 나온다.** 결과 번들에서 꺼낸다 (4단계)
3. **Debug 수치로 Release 를 말하지 않는다.** 최적화가 꺼져 있어 계산 비용이 과장된다.
   릴리즈 개선폭을 주장하려면 릴리즈에서 재야 한다
4. **첫 실행은 버린다.** 캐시·JIT·최초 레이아웃이 섞인다
5. **시뮬레이터가 불안정해지면 수치가 아니라 환경 문제다.** `Invalid device state` 가 나오면
   `shutdown` → `boot` → `bootstatus` 로 리셋하고 다시 잰다
6. **소프트웨어 키보드는 접근성 트리에 안 나온다.** 별 프로세스라서 `describe-ui` 로는 안 보인다.
   키보드 관련 확인은 스크린샷으로 한다
7. **개선폭을 비율로만 말하지 않는다.** "80% 개선" 보다 "219 → 12" 가 검증 가능하다

---

## 보고 형식

```
## 재현 조건
기기 / 구성 / 데이터 규모 / 조작 순서

## 처음 가설과 그 결과
가설: ...
측정: ... → 기각 (또는 확인)

## 실제 원인
1. ... (근거 수치)
2. ...

## 전후
표

## 남은 것
못 잰 것 · 재현 못 한 것을 명시. 안 쟀으면 안 쟀다고 적는다
```

**추측을 수치처럼 적지 않는다.** 재지 않은 항목은 "미측정" 으로 남긴다.
