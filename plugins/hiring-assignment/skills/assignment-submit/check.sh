#!/bin/sh
#
# 과제 제출 전 기계 검사.
#
# 핵심은 clean clone 이다. 내 작업 디렉토리에서 도는 것은 아무 증거가 아니다 —
# 추적되지 않는 파일에 기대고 있으면 채점자 머신에서 열리지 않는다.
#
# 사용법: check.sh <저장소경로> <앱스킴> [테스트스킴...]
#
# 차단하지 않는다. 발견한 것을 출력하고 종료 코드는 항상 0 이다.

REPO="${1:-$(pwd)}"
APP_SCHEME="$2"
shift 2 2>/dev/null
TEST_SCHEMES="$*"

say() { printf '\n=== %s ===\n' "$1"; }
found() { printf '  ! %s\n' "$1"; }
ok() { printf '  · %s\n' "$1"; }

cd "$REPO" 2>/dev/null || { echo "저장소를 못 찾음: $REPO"; exit 0; }
REPO="$(pwd)"
echo "저장소: $REPO"

# ── 1. 작업 트리 ────────────────────────────────────────────
say "작업 트리"
DIRTY=$(git status --porcelain 2>/dev/null)
if [ -n "$DIRTY" ]; then
    found "커밋되지 않은 변경이 있다. clean clone 검사는 이것들 없이 돈다"
    printf '%s\n' "$DIRTY" | sed 's/^/      /'
else
    ok "깨끗함"
fi

# ── 2. 추적되면 안 되는 것 ──────────────────────────────────
say "추적되는 파일 중 위험한 것"
BAD=$(git ls-files | grep -E '\.(xcodeproj|xcworkspace)/|^Derived/|/Derived/|\.p12$|\.mobileprovision$|xcuserdata|\.env$' || true)
if [ -n "$BAD" ]; then
    found "생성물·인증서로 보이는 파일이 추적된다"
    printf '%s\n' "$BAD" | sed 's/^/      /' | head -20
else
    ok "생성물·인증서 없음"
fi

SECRETS=$(git grep -nIE '(?i)(api_?key|secret|access_?token|client_?secret|password)[[:space:]]*[:=][[:space:]]*"[^"]{8,}"' -- '*.swift' '*.yml' '*.yaml' '*.plist' 2>/dev/null || true)
if [ -n "$SECRETS" ]; then
    found "비밀값으로 보이는 문자열"
    printf '%s\n' "$SECRETS" | sed 's/^/      /' | head -10
else
    ok "비밀값 패턴 없음"
fi

# ── 3. 잔재 후보 ────────────────────────────────────────────
say "잔재 후보 (판단은 사람이 한다)"
for PATTERN in 'example\.com' 'preview://' 'TODO' 'FIXME'; do
    HITS=$(git grep -nI "$PATTERN" -- '*.swift' 2>/dev/null | head -8 || true)
    if [ -n "$HITS" ]; then
        found "$PATTERN"
        printf '%s\n' "$HITS" | sed 's/^/      /'
    fi
done

INTERNAL=$(git ls-files | grep -E 'docs/PLAN\.md|docs/SUBMISSION-README\.md|CLAUDE\.md|\.claude/' || true)
if [ -n "$INTERNAL" ]; then
    found "내부 작업 문서가 추적된다 — 제출물에 들어간다"
    printf '%s\n' "$INTERNAL" | sed 's/^/      /'
fi

# ── 4. README 세 칸 ─────────────────────────────────────────
say "README"
if [ -f README.md ]; then
    PLACEHOLDER=$(grep -n '\[\[' README.md || true)
    if [ -n "$PLACEHOLDER" ]; then
        found "채우지 않은 자리가 남아 있다"
        printf '%s\n' "$PLACEHOLDER" | sed 's/^/      /' | head -10
    else
        ok "빈 자리 없음"
    fi
    grep -q '30초' README.md \
        && ok "채점자 동선 안내 있음" \
        || found "'30초 안에 확인하실 것' 같은 리뷰어 동선 안내가 없다"
    for SECTION in '왜' '안 한' '시간이 더'; do
        if grep -q "$SECTION" README.md; then
            ok "'$SECTION' 로 보이는 항목 있음"
        else
            found "'$SECTION ...' 항목이 안 보인다"
        fi
    done
    head -5 README.md | grep -qiE 'tuist|xcodebuild|open |실행|설치' \
        && ok "첫 5줄에 실행 방법으로 보이는 내용 있음" \
        || found "첫 화면에 실행 방법이 안 보인다"
else
    found "README.md 가 없다"
fi

