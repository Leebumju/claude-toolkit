# 기기에서 수치·로그를 꺼내는 명령

`measure-ios` 4단계와 `ios-modernize:crash-triage` 1단계가 함께 쓰는 **조회표**다.
절차가 아니라 명령 목록이므로 스킬 본문에서 뺐다. **필요한 항목만 찾아 쓴다.**

아래 "확인함" 표시는 실기기(iPhone 15 / iOS 26.6)에서 **실제로 돌려 본 것**이다.
표시가 없는 것은 옵션 표면만 확인했고 실행하지 않았다.

---

## 0. 공통 — 먼저 알아 둘 것

| 알아 둘 것 | 왜 |
|---|---|
| `Failed to load provisioning paramter list ... No provider was found` 가 **매 호출마다** 뜬다 | **무해하다.** 명령은 정상 동작한다. 이 줄을 보고 실패로 판단하지 않는다 |
| 기기가 잠겨 있으면 일부 명령이 막힌다 | `device info lockState` 로 먼저 본다 |
| `devicectl` 은 Xcode 15+ 에 있다 | `Device Hub` 는 그 위에 얹은 UI 다. CLI 는 그 전부터 쓸 수 있다 |

```sh
# 기기 목록 — State 가 connected 인 것만 쓸 수 있다        [확인함]
xcrun devicectl list devices

# 잠금 상태                                              [확인함]
xcrun devicectl device info lockState --device <Identifier>
```

파일 도메인은 네 개다.

```
systemCrashLogs · appDataContainer · appGroupDataContainer · temporary
```

`appDataContainer` 와 `appGroupDataContainer` 는 `--domain-identifier <번들ID>` 가 필요하다.
`temporary` 는 임의 문자열을 주면 그것이 내 공간이 된다.

---

## 1. 시뮬레이터에서 뽑기 — `simctl`

```sh
# 콘솔을 파일로. 로그는 stderr 로 가는 경우가 많으니 둘 다 받는다
xcrun simctl launch --stdout=/tmp/out.log --stderr=/tmp/err.log \
    --terminate-running-process <UDID> <번들ID>

# 계측을 환경변수로 켠다 — SIMCTL_CHILD_ 접두사가 앱 환경으로 전달된다
SIMCTL_CHILD_PERF=1 xcrun simctl launch --console-pty <UDID> <번들ID>

# 진단 수집
xcrun simctl diagnose

# 캐시까지 지운 첫 실행 조건
xcrun simctl shutdown all && xcrun simctl boot <UDID> && xcrun simctl bootstatus <UDID>
xcrun simctl uninstall <UDID> <번들ID>
```

---

## 2. 실기기에서 뽑기 — `devicectl`

```sh
# 계측을 켜고 띄운다 — DEVICECTL_CHILD_ 접두사가 앱 환경으로 전달된다
DEVICECTL_CHILD_PERF=1 xcrun devicectl device process launch \
    --device <Identifier> <번들ID>

# JSON 으로 직접 주입 (이쪽을 쓰면 DEVICECTL_CHILD_ 는 무시된다)
xcrun devicectl device process launch --device <Identifier> -e '{"PERF":"1"}' <번들ID>
```

**실기기에서는 콘솔 스트리밍에 기대지 않는다.** 계측을 파일로 쓰고 꺼낸다.

```sh
# 컨테이너에 무엇이 있는지                                 [확인함 — 453개 나열]
xcrun devicectl device info files --device <Identifier> \
    --domain-type appDataContainer --domain-identifier <번들ID> --recurse

# 하위 디렉토리만                                         [확인함]
#   빈 디렉토리는 "0 files:" 를 낸다. 실패가 아니다
xcrun devicectl device info files --device <Identifier> \
    --domain-type appDataContainer --domain-identifier <번들ID> --subdirectory Documents

# 앱이 쓴 파일을 꺼낸다                                    [확인함 — 31바이트 그대로 회수]
xcrun devicectl device copy from --device <Identifier> \
    --domain-type appDataContainer --domain-identifier <번들ID> \
    --source Documents/perf.log --destination ./perf.log

# 내 공간에 넣고 빼기 (왕복 검증용)                         [확인함 — 내용 그대로]
xcrun devicectl device copy to   --device <Identifier> --domain-type temporary \
    --domain-identifier <임의문자열> --source ./x.log --destination x.log
xcrun devicectl device copy from --device <Identifier> --domain-type temporary \
    --domain-identifier <임의문자열> --source x.log --destination ./y.log
```

### 실기기에서만 만들 수 있는 조건

```sh
# 메모리 압박 — 캐시가 비워지는 경로를 재현한다
xcrun devicectl device process sendMemoryWarning --device <Identifier> <pid 또는 번들ID>

# 백그라운드 전환
xcrun devicectl device process suspend --device <Identifier> ...
xcrun devicectl device process resume  --device <Identifier> ...

# 화면 방향 (get / rotate / set)
xcrun devicectl device orientation get --device <Identifier>

# 화면 배율·크기 — 셀 크기 계산의 전제다                    [확인함]
xcrun devicectl device info displays --device <Identifier>
#   → bounds · pointScale · currentOrientation
```

**위 셋(`sendMemoryWarning`·`suspend`/`resume`·`orientation set`)은 실행해 보지 않았다.**
옵션 표면만 확인했다. 쓸 때 동작을 먼저 확인한다.

