#!/usr/bin/env bash
#
# SKILL.md 기계 검사. 사람이 판단할 것은 판단하지 않고, 확정적으로 틀린 것만 짚는다.
#
# 사용법: audit.sh <SKILL.md 경로 또는 스킬 루트 디렉토리>
#
# 차단하지 않는다. 종료 코드는 항상 0 이다 — 이 검사가 작업을 막으면 사람이 검사를 끈다.

set -uo pipefail

TARGET="${1:-.}"
RED=$'\033[31m'; GREEN=$'\033[32m'; YEL=$'\033[33m'; BOLD=$'\033[1m'; OFF=$'\033[0m'

say()   { printf '\n%s%s%s\n' "$BOLD" "$1" "$OFF"; }
bad()   { printf '  %s✗%s %s\n' "$RED" "$OFF" "$1"; }
warn()  { printf '  %s!%s %s\n' "$YEL" "$OFF" "$1"; }
ok()    { printf '  %s✓%s %s\n' "$GREEN" "$OFF" "$1"; }

# macOS 기본 bash 는 3.2 라 mapfile 이 없다. while-read 로 배열을 만든다.
FILES=()
if [ -d "$TARGET" ]; then
    while IFS= read -r line; do
        FILES+=("$line")
    done < <(find "$TARGET" -name SKILL.md | sort)
else
    FILES=("$TARGET")
fi

[ "${#FILES[@]}" -eq 0 ] && { echo "SKILL.md 를 찾지 못했다: $TARGET"; exit 0; }