# ── 5. 커밋 히스토리 ────────────────────────────────────────
say "커밋 히스토리"
COUNT=$(git rev-list --count HEAD 2>/dev/null || echo 0)
echo "  커밋 수: $COUNT"
[ "$COUNT" -le 1 ] && found "커밋이 하나뿐이다. 기능 단위로 쪼개져 있어야 한다"
git log --format='      %h %s' | head -15
FIRST=$(git log --reverse --format='%s%n%b' | head -20 | grep -icE '템플릿|template' || true)
[ "$FIRST" -eq 0 ] && found "템플릿을 썼다면 첫 커밋에 그 사실이 있어야 한다 (확인 필요)"

# ── 5b. zip 에 섞여 나갈 파일 ───────────────────────────────
#
# .gitignore 는 zip 을 막지 못한다. 폴더째 압축하면 추적되지 않는 파일도 함께 들어간다.
# 작업용 메모·요구사항 정리·키가 그렇게 나간다.
say "압축하면 함께 들어갈 무시된 파일"
IGNORED=$(git status --short --ignored 2>/dev/null | grep '^!!' | sed 's/^!! //' || true)
if [ -n "$IGNORED" ]; then
    echo "$IGNORED" | while IFS= read -r f; do
        found "무시되지만 파일로 존재: $f  ← zip -x 로 뺄지 판단할 것"
    done
else
    ok "무시된 파일이 없다"
fi

# ── 5c. 저장소 서식을 내 도구가 바꿔놓지 않았는지 ────────────
#
# 실전에서 당한 것: PostToolUse 포매터가 trailing comma 를 넣었고 원본은 그 서식을
# 쓰지 않았다. 목표는 경고 0이 아니라 **원본과 동수**다.
say "린트 경고 수 — 원본 대비"
if command -v swiftlint >/dev/null 2>&1; then
    NOW=$(swiftlint --quiet 2>/dev/null | grep -c warning || echo 0)
    echo "  지금: ${NOW}건"
    BASE_REF=$(git log --format=%H | tail -1)
    if [ -n "$(git status --porcelain)" ]; then
        found "작업 트리가 깨끗하지 않아 원본과 비교하지 않았다 (커밋/stash 후 다시 돌릴 것)"
    else
        git stash list >/dev/null 2>&1
        if git checkout -q "$BASE_REF" 2>/dev/null; then
            BASE=$(swiftlint --quiet 2>/dev/null | grep -c warning || echo 0)
            git checkout -q - 2>/dev/null
            echo "  원본($(echo "$BASE_REF" | cut -c1-7)): ${BASE}건"
            if [ "$NOW" -gt "$BASE" ]; then
                found "원본보다 $((NOW - BASE))건 늘었다. 어느 규칙인지 확인할 것:"
                echo "      swiftlint --quiet | grep -oE '\\([a-z_]+\\)\$' | sort | uniq -c | sort -rn"
                found "원본에 0건이던 규칙이 생겼으면 내 포매터가 넣은 것이다 — 되돌린다"
            else
                ok "원본보다 늘지 않았다"
            fi
        else
            found "원본 커밋 checkout 실패 — 비교를 건너뛴다"
        fi
    fi
else
    ok "SwiftLint 미설치 — 서식 비교를 건너뜀"
fi

# ── 5d. 문서가 주장하는 수치 ────────────────────────────────
#
# 실전에서 문서와 코드가 어긋난 것이 네 건이었고 원인은 하나였다 —
# **잰 뒤에 코드가 또 움직였다.** 그래서 제출 직전에 다시 잰다.
# 자동 대조는 하지 않는다(문장 형태가 너무 다양하다). 실측값과 문서의 수치를
# 나란히 출력해서 눈으로 대조하게 만든다.
say "문서 수치 — 실측값"
echo "  커밋 수:        $(git rev-list --count HEAD)"
DECLARED=$(grep -rhoE '@Test|func test[A-Za-z0-9_]*\(' --include='*.swift' . 2>/dev/null | wc -l | tr -d ' ')
echo "  테스트 선언 수: ${DECLARED}  (실행 수는 6단계 'Test run with' 출력을 볼 것)"
if command -v swiftlint >/dev/null 2>&1; then
    echo "  린트 경고:      $(swiftlint --quiet 2>/dev/null | grep -c warning || echo 0)건"
fi
echo "  Swift 파일/줄:  $(git ls-files '*.swift' | wc -l | tr -d ' ') 개 / $(git ls-files '*.swift' | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}') 줄"

