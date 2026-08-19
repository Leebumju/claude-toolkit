---
name: assignment-start
description: 과제를 받은 직후 첫 30분에 쓴다. 사용자가 과제 요구사항이나 API 스펙을 붙여넣으며 "과제 시작", "이거 받았어", "시작하자" 라고 할 때 사용한다. 요구사항을 실패 케이스까지 포함한 목록으로 번역하고, 템플릿 도메인을 갈아끼우고, 남은 시간을 배분한다.
argument-hint: "[과제 요구사항 원문 · API 스펙. 길면 파일 경로]"
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# 과제 시작 (첫 30분)

시간 제한이 걸린 과제의 시작 절차다. **여기서 30분을 쓰면 나머지가 순서대로 풀리고,
여기를 건너뛰면 마지막 한 시간에 에러 처리와 README 가 통째로 빠진다.**

미리 만들어 둔 **뼈대 저장소**가 있으면 시작 전에 그 저장소의 계획 문서를 읽는다.
무엇이 들어 있고 무엇이 일부러 비어 있는지를 먼저 파악해야 뭘 지울지 정할 수 있다.
뼈대가 없으면 이 단계를 건너뛰고 1절부터 간다.

## 어떻게 쓰나 — 실제 흐름

```
사용자: "과제 받았어" + 요구사항 원문 / API 스펙
   │
   ├─ 0단계  마감 시각 · 제출 방식 · UI 프레임워크 · AI 언급을 묻는다 ─▶ 답을 받는다
   │          답에 따라 구조가 달라진다. 추측으로 채우지 않는다          ■ 여기서 멈춘다
   │
   ├─ 1단계  요구사항을 화면 · 상태 · 실패 케이스 세 목록으로 옮긴다
   │          추적되지 않는 파일에 적는다 (→ 재개 지점)
   │
   ├─ 2단계  구조를 정하고, 2-1 에서 지울 파일 목록을 같이 보여준다 ──▶ 사용자가 승인
   │          "뼈대 그대로 + 페이징 · 이미지 삭제"                     ■ 지우기 전에 멈춘다
   │
   ├─ 2-1단계 안 쓰는 것을 지운다 → 컴파일러가 가리키는 네 곳을 고친다
   │
   ├─ 3단계  도메인을 갈아끼운다
   │          perl 치환 → git mv → `git grep -nP` 로 잔재 0건 확인
   │
   ├─ 4단계  API 를 붙인다 — `…Client+Live.swift` 하나만 고친다
   │
   ├─ 5단계  남은 시간을 구간으로 배분해 적어 둔다
   │
   ├─ 6단계  첫 커밋 ─────────────────────────────────────────▶ 사용자가 커밋한다
   │          템플릿을 썼다는 사실을 메시지에 남긴다                   ■ 커밋은 승인 뒤에
   │
   └─ 7단계  제출용 README 를 덮어써 세운다
              이후 판단이 갈릴 때마다 그 자리에 한 줄씩
```

**멈추는 지점이 셋이다.** 0단계의 네 가지 답을 받기 전, **파일을 지우기 전(2-1)**, 커밋 전.

2단계 뒤에 멈추는 이유는 그 뒤가 되돌리기 어렵기 때문이다. 구조 결정과 삭제는 붙어 있고,
지운 뒤에 요구사항을 다시 읽어 "그거 필요했다" 가 되면 3단계 리네임까지 되돌려야 한다.
**지울 목록을 먼저 보여주고 승인을 받는다.**

### 요구사항 체크리스트는 파일로 남긴다 — 재개 지점

`.claude/assignment/checklist.md` 에 적는다. **추적되는 경로에 두지 않는다.** `.gitignore` 에 `.claude/` 가 있는지 먼저 확인한다
(`git check-ignore -q .claude/x && echo 무시됨`). 없으면 먼저 추가한다 — 없으면 작업 파일이 커밋 후보로 뜬다.
제출물에 작업 메모가 섞이면 그것도 채점 대상이 된다 — 뼈대의 `docs/PLAN.md` 를 제출 전에
지우는 것과 같은 이유다.