for F in "${FILES[@]}"; do
    DIR=$(dirname "$F")
    DNAME=$(basename "$DIR")
    LINES=$(wc -l < "$F" | tr -d ' ')

    say "══ $DNAME  (${LINES}줄)"

    # ── 프론트매터 ────────────────────────────────────────────
    NAME=$(grep -m1 '^name:' "$F" | sed 's/^name: *//' | tr -d ' ')
    if [ -z "$NAME" ]; then
        bad "name 없음 — 스킬이 로드되지 않는다"
    elif [ "$NAME" != "$DNAME" ]; then
        bad "name 이 디렉토리와 다르다 (dir=$DNAME, name=$NAME) — 호출이 안 잡힌다"
    fi

    grep -q '^description:' "$F" || bad "description 없음 — 대화에서 이 스킬이 뜨지 않는다"
    grep -q '^allowed-tools:' "$F" || warn "allowed-tools 없음 — 도구가 제한되지 않는다"

    # description 안에 실제로 사용자가 쓸 말(따옴표 인용)이 있는가
    TRIGGERS=$(grep -m1 '^description:' "$F" | grep -oE '"[^"]+"' | wc -l | tr -d ' ')
    if [ "$TRIGGERS" -eq 0 ]; then
        bad "description 에 부르는 말이 없다 — 인용부호로 실제 사용자 표현을 넣을 것"
    else
        ok "부르는 말 ${TRIGGERS}개"
    fi

    # 읽기 전용을 주장하면서 쓰기 도구를 들고 있는가.
    #
    # "고치지 않는다" 를 패턴에 넣으면 안 된다 — "추측으로 고치지 않는다",
    # "분기를 지금 고치지 않는다" 같은 작업 지침까지 걸려서 오탐이 난다.
    # 읽기 전용 **선언**만 잡는다: description 에 있거나, 본문에 단정문으로 있는 것.
    if grep -m1 '^description:' "$F" | grep -qiE '읽기 전용|read-only' \
       || grep -qiE '읽기 전용(이다|입니다)|\*\*읽기 전용' "$F"; then
        if grep -m1 '^allowed-tools:' "$F" | grep -qE 'Edit|Write|NotebookEdit'; then
            bad "읽기 전용이라 적었는데 allowed-tools 에 Edit/Write 가 있다"
        else
            ok "읽기 전용 선언과 도구 목록이 일치"
        fi
    fi

    # ── 마크다운 구조 ─────────────────────────────────────────
    #
    # 대량 편집 뒤 조용히 깨지는 종류다. 코드블록 짝이 안 맞으면 그 뒤 문서 전체가
    # 코드로 렌더돼서 절차가 안 읽힌다. 사람 눈으로는 안 잡힌다.
    FENCE=$(grep -c '^```' "$F")
    if [ $((FENCE % 2)) -ne 0 ]; then
        bad "코드블록 짝이 안 맞는다 (\`\`\` ${FENCE}개) — 뒤쪽 문서 전체가 코드로 렌더된다"
    fi

    # ── 구조 ──────────────────────────────────────────────────
    # 단계 표기가 저장소마다 다르다: "## 1.", "### 1.", "## 1단계".
    # 하나만 세면 형식이 다른 스킬을 "절차가 없다" 고 오판한다.
    STEPS=$(grep -cE '^#{2,3} [0-9]+([.\ ]|단계)' "$F")
    [ "$STEPS" -gt 8 ] && warn "번호 붙은 단계 ${STEPS}개 — 8개를 넘으면 끝까지 읽히지 않는다"
    [ "$STEPS" -eq 0 ] && warn "번호 붙은 단계가 없다 — 절차가 아니라 설명서일 수 있다"

    for pat in '어떻게 쓰나|실제 흐름=실행 흐름' '멈추는 지점|여기서 멈춘다=멈추는 지점' '보고 형식|보고한다=보고 형식'; do
        key="${pat%%=*}"; label="${pat##*=}"
        grep -qE "$key" "$F" || bad "${label}이 없다"
    done

    grep -qE '실패하면|없으면 원칙|설치돼 있으면' "$F" || {
        grep -qE '스킬|Skill' "$F" && warn "다른 스킬을 가리키는데 폴백 문장이 없다"
    }

    grep -qE '재개|끊기면|이어서' "$F" || warn "재개 지점 안내가 없다 — 대화가 끊기면 기억으로 이어간다"

    # 줄 수만으로 판정하지 않는다. 300줄 기준은 근거 없이 정한 값이었고
    # 실측 분포와 맞지 않았다 — 실전 검증으로 근거가 붙으면 400줄이 정상이다.
    # 대신 **한 절이 전체의 25% 를 넘는지**를 본다. 그것이 쪼갤 선이다.
    if [ "$LINES" -gt 450 ]; then
        warn "${LINES}줄 — 450줄을 넘는다. 아래 절 크기를 함께 볼 것"
    fi
    # 절 크기는 **정보로만 낸다. 판정하지 않는다.**
    #
    # 세 가지 기준을 시도해 전부 오탐이 났다.
    #   · 줄 수 > 300      → 실측 근거가 붙으면 400줄이 정상이다. 전부 걸린다
    #   · 최대 절 > 25%    → 절이 적은 스킬은 한 절이 자연히 크다
    #   · 최대 절 > 평균×3 → "어떻게 쓰나"(흐름도)가 걸린다. 그건 정상이다
    #
    # 조회표와 절차를 코드 비중으로도 못 가른다 — 계측 코드 본문이 49%,
    # 진행 템플릿이 70%인데 둘 다 빼면 안 되는 것이다.
    # **판정은 사람이 한다.** 기계는 어디가 큰지만 보여준다.
    if [ "$LINES" -gt 400 ]; then
        say "  절 크기 (판정 아님 — 큰 절이 조회표인지 사람이 본다)"
        awk '
            /^## /{ if (prev != "") printf "      %4d줄  %s\n", NR - start, prev; prev = $0; start = NR }
            END { printf "      %4d줄  %s\n", NR - start, prev }
        ' "$F" | sort -rn | head -3
        echo "      → 명령 목록이면 참조 파일로 뺀다. 절차·근거면 그대로 둔다"
    fi

    # ── 무력한 문장 ───────────────────────────────────────────
    # 따옴표로 감싼 것은 "이렇게 쓰지 말라" 는 **인용**이다. 지시가 아니므로 뺀다.
    # (이 파일 자신이 그런 표를 갖고 있어서, 안 빼면 자기 자신을 오탐한다)
    WEAK=$(grep -nE '꼼꼼히|적절(히|한)|상황에 따라|알아서|가능하면 잘|신중히' "$F" \
           | grep -vE '"[^"]*(꼼꼼히|적절|상황에 따라|알아서|신중히)[^"]*"' || true)
    if [ -n "$WEAK" ]; then
        bad "판정 기준 없는 문장 — 확인 방법을 붙일 것:"
        echo "$WEAK" | head -6 | sed 's/^/      /'
    fi

    STRONG_CLAIM=$(grep -nE '완벽|반드시 모두|100%|절대 안전|보장한다' "$F" \
           | grep -vE '"[^"]*(완벽|반드시 모두|100%|절대 안전|보장)[^"]*"' || true)
    [ -n "$STRONG_CLAIM" ] && { bad "검증 불가한 강한 주장:"; echo "$STRONG_CLAIM" | head -4 | sed 's/^/      /'; }

    # ── 차단 여부 ─────────────────────────────────────────────
    grep -nE 'exit 1|중단한다|진행할 수 없다|작업을 멈춘다' "$F" | grep -vE '차단하지|멈추지 않' | head -3 \
        | while read -r l; do warn "차단 가능성: $l"; done

    # ── 동봉 파일 참조 (대상 프로젝트 파일은 제외) ──────────────
    # 스킬이 함께 배포하는 파일만 검사한다. 대상 프로젝트의 경로는 검사 대상이 아니다.
    grep -oE '`\./?[A-Za-z0-9_.-]+\.(sh|py)`' "$F" | tr -d '`' | sed 's|^\./||' | sort -u \
        | while read -r ref; do
            if [ -e "$DIR/$ref" ]; then ok "동봉 파일 실재: $ref"
            else bad "동봉했다고 적힌 파일이 없다: $ref"; fi
        done

    # ── 재사용을 막는 고유 정보 ────────────────────────────────
    LOCAL=$(grep -nE '/Users/|~/Desktop/|C:\\\\' "$F" || true)
    [ -n "$LOCAL" ] && { bad "개인 경로가 박혀 있다 — 남이 못 쓴다:"; echo "$LOCAL" | head -3 | sed 's/^/      /'; }
