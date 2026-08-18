---
name: async-migration
description: 콜백·Rx 기반 비동기 코드를 Swift Concurrency 로 옮긴다. "async 로 바꿔줘", "콜백을 async/await 로", "RxSwift 걷어내줘", "Swift Concurrency 전환", "async let 써도 되나?" 에 쓴다. 시그니처만 바꾸는 것이 아니라 취소가 실제로 전파되는지 확인하는 것까지가 이 절차다.
argument-hint: "[대상. 예: '목록 조회 Repository', '결제 흐름']"
allowed-tools: Read, Grep, Glob, Edit, Write, Bash, Skill
---

# 비동기 전환

**콜백 API 를 `async` 로 감싸는 것은 시그니처만 바꾸는 일이다.**
감싸기만 하면 호출부는 깔끔해지는데 **취소가 전파되지 않는다.** 그리고 취소되지 않는 브릿지는
크래시가 된다 — continuation 이 재개되지 않은 채로 작업이 사라진다.

실제로 이렇게 물렸다.

- 화면에서 `async let` 으로 세 개를 병렬 호출했다가 **크래시**했다.
  `async let` 은 한 쪽이 throw/cancel 되면 나머지 자식 작업을 암묵적으로 취소하는데,
  브릿지 안의 레거시 콜백 API 가 취소를 인지하지 못해 **continuation 이 재개되지 않았다**
- 순차로 두 번 `await` 해서 화면이 두 번 갱신됐다. 1초 사이에 화면이 덜컥거렸다

그래서 이 절차의 목적은 4단계다. **취소가 실제로 전파되는지 확인한다.**

---

## 어떻게 쓰나 — 실제 흐름

```
사용자: "이 Repository 를 async 로 바꿔줘"
   │
   ├─ 0단계  내가 4개를 묻는다 ──────────────▶ 사용자가 답한다
   │          (대상 · 브릿지냐 네이티브냐 · 동작 변경 허용 · Swift 버전)
   │
   ├─ 1단계  지금 무엇으로 되어 있는지 실측한다
   │          콜백 / Rx / 브릿지 / 네이티브 분포
   │
   ├─ 2단계  옮길 순서를 낸다 ────────────────▶ 사용자가 승인
   │          아래 계층부터. 시그니처는 유지               ■ 여기서 멈춘다
   │
   ├─ 3단계  옮긴다 (경로 셋 중 하나)
   │          취소 핸들러를 함께 붙인다
   │
   ├─ 4단계  취소를 검증한다 ─────────────────▶ 사용자가 실행
   │          대기 중 이탈했을 때 무엇이 일어나는지        ■ 여기서 멈춘다
   │
   ├─ 5단계  병렬 호출 규칙을 적용한다
   │          async let 을 쓸 수 있는 조건인지 판정
   │
   └─ 커밋 후보를 제시한다 ──────────────────▶ 사용자가 판단
```

**멈추는 지점이 셋이다.** 순서 승인 전, 취소 검증(실행), 커밋 전.

4단계에서 멈추는 이유가 이 스킬의 존재 이유다. 취소는 **코드를 읽어서 확인할 수 없다.**
대기 중에 화면을 나가 봐야 안다.

### 기록은 파일로 남긴다 — 재개 지점

`.claude/async-migration/<대상>.md` 에 적는다. **추적되는 경로에 두지 않는다.**

전환은 계층별로 나뉘어 진행되고, 중간에 끊기면 **어디까지 네이티브고 어디부터 브릿지인지**
알 수 없게 된다. 그 상태에서 `async let` 판정을 하면 틀린다 (→ 5단계).

```markdown
## 지금 상태 (1단계 실측)
| 계층 | 방식 | 취소 인지 |
|---|---|---|
| Repository A | 브릿지 | ✗ |
| Repository B | 네이티브 | ○ |
| UseCase | async throws (시그니처만) | 해당 없음 |

## 승인받은 순서 (2단계, 2026-08-18)
1. Repository A 를 취소 인지 브릿지로
2. 그 위 UseCase 는 시그니처 유지 — 호출부 변경 없음

## 진행
- [x] Repository A 브릿지에 취소 핸들러 부착
- [ ] 취소 검증        ← 여기서 멈췄다
- [ ] 병렬 호출 판정

## 취소 검증 결과
- 대기 중 뒤로가기 → 요청 중단 확인 ○ / continuation 재개 확인 ○
- 재현 못 한 것: 응답이 650ms 라 제스처 창보다 좁아 취소 창을 못 만들었다
```

**재현하지 못한 것을 재현했다고 적지 않는다.** 실제로 서버 응답이 빨라
취소 창을 못 만든 적이 있다. 그때는 못 했다고 적는다.

### 다른 절차로 넘기는 지점

**아래는 지켜야 할 원칙이고, 같은 이름의 스킬은 그 원칙을 절차로 풀어놓은 것이다.**
스킬이 설치돼 있으면 `Skill` 로 부르고, **없으면 원칙만 지키고 그대로 진행한다.**