say "문서에 적힌 수치가 든 줄 — 위 실측값과 대조할 것"
DOCS=$(git ls-files '*.md')
if [ -n "$DOCS" ]; then
    # shellcheck disable=SC2086
    # 마크다운 강조(**59개**)를 먼저 벗긴다. 안 벗기면 수치를 그냥 놓친다 —
    # 실전에서 README 의 "테스트 **59개**" 가 이 방식으로 검사를 빠져나갔고,
    # 실제 실행 수는 91개였다.
    for f in $DOCS; do
        sed 's/\*\*//g; s/`//g' "$f" | grep -nE '[0-9]+ *(개|건|줄|%|배|ms|초|명|회)' \
            | sed "s|^|  $f:|"
    done | head -40
    echo "  ── 40줄까지만 출력했다. 전부 보려면:"
    echo "     for f in \$(git ls-files '*.md'); do sed 's/\\*\\*//g' \$f | grep -nE '[0-9]+ *(개|건|줄|%|배)' | sed \"s|^|\$f:|\"; done"
else
    found "추적되는 .md 문서가 없다 — README 가 커밋되지 않았을 수 있다"
fi

say "문서가 주장하는 것 중 사람이 판단해야 하는 문장"
# shellcheck disable=SC2086
if [ -n "$DOCS" ]; then
    CLAIMS=$(grep -nE '전수|모든 커밋|전부 확인|100%|보장' $DOCS 2>/dev/null)
    if [ -n "$CLAIMS" ]; then
        found "다음 주장이 실제 검사 결과와 일치하는지 확인할 것:"
        echo "$CLAIMS" | head -15 | sed 's/^/      /'
    else
        ok "검증 불가한 강한 주장 없음"
    fi
fi

say "문서 내부 참조 (링크 + 평문 절 번호)"
python3 - "$@" <<'PY' 2>/dev/null || found "링크 검사를 건너뜀 (python3 없음)"
import re, subprocess, sys, os, unicodedata

docs = subprocess.run(['git','ls-files','*.md'], capture_output=True, text=True).stdout.split()
def slug(h):
    h = h.strip().lstrip('#').strip()
    h = re.sub(r'`|\*|_', '', h)
    h = re.sub(r'[^\w\s가-힣-]', '', h, flags=re.UNICODE)
    return h.strip().lower().replace(' ', '-')

anchors = {}
for d in docs:
    with open(d, encoding='utf-8') as f:
        anchors[d] = {slug(l) for l in f if l.startswith('#')}

bad = []
for d in docs:
    with open(d, encoding='utf-8') as f:
        for i, line in enumerate(f, 1):
            for text, target in re.findall(r'\[([^\]]*)\]\(([^)]+)\)', line):
                if target.startswith(('http://','https://','mailto:')):
                    continue
                path, _, frag = target.partition('#')
                tgt = os.path.normpath(os.path.join(os.path.dirname(d), path)) if path else d
                if path and not os.path.exists(tgt):
                    bad.append(f'{d}:{i}  파일 없음 → {target}')
                elif frag and tgt in anchors and slug(frag) not in anchors[tgt]:
                    bad.append(f'{d}:{i}  절 없음 → {target}   ({text})')

# 평문 절 참조(§5, §3-1). 마크다운 링크가 아니라 이 형태가 실전에서 깨졌다 —
# README 가 존재하지 않는 §14 를 가리키고 있었다. 링크 검사로는 안 잡힌다.
defined = set()
for d in docs:
    with open(d, encoding='utf-8') as f:
        for line in f:
            m = re.match(r'^#{2,4} *([0-9]+(?:-[0-9]+)?)\.?\s', line)
            if m:
                defined.add(m.group(1))

# 오탐을 걸러낸다. 오탐이 나오면 사람이 이 검사를 끄고, 끄면 진짜를 놓친다.
#   · 코드 펜스 안 — 예시로 적은 것이다
#   · 인라인 코드(`§14`) — 참조가 아니라 인용이다
#   · 같은 줄에 다른 문서를 명시한 경우(CLAUDE.md §9) — 외부 문서의 절이다
#   · <!-- ref-ignore --> 가 붙은 줄 — 남의 문서 절을 **서술**하는 산문은
#     기계가 참조와 구분할 수 없다. 그 두 경우만 손으로 표시한다
for d in docs:
    fenced = False
    with open(d, encoding='utf-8') as f:
        for i, line in enumerate(f, 1):
            if line.lstrip().startswith('```'):
                fenced = not fenced
                continue
            if fenced or 'ref-ignore' in line:
                continue
            # 외부 문서 표시는 **인라인 코드를 지우기 전에** 본다.
            # 순서를 바꾸면 `CLAUDE.md §9` 처럼 백틱에 싸인 경로가 먼저 지워져 오탐이 된다.
            if re.search(r'[\w/.~-]+\.md', line):
                continue
            stripped = re.sub(r'`[^`]*`', '', line)          # 인라인 코드 = 인용, 참조 아님
            for ref in re.findall(r'§ *([0-9]+(?:-[0-9]+)?)', stripped):
                if ref not in defined:
                    bad.append(f'{d}:{i}  § {ref} — 어느 문서에도 없는 절 번호')