### 터치 입력은 없다

`devicectl` 에 `tap`·`swipe`·`gesture` 가 **0건**이다.
실기기 UI 자동화는 **`devicectl`(상태 제어) + XCUITest(입력)** 조합이다.
시뮬레이터에서 `axe` 로 하던 것을 실기기에서 그대로 할 수 없다.

---

## 3. 크래시 로그 가져오기

**실기기가 기준이다.** 시뮬레이터에서 안 죽는 크래시가 실기기에서 죽는다 —
써멀·메모리 압박·실제 네트워크 지연이 시뮬레이터에 없다.

```sh
# 맥에서 난 것 (시뮬레이터 포함)
ls -t ~/Library/Logs/DiagnosticReports/*.ips | head -5

# 실기기 목록                                             [확인함 — .ips 321개]
xcrun devicectl device info files --device <Identifier> --domain-type systemCrashLogs

# 특정 로그를 꺼낸다                                       [확인함 — 245KB 회수]
xcrun devicectl device copy from --device <Identifier> --domain-type systemCrashLogs \
    --source <파일명>.ips --destination ./crash.ips

# 전체 진단 아카이브 (느리고 크다 — 실행해 보지 않았다)
xcrun devicectl device sysdiagnose --device <Identifier>
```

---

## 4. `.ips` 읽기 — JSON 문서 **두 개**다

첫 줄이 헤더, 그 뒤가 본문이다. **한 덩어리로 파싱하면 실패한다.**

```python
raw = open(path, encoding='utf-8').read().split('\n', 1)
header = json.loads(raw[0])   # bug_type, os_version, timestamp, incident_id
body   = json.loads(raw[1])   # 리포트 종류마다 구조가 다르다
```

**`bug_type` 이 리포트 종류를 가른다.** 신호를 읽기 전에 이걸 먼저 본다 —
종류가 다르면 볼 필드가 아예 다르다.

확인한 값은 `298` = JetsamEvent, `309` = Analytics 두 개뿐이다.
**전체 대응표는 확인하지 않았으므로 필드를 읽어서 판단한다.**

---

## 5. JetsamEvent — 메모리 강제 종료

**메모리 부족 종료는 크래시가 아니다.** 크래시 리포트가 안 남고 `JetsamEvent` 로 남는다.
"갑자기 앱이 사라진다", "백그라운드 갔다 오면 처음부터 시작한다" 가 이 증상이다.

**계측 코드 없이 실기기 메모리 사용량을 알 수 있다.** 그 시점 기기 전체의
프로세스별 현황이 들어 있기 때문이다.

```sh
xcrun devicectl device info files --device <Identifier> --domain-type systemCrashLogs \
    | grep JetsamEvent
```

```python
body = json.loads(open('jetsam.ips').read().split('\n', 1)[1])
procs = body['processes']

# 실제로 종료된 것
killed = [p for p in procs if p.get('reason')]
#   예: reason=per-process-limit  rpages=1408  priority=0

# 메모리 사용 상위 (rpages 는 4KB 페이지)
for p in sorted(procs, key=lambda x: x.get('rpages') or 0, reverse=True)[:5]:
    print(p['name'], (p.get('rpages') or 0) * 4 / 1024, 'MB')
```

| 필드 | 뜻 |
|---|---|
| `reason` | 종료 사유. `per-process-limit` 은 그 앱이 자기 상한을 넘은 것 |
| `rpages` | 상주 페이지 수. **× 4KB = 실사용 메모리** |
| `priority` | 낮을수록 먼저 죽는다. 백그라운드 앱이 낮다 |
| `lifetimeMax` | 그 프로세스가 살아 있는 동안의 최대 사용량 |

**내 앱이 `killed` 에 없어도 `rpages` 상위에 있으면 위험 신호다.**
기기 메모리가 빠듯할 때 다음 차례가 된다.

이 수치가 계측값보다 나은 점이 있다. **실기기·실사용 중에 찍힌 값**이라는 것이다.
계측으로 재는 값은 내 조작 시나리오 안의 값이고, 이것은 사용자가 실제로 쓰던 상태다.

**확인함** — 실기기에서 `JetsamEvent` 7건을 찾아 하나(245KB)를 회수하고,
`processes` 437개와 종료된 1건(`reason=per-process-limit`)을 읽는 것까지 돌렸다.

---

## 6. 테스트에서 뽑기

**`print` 는 `xcodebuild test` 표준 출력에 섞여 나오지 않는다.** 결과 번들에서 꺼낸다.

```sh
xcodebuild test -workspace App.xcworkspace -scheme App \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -resultBundlePath /tmp/res.xcresult

xcrun xcresulttool get log --path /tmp/res.xcresult --type console | grep '\[PERF\]'
```

`--type` 은 `build` / `action` / `console` 세 개고, 테스트 콘솔 출력은 `console` 이다.

```sh
# 실제 실행 개수
xcodebuild test ... 2>&1 | grep 'Test run with'
```

**테스트 파일을 새로 만들었으면 프로젝트를 재생성한다.** 프로젝트 생성 도구를 쓰는
저장소에서 파일만 추가하면 타깃에 안 붙어서 **조용히 실행되지 않는다.**
개수를 눈으로 확인한다.