| 이런 게 나오면 | 지킬 원칙 | 절차가 있는 스킬 |
|---|---|---|
| 비동기만이 아니라 화면 패턴까지 바꿔야 한다 | 동작 보존을 먼저 증명한다. 전환과 섞지 않는다 | `legacy-port` (같은 플러그인) |
| 취소·재시도를 지킬 테스트가 없다 | 취소와 재시도는 테스트로 못 박는다 | `test-seams` (같은 플러그인) |
| 순차/병렬을 바꿨는데 빨라졌는지 모른다 | 추측하지 않고 전후를 잰다 | `ios-measure:measure-ios` |

같은 플러그인 안은 이름 그대로, 다른 플러그인은 `플러그인:스킬` 형식이다.
**호출에 실패하면 원칙만 적용하고 계속 간다.**

---

## 0. 먼저 확인한다 — 사용자에게 묻는다

1. **대상** — Repository 하나인가, 흐름 전체인가
2. **브릿지인가 네이티브인가** — 콜백 API 를 감쌀 것인가, 아니면 네이티브 async API 로
   갈아탈 것인가. 갈아탈 수 있으면 그게 정답이다 (→ 3-a)
3. **동작을 바꿔도 되는가** — 순차를 병렬로 바꾸면 화면 갱신 횟수와 취소 동작이 달라진다.
   기본값은 **바꾸지 않는다**
4. **Swift 버전과 언어 모드** — Swift 6 strict concurrency 면 `Sendable` 청구서가 온다 (→ 3-b)

---

## 1. 지금 무엇으로 되어 있는지 실측한다

추측하지 않는다. **브릿지와 네이티브가 섞여 있는지**가 5단계 판정을 가른다.

```sh
# 콜백 기반 (completion / success·failure 쌍)
grep -rnE 'completion: *@escaping|success: *@escaping|failure: *@escaping' --include='*.swift' <대상>

# Rx 기반
grep -rnE 'Observable<|Single<|\.subscribe\(|DisposeBag' --include='*.swift' <대상> | wc -l

# 브릿지 (continuation 으로 감싼 것)
grep -rn 'withCheckedThrowingContinuation\|withCheckedContinuation\|withUnsafeContinuation' --include='*.swift' .

# 취소를 인지하는 브릿지인가 ← 이 수가 위 수보다 적으면 그 차이가 위험 구간이다
grep -rn 'withTaskCancellationHandler' --include='*.swift' . | wc -l

# 병렬 호출 (5단계 판정 대상)
grep -rn 'async let\|withThrowingTaskGroup\|withTaskGroup' --include='*.swift' .
```

**`continuation` 개수와 `withTaskCancellationHandler` 개수의 차이**가 이 저장소에서
취소가 새는 지점의 상한이다. 그 목록을 먼저 만든다.

---

## 2. 옮길 순서를 정한다 — 시그니처는 유지

아래 계층부터 옮긴다. 그리고 **위 계층의 시그니처를 바꾸지 않는다.**

```
Repository (구현) → UseCase (시그니처 유지) → ViewModel (호출부 변경 없음)
```

UseCase·Repository 의 시그니처를 `async throws` 로 유지하면 **내부 구현을 브릿지에서
네이티브로 갈아도 호출부가 그대로다.** 전환을 조금씩 할 수 있는 이유가 이것이다.

```swift
protocol ItemRepository {
    func load() async throws -> [Item]   // 구현이 브릿지든 네이티브든 이 줄은 안 바뀐다
}
```

---

## 3. 옮긴다 — 경로 셋

### a. 네이티브 async API 로 갈아탄다 (가능하면 이것)

라이브러리가 네이티브 async 를 제공하면 브릿지를 만들지 않는다.
구조적 동시성이 정상 동작하고 취소가 자동으로 전파된다.

**신규 코드에 브릿지를 새로 도입하지 않는다.** 브릿지는 레거시를 감싸는 임시 수단이다.

### b. 취소를 인지하는 브릿지로 감싼다

콜백 API 를 감쌀 수밖에 없다면 **취소 핸들러를 반드시 함께 붙인다.**
붙이지 않은 브릿지가 크래시의 출발점이다.

```swift
func load(_ client: LegacyClient) async throws -> [Item] {
    try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            client.start(success: { continuation.resume(returning: $0) },
                         failure: { continuation.resume(throwing: $0) })
        }
    } onCancel: {
        client.cancel()          // 레거시에 취소를 실제로 전달한다
    }
}
```

**`onCancel:` 클로저는 `@Sendable` 이다.** Swift 6 언어 모드에서 여기에 non-Sendable
객체를 잡으면 **경고가 아니라 에러**다.

```
error: capture of 'client' with non-Sendable type 'LegacyClient' in a '@Sendable' closure
```

레거시 객체가 내부적으로 동기화돼 있으면 그 사실을 선언한다.
**왜 안전한지 주석으로 남긴다** — 컴파일러 검사를 끄는 선언이므로 근거가 없으면 다음 사람이 못 믿는다.

```swift
/// 내부에서 락으로 동기화하므로 Sendable 을 선언한다.
final class LegacyClient: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    func start(success: @escaping @Sendable ([Item]) -> Void,
               failure: @escaping @Sendable (Error) -> Void) { ... }

    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
}
```