제한 시간이 긴 과제는 대화가 여러 번 끊긴다. 끊긴 뒤 기억으로 이어가면 1단계에서 뽑은
실패 케이스가 조용히 사라지고, 그게 그대로 테스트 누락과 README 공백이 된다.
**끊기면 이 파일부터 읽고 재개한다.**

```markdown
## 확인한 것 (0단계)
마감 <시각> / 제출 <저장소|압축> / UI <지정 없음|UIKit> / AI 언급 <있음|없음>

## 화면
- [ ] 목록
- [ ] 상세

## 상태 (화면마다)
- [ ] 로딩 · 빈 · 에러 · 정상

## 실패 케이스 — 그대로 테스트 목록이 된다
- [ ] 서버 500
- [ ] 빈 배열
- [ ] 페이징 중 실패
- [ ] 화면 이탈
- [ ] 중복 탭
- [ ] 오프라인

## 구조 결정 (2단계, 승인받은 내용)
뼈대 그대로 / 지운 것: 페이징 · 로컬 저장

## 진행
- [x] 0 확인   - [x] 1 목록   - [x] 2 구조 승인   - [x] 2-1 삭제
- [ ] 3 도메인 리네임        ← 여기서 멈췄다
- [ ] 4 API   - [ ] 5 시간 배분   - [ ] 6 첫 커밋   - [ ] 7 README

## 판단이 갈린 순간 (README 재료)
- <시각> ...
```

### 다른 절차로 넘기는 지점

**아래는 지켜야 할 원칙이고, 같은 이름의 스킬은 그 원칙을 절차로 풀어놓은 것이다.**
스킬이 설치돼 있으면 `Skill` 로 부르고, **없으면 원칙만 지키고 그대로 진행한다.**

| 이런 게 나오면 | 지킬 원칙 | 절차가 있는 스킬 |
|---|---|---|
| 제출로 넘어간다 | 내 머신에서 도는 것은 증거가 아니다 — clean clone 에서 확인한다 | `assignment-submit` |
| 이만하면 되는지 스스로 판단이 안 선다 | 평가는 이 대화를 보지 못하는 쪽에 맡긴다 | `assignment-critique` |
| 성능을 요구사항에서 봤거나 README 에 개선을 쓰려 한다 | 수치 없이 빨라졌다고 쓰지 않는다 | `ios-measure:measure-ios` |
| 뼈대 없이 시작해서 모듈 경계를 새로 세운다 | 경계는 위반이 컴파일되지 않는 형태로 세운다 | `ios-modernize:modularize-ios` |
| UIKit 지정이라 기존 화면 코드를 옮겨야 한다 | 옮기기 전에 현재 동작을 적고 옮긴 뒤 대조한다 | `ios-modernize:legacy-port` |

같은 플러그인 안의 스킬은 이름 그대로 부르고, 다른 플러그인은 `플러그인:스킬` 형식이다.
**호출에 실패하면 원칙만 적용하고 계속 간다.** 과제 중에 스킬을 고치느라 시간을 쓰지 않는다.

---

## 0. 먼저 확인할 것 — 사용자에게 묻는다

요구사항에 안 적혀 있으면 추측하지 말고 묻는다. 답에 따라 구조가 달라진다.

- 제출 마감 시각 (시작 시각 + 제한 시간)
- 제출 방식 — 저장소 링크인지 압축 파일인지
- UI 프레임워크 지정이 있는지 (UIKit 지정이면 화면 계층을 새로 짜야 한다)
- AI 사용에 대한 언급이 있는지

## 1. 요구사항을 목록으로 번역한다 (10분)

원문을 그대로 두지 말고 세 개의 목록으로 옮긴다. **세 번째가 점수가 갈리는 자리다.**

```
화면      — 목록 / 상세 / 검색 …
상태      — 각 화면의 로딩 · 빈 · 에러 · 정상
실패 케이스 — 서버 500 / 빈 배열 / 페이징 중 실패 / 화면 이탈 / 중복 탭 / 오프라인
```