done

# ── 트리거 겹침 ────────────────────────────────────────────────
#
# 스킬은 이름으로 불리는 게 아니라 description 이 대화와 맞아서 뜬다.
# 같은 문구가 두 스킬에 있으면 둘 다 안 뜨거나 엉뚱한 쪽이 뜬다.
# 스킬 하나만 지정했을 때는 비교 대상이 없으므로 건너뛴다.
# ── 스킬 참조 표기 드리프트 ─────────────────────────────────────
#
# 스킬끼리 서로를 가리키는 표는 파일마다 복제된다. 복제본은 반드시 어긋난다.
# 실측: 같은 대상을 한쪽은 `measure-ios`, 다른 쪽은 `ios-measure:measure-ios` 로
# 적어 놓은 상태였고, 규칙을 적어 놓은 문단 바로 위 줄이 그 규칙을 위반하고 있었다.
# 사람 눈으로는 안 잡힌다. 기계가 잡는다.
if [ "${#FILES[@]}" -gt 1 ]; then
    say "스킬 참조 표기 — 다른 플러그인은 플러그인:스킬 형식인가"
    printf '%s\n' "${FILES[@]}" | python3 -c '
import re, sys, os

paths = [l.strip() for l in sys.stdin if l.strip()]

# 스킬 이름 → 소속 플러그인
owner = {}
for p in paths:
    skill = os.path.basename(os.path.dirname(p))
    parts = p.split(os.sep)
    plugin = parts[parts.index("plugins") + 1] if "plugins" in parts else "?"
    owner[skill] = plugin

bad = []
for p in paths:
    me_skill = os.path.basename(os.path.dirname(p))
    me_plugin = owner[me_skill]
    with open(p, encoding="utf-8") as f:
        for i, line in enumerate(f, 1):
            for ref in re.findall(r"`([a-z][a-z0-9-]+)`", line):
                if ref == me_skill or ref not in owner:
                    continue
                if owner[ref] != me_plugin:
                    bad.append((p, i, ref, owner[ref], line.strip()[:64]))

if not bad:
    print("  \033[32m✓\033[0m 다른 플러그인 참조가 모두 플러그인:스킬 형식")
else:
    print("  \033[31m✗\033[0m 접두사 없는 외부 스킬 참조 %d건 — 호출이 안 잡힌다" % len(bad))
    for p, i, ref, plug, ctx in bad[:10]:
        print("      %s:%d  `%s` → `%s:%s`" % (os.path.basename(os.path.dirname(p)), i, ref, plug, ref))
'

    say "트리거 겹침 — 같은 문구를 두 스킬이 쓰고 있는가"
    # 쉘로 하면 안 된다. 트리거 문구에 공백이 들어 있어서 awk/uniq 로 자르면
    # `"이 스킬 뭐가 부족해?"` 가 `"이` 로 잘려 엉뚱한 것끼리 비교된다.
    printf '%s\n' "${FILES[@]}" | python3 -c '
import re, sys, os
from collections import defaultdict

owners = defaultdict(list)
for path in (l.strip() for l in sys.stdin if l.strip()):
    name = os.path.basename(os.path.dirname(path))
    with open(path, encoding="utf-8") as f:
        desc = next((l for l in f if l.startswith("description:")), "")
    for phrase in re.findall(r"\"([^\"]+)\"", desc):
        owners[phrase.strip()].append(name)

dupes = {p: n for p, n in owners.items() if len(set(n)) > 1}
if not dupes:
    print("  \033[32m✓\033[0m 겹치는 트리거 문구 없음 (총 %d개 문구 비교)" % len(owners))
else:
    for phrase, names in sorted(dupes.items()):
        print("  \033[31m✗\033[0m \"%s\" — %s" % (phrase, " · ".join(sorted(set(names)))))
    print("      → 한쪽에서 빼거나 \"이럴 때는 저쪽\" 을 적을 것")
'
fi

say "이 스크립트가 판단하지 않은 것"
echo "  · 문장이 실제로 행동을 바꾸는지 (3단계)"
echo "    → 쓴 사람은 할 수 없다. 방금 쓴 사람에게는 모든 문장이 자명하다."
echo "    → 별도 세션 · 읽기 전용 · 렌즈 하나로 넘길 것 (SKILL.md 3단계)"
echo "  · 지식 설명 · 가상 예시 · 절차 겹침 (4단계) — 같은 방식으로 넘길 것"
echo "  · 뜻은 같고 표현만 다른 트리거 — 문자열 비교로는 안 잡힌다"
echo "  · 절차가 실제로 통하는지 — 한 번 돌려봐야 안다"
echo
printf '  %s이 스크립트만 돌린 것을 "검사받았다" 고 적지 않는다.%s\n' "$YEL" "$OFF"
echo "  \"기계 검사만 통과\" 가 정확한 표현이다."
exit 0
