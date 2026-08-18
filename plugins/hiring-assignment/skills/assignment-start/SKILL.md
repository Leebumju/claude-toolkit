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