실패 케이스 목록이 그대로 **테스트 목록**이 되고 **Example 앱 시나리오**가 된다.
뼈대에 이미 다섯 개가 있으므로 과제 고유의 것만 더한다.

## 2. 구조를 정한다 (5분)

기본은 **뼈대 그대로** 간다. 세팅 비용이 0 이므로 줄일 이유가 없다.
아래에 해당할 때만 손댄다.

| 요구사항 | 대응 |
|---|---|
| 저장소가 SwiftData/Realm 으로 지정됨 | `storage/swiftdata` 브랜치에서 가져오거나 Core 에 구현 하나 추가 |
| UIKit 지정 | Feature 를 새로 짠다. Domain·Core 는 그대로 쓴다 |
| 화면이 하나뿐 | 그대로 둔다. 모듈을 합치는 게 더 큰 작업이다 |
| 네비게이션 필요 | **이제 짠다.** 화면 구조가 정해졌으므로 |

## 2-1. 안 쓰는 것을 지운다 (5분) — 리네임보다 먼저

**뼈대는 목록 화면을 전제로 만들어져 있다.** 과제가 목록이 아니면 그 부분은 전부 죽은
코드이고, 남겨 두면 "안 쓰는 코드가 있다" 로 감점된다. 리네임 전에 지워야 지울 양이 줄고
리네임 결과도 깨끗해진다.

요구사항에 없으면 지운다. 애매하면 지운다 — 필요해지면 그때 다시 짜는 게 싸다.

| 과제에 없는 것 | 지울 파일 |
|---|---|
| 페이징 | `Domain/Models/PagingState.swift` · `Domain/Models/Page.swift` · `Domain/Tests/PagingStateTests.swift` |
| 목록 이미지 | `Domain/Clients/ImageClient.swift` · `Core/Sources/Image/` · `Core/Tests/ImageLoaderTests.swift` · `Feature/Sources/Shared/RemoteImage.swift` |
| 목록 화면 자체 | `Feature/Sources/ItemList/` · `Feature/Tests/ItemListTests.swift` |
| 로컬 저장 | `Domain/Local/` · `Core/Sources/Local/` |

지우고 나면 **이 네 곳이 따라온다.** 컴파일러가 순서대로 알려 주므로 그대로 고치면 된다.

- `Domain/Clients/ItemClient.swift` — 페이징을 뺐으면 `page(cursor:)` 시그니처를 바꾼다
- `Core/Sources/Remote/…Client+Live.swift` — 위에 맞춘다
- `Feature/Sources/Preview/PreviewSupport.swift` — 시나리오를 과제의 실패 케이스로 다시 쓴다
- `Feature/Example/FeatureExampleApp.swift` · `App/Sources/AssignmentKitApp.swift` — 루트 화면 교체

**남는 것** — 이건 어떤 과제에도 쓴다. 지우지 않는다.

```
Tuist 4계층 · 계층 경계 린트 · 커밋 훅 · CI · Example 앱 골격
HTTPTransport · DataErrorMapper · DataError · StateViews(로딩/빈/에러) · App 조립
```

## 3. 도메인을 갈아끼운다 (10분)

템플릿의 `Item` 을 과제 도메인으로 바꾼다. 이름이 남아 있으면 채점자가 바로 알아본다.

**단어 경계를 지켜야 한다.** `URLQueryItem` · `queryItems` 가 같이 바뀌면 빌드가 깨진다.

> **`sed` 를 쓰지 마라.** macOS 의 BSD `sed` 는 `\b` 를 지원하지 않아 **아무것도 바꾸지 않고
> 조용히 성공한다.** `git grep -E '\b…'` 도 같은 이유로 0건을 반환하므로, 안 바뀐 것을
> 안 잡히는 grep 으로 확인하고 통과했다고 착각하게 된다. 실제로 그렇게 한 번 속았다.
> **치환은 `perl`, 확인은 `git grep -P`.**
>
> ```
> sed -E  's/\bItem/Photo/g'   →  Item ItemClient URLQueryItem   (그대로)
> perl -pe 's/\bItem/Photo/g'  →  Photo PhotoClient URLQueryItem  (정상)
> ```