콜백 파라미터에도 `@Sendable` 이 필요하다. 위 형태는 Swift 5·6 양쪽에서
**경고·에러 0으로 통과하는 것을 확인했다.**

### c. Rx 스트림을 옮긴다

**한 번만 값을 내는 것과 계속 내는 것을 구분한다.** 섞으면 취소 의미가 달라진다.

| Rx | 옮길 대상 |
|---|---|
| `Single` / 한 번 값을 내고 끝 | `async throws -> T` |
| `Observable` / 계속 값을 냄 | `AsyncStream` · `AsyncThrowingStream` |
| `DisposeBag` 로 수명 관리 | `Task` 를 보관하고 `deinit`·이탈 시점에 `cancel()` |

`deinit` 에서 취소할 때 주의한다. **`deinit` 에서 액터 격리 상태를 건드리면 안 된다.**
취소는 격리 없이 부를 수 있는 형태로 만들어 둔다.

---

## 4. 취소를 검증한다 — 이 단계가 목적이다

**코드를 읽어서 확인할 수 없다.** 실행해서 세 가지를 본다.

| 확인할 것 | 어떻게 |
|---|---|
| 요청이 실제로 중단되는가 | 대기 중 화면을 나가고, 네트워크 요청 수를 센다 |
| continuation 이 재개되는가 | 취소 뒤에도 앱이 살아 있는가. 죽으면 재개되지 않은 것이다 |
| 취소 뒤에 상태가 갱신되지 않는가 | 나간 화면의 상태가 나중에 바뀌면 안 된다 |

취소 창을 만드는 방법이다.

```sh
# 응답이 빠르면 취소 창이 안 열린다. 느린 조건을 먼저 만든다
#   · 네트워크 조건을 느리게 (Network Link Conditioner)
#   · 목록 규모를 키운다
#   · 프록시로 응답을 지연시킨다
```

**취소를 재현하지 못했으면 못 했다고 적는다.** 실제로 서버 응답이 650ms 라
제스처 창보다 좁아서 재현하지 못한 적이 있다. 그때 "취소 처리를 확인했다" 고 쓰면 거짓이 된다.

---

## 5. 병렬 호출 규칙 — `async let` 판정

**브릿지가 하나라도 섞여 있으면 `async let` 을 쓰지 않는다.**

이유는 이렇다. `async let` 은 한 쪽이 throw/cancel 되면 **나머지 자식 작업을 암묵적으로
취소**한다. 취소를 인지하지 못하는 브릿지가 그 안에 있으면 continuation 이 재개되지 않고,
작업이 해제되면서 크래시한다.

판정표다.

| 상황 | 병렬 방법 |
|---|---|
| 전부 네이티브 async (브릿지 0) | `async let` 가능 |
| 브릿지가 섞여 있고 **취소 핸들러가 붙어 있다** | `TaskGroup` 을 쓴다. 실패 처리를 명시적으로 쓸 수 있다 |
| 브릿지가 섞여 있고 취소 핸들러가 없다 | **병렬로 만들지 않는다.** 순차로 둔다 |

```swift
// 브릿지가 섞여 있을 때의 병렬 — 실패를 개별로 다룰 수 있다
try await withThrowingTaskGroup(of: [Item].self) { group in
    for client in clients { group.addTask { try await load(client) } }
    var all: [[Item]] = []
    for try await result in group { all.append(result) }
    return all
}
```

**순차를 병렬로 바꾸는 것은 동작 변경이다.** 화면 갱신 횟수가 달라지고 취소 의미가 달라진다.
0단계에서 허용받지 않았으면 하지 않는다.

### 화면 갱신 횟수를 함께 본다

두 요청을 각각 기다려 각각 반영하면 **화면이 두 번 덜컥거린다.**
순차를 유지하더라도 반영은 한 번으로 모을 수 있다. 이것은 비동기 구조가 아니라
반영 시점의 문제이므로 전환과 분리해서 판단한다.

---

## 6. 보고 형식

```
■ 옮긴 것
   계층 → 경로(a 네이티브 / b 브릿지 / c Rx) → 시그니처가 바뀌었는지

■ 취소
   취소 핸들러를 붙인 곳 / 안 붙인 곳
   검증 결과: 요청 중단 · continuation 재개 · 취소 후 상태 갱신
   **재현하지 못한 것을 명시**

■ Sendable 청구서
   @unchecked Sendable 을 선언한 타입과 그 근거 (락·직렬 큐 등)

■ 병렬 호출 판정
   async let / TaskGroup / 순차 유지 — 각각 왜 그렇게 정했는지

■ 동작이 달라진 것
   순차↔병렬, 화면 갱신 횟수. 허용받은 범위인지

■ 내가 돌리지 않은 것
   빌드·테스트·취소 재현 중 안 한 것
```

**빌드·테스트를 돌리지 않았으면 돌리지 않았다고 적는다.**
취소는 특히 "코드상 맞다" 로 끝내지 않는다 — 실행해서 본 것만 확인으로 적는다.