if bad:
    print(f'  \033[31m✗\033[0m 깨진 참조 {len(bad)}건 — 읽는 순서 안내가 깨져 있으면 없는 것보다 나쁘다')
    for b in bad[:20]:
        print('      ' + b)
    print('      번호가 존재해도 **가리키는 내용이 맞는지**는 눈으로 볼 것 (기계가 못 잡는다)')
    sys.exit(0)
print('  \033[32m✓\033[0m 문서 내부 참조 이상 없음 (내용 일치는 미검증)')
PY

# ── 6. clean clone 빌드 ─────────────────────────────────────
say "clean clone 빌드"
if [ -z "$APP_SCHEME" ]; then
    found "앱 스킴을 안 넘겨서 빌드 검사를 건너뛴다: check.sh <경로> <앱스킴> [테스트스킴...]"
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
echo "  임시 클론: $TMP/clone"

if ! git clone -q "$REPO" "$TMP/clone" 2>&1; then
    found "clone 실패"
    exit 0
fi
cd "$TMP/clone" || exit 0

if [ -f Tuist.swift ] || [ -d Tuist ]; then
    echo "  tuist install..."
    tuist install >"$TMP/install.log" 2>&1 || { found "tuist install 실패"; tail -15 "$TMP/install.log" | sed 's/^/      /'; }
    echo "  tuist generate..."
    tuist generate --no-open >"$TMP/gen.log" 2>&1 || { found "tuist generate 실패"; tail -15 "$TMP/gen.log" | sed 's/^/      /'; exit 0; }
    ok "프로젝트 생성됨"
fi

WS=$(ls -d ./*.xcworkspace 2>/dev/null | head -1)
[ -z "$WS" ] && { found "xcworkspace 를 못 찾음"; exit 0; }

echo "  빌드: $APP_SCHEME"
if xcodebuild -workspace "$WS" -scheme "$APP_SCHEME" \
    -destination 'generic/platform=iOS Simulator' -skipMacroValidation build \
    >"$TMP/build.log" 2>&1; then
    ok "빌드 성공 ($APP_SCHEME)"
else
    found "빌드 실패 ($APP_SCHEME)"
    grep -E 'error:' "$TMP/build.log" | sort -u | head -15 | sed 's/^/      /'
fi

SIM=$(xcrun simctl list devices available --json 2>/dev/null \
    | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; print(next(v['name'] for ds in d.values() for v in ds if v['name'].startswith('iPhone')))" 2>/dev/null)

for SCHEME in $TEST_SCHEMES; do
    echo "  테스트: $SCHEME (${SIM:-시뮬레이터 미검출})"
    [ -z "$SIM" ] && { found "시뮬레이터를 못 찾아 테스트를 건너뜀"; continue; }
    if xcodebuild test -workspace "$WS" -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$SIM" -skipMacroValidation \
        >"$TMP/test-$SCHEME.log" 2>&1; then
        ok "테스트 통과 ($SCHEME)"
    else
        found "테스트 실패 ($SCHEME)"
        grep -E 'error:|✘|failed' "$TMP/test-$SCHEME.log" | sort -u | head -10 | sed 's/^/      /'
    fi
done

if command -v swiftlint >/dev/null 2>&1; then
    ERRORS=$(swiftlint lint --quiet --no-cache 2>&1 | grep -c 'error:')
    if [ "$ERRORS" -gt 0 ]; then
        found "린트 error $ERRORS 건"
        swiftlint lint --quiet --no-cache 2>&1 | grep 'error:' | head -10 | sed 's/^/      /'
    else
        ok "린트 error 0"
    fi
else
    found "SwiftLint 미설치 — 규칙 검사를 건너뜀"
fi

say "이 스크립트가 하지 않은 것"
echo "  · 커밋별 단독 빌드 — 순차 빌드라 오래 걸린다."
echo "    isolation: \"worktree\" 서브에이전트에 넘길 것 (SKILL.md 4단계)"
echo "  · 문서 수치의 **대조** — 실측값은 5d 에서 출력했다. 문장과 맞는지는 눈으로 볼 것"
echo "  · zip 규격(파일명·용량·.git 포함) — 안내 문서를 다시 읽을 것"

say "끝"
echo "  clean clone 에서 돌린 결과다. 여기서 통과하면 채점자 머신에서도 열린다."
exit 0