```sh
cd <뼈대를 복제한 경로>
NEW=Movie                     # 과제 도메인. 첫 글자 대문자
new=movie

git grep -lP '\b(Item|item)' -- '*.swift' \
  | xargs perl -pi -e "s/\bItem/$NEW/g; s/\bitem/$new/g"

# 파일·디렉토리 이름도 바꾼다
git mv Projects/Domain/Sources/Models/Item.swift        "Projects/Domain/Sources/Models/$NEW.swift"
git mv Projects/Domain/Sources/Clients/ItemClient.swift "Projects/Domain/Sources/Clients/${NEW}Client.swift"
git mv Projects/Core/Sources/Remote/ItemClient+Live.swift "Projects/Core/Sources/Remote/${NEW}Client+Live.swift"
git mv Projects/Feature/Sources/ItemList "Projects/Feature/Sources/${NEW}List"
git mv "Projects/Feature/Sources/${NEW}List/ItemList.swift"     "Projects/Feature/Sources/${NEW}List/${NEW}List.swift"
git mv "Projects/Feature/Sources/${NEW}List/ItemListView.swift" "Projects/Feature/Sources/${NEW}List/${NEW}ListView.swift"
git mv Projects/Feature/Tests/ItemListTests.swift "Projects/Feature/Tests/${NEW}ListTests.swift"

tuist generate --no-open
```

바꾼 뒤 **반드시 빌드와 테스트를 돌린다.** 여기서 안 깨진 걸 확인하고 커밋한다.

```sh
git grep -nP '\b(Item|item)' -- '*.swift'   # 남은 것이 없어야 한다. -E 가 아니라 -P
```

> 2026-08-17 에 실제 공개 API(picsum.photos)로 끝까지 돌려 확인했다 — 리네임 → DTO 교체 →
> 빌드 → 시뮬레이터에서 실제 데이터·이미지 렌더 → 스크롤 페이징까지.

모델 필드도 과제에 맞게 바꾼다. `title` / `subtitle` / `imageURL` 은 템플릿의 이름이다.

**모델의 ID 타입을 바꾸면 두 곳이 따라온다** (서버 id 가 String 인 경우가 흔하다).
컴파일러가 잡아 주므로 순서대로 고치면 된다.

- `Core/Sources/Remote/…Client+Live.swift` — DTO 매핑. 어차피 다시 쓰는 파일이다
- `Feature/Sources/Preview/PreviewSupport.swift` — Mock 데이터 생성기

Domain 의 다른 타입과 Feature 화면 코드는 안 바뀐다. `FavoriteStore` 는 `Photo.ID` 로
받으므로 그대로 돈다.

## 4. API 를 붙인다 (30분)

`Core/Sources/Remote/…Client+Live.swift` 하나만 고친다. DTO 는 이 파일 밖으로 내보내지 않는다.

- 서버가 커서가 아니라 page/offset 을 쓰면 여기서 흡수한다. `Page` 타입은 그대로 둔다.
  페이지 번호를 커서로 삼으면 도메인은 아무것도 몰라도 된다
- **다음 페이지 표식을 안 주는 서버가 많다.** 받은 개수가 요청한 개수보다 적으면 끝으로 본다
  (`response.count < pageSize ? nil : page + 1`)
- **최상위가 배열인 응답이 흔하다.** 템플릿의 `…PageDTO` 를 버리고 `[…DTO]` 로 바로 받는다
- null 이 오는 필드의 기본값을 여기서 정한다. 화면이 옵셔널을 다루게 두면 같은 분기가 반복된다
- base URL 은 `Projects/App/Sources/AppConfiguration.swift` 한 줄

## 5. 시간을 배분한다

남은 시간을 적어 두고 시작한다. 8시간 기준 배분이며, 제한 시간이 다르면 비율로 줄인다.

| 구간 | 할 일 |
|---|---|
| 0:00–0:30 | 이 절차 (1~3단계) |
| 0:30–1:00 | API 연결 |
| 1:00–3:00 | 목록 화면. 세 상태 포함 |
| 3:00–4:30 | 상세 화면 + 로컬 저장 |
| 4:30–5:30 | 실패 경로 테스트 |
| 5:30–6:00 | 직접 돌려 가장자리 점검 — 기내 모드 · 500 강제 · 빈 배열 · 스크롤 중 이탈 |
| 6:00–7:00 | README 세 칸 |
| 7:00–7:30 | 커밋 정리 |
| 7:30–8:00 | `/assignment-submit` — clean clone 검증 |

**마지막 30분을 줄이지 않는다.** 내 머신에서 도는 것은 증거가 아니다.

## 6. 첫 커밋

템플릿을 썼다는 사실을 첫 커밋에 남긴다. 숨기면 히스토리에서 티가 나고,
밝히면 자기 표준이 있는 사람으로 읽힌다.

```
chore: 프로젝트 셋업 (개인 템플릿 기반)
```

README 에도 한 줄 넣는다 — "프로젝트 셋업은 평소 사용하는 개인 템플릿을 기반으로 했고,
과제 요구사항에 맞춰 도메인과 모듈 구성을 조정했습니다."

## 7. 제출용 README 를 먼저 세운다

**`docs/SUBMISSION-README.md` 를 `README.md` 로 덮어쓰고 시작한다.** 마지막 한 시간에
빈 문서를 마주하지 않기 위해서다. 채점자 동선(30초 안에 확인할 것 → 범위 판단 → 구조 →
테스트 → 일부러 안 한 것 → AI 검증 → 시간이 더 있으면) 이 이미 짜여 있고, 사실인 항목은
그대로 쓸 수 있다.

작업하면서 **판단이 갈렸던 순간마다 그 자리에 한 줄씩 적어 둔다.** 나중에 기억으로
복원하려 하면 일반론밖에 안 나온다.

특히 **"AI 를 어디에 썼고 무엇을 버렸는가"** 칸은 과제 중에 생긴 사례로 채운다.
받은 코드를 그대로 안 쓴 지점, 규칙이 실제로 도는지 확인한 지점, 추측 대신 값을 찍어
확인한 지점. 채점 축이 결과물에서 과정으로 옮겨간 자리라 여기가 변별이 된다.

## 지금 하지 않는 것

- **기능을 늘리는 것.** 요구된 것이 전부 동작하는 게 먼저다. 하나라도 미완이면 나머지가 다 죽는다
- **구조를 새로 고민하는 것.** 뼈대를 쓰기로 했으면 쓴다
- **접근성 전면 적용 · 다크모드 · 애니메이션.** README 의 "시간이 더 있으면" 에 이름을 적는다
- **`docs/PLAN.md` 를 남겨 두는 것.** 제출 전에 지운다

---

## 보고 형식

첫 30분이 끝나면 이 모양으로 보고한다. 다음 대화에서 이것만 보고 이어갈 수 있어야 한다.

```
## 확인한 것 (0단계)
마감 <시각, 남은 시간> / 제출 <저장소|압축> / UI <지정> / AI 언급 <있음|없음>

## 요구사항
체크리스트: .claude/assignment/checklist.md
화면 <n>개 · 상태 <n>종 · 실패 케이스 <n>개
요구사항에 안 적혀 있어 물어봐야 하는 것: ...

## 구조
뼈대 그대로 | 바꾼 것 <저장소 구현 추가 · Feature 재작성 …>

## 지운 것 (2-1)
파일·디렉토리 목록. 따라서 고친 곳도 같이

## 도메인
Item → <도메인>. `git grep -nP` 잔재 <n>건
빌드 <통과|실패|미실행> / 테스트 <통과 n·실패 n|미실행>

## 시간 배분
| 구간 | 할 일 |  ← 남은 시간에 맞춘 실제 시각으로

## 첫 커밋
메시지 후보 + 스테이지에 들어갈 파일 수

## 다음에 바로 할 것
한 줄
```

**돌리지 않은 것을 돌렸다고 적지 않는다.** 빌드·테스트를 아직 안 돌렸으면 "미실행" 으로
남긴다. 남은 시간을 실제 시각으로 적는다 — "약 7시간" 은 다음 대화에서 쓸 수 없다.
