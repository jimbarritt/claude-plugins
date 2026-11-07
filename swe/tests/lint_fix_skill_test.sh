#!/usr/bin/env bash
# Structural regression test for claude-plugins#35: /swe:lint-fix must
# exist as a sibling of /swe:lint-file, share lint-file's check commands
# byte-for-byte (so the two cannot drift), carry Edit in its own
# allowed-tools while lint-file stays Edit-free, do one fix pass and one
# re-check with no loop back into fixing, and record its ledger rows
# under a distinct `--recorded-by`.
#
# This checks SKILL.md text only, not that an agent's edits are
# actually correct: no automated test can judge a fix's prose quality.
# A manual check: run /swe:lint-fix on a scratch markdown file holding
# one banned word, one inference-tier fault, and one Pass 3
# contradiction, and confirm the first two are edited, the third is
# reported as not fixed, the second check runs, and the ledger row
# shows recorded_by "lint-fix".
#
# Run: swe/tests/lint_fix_skill_test.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$HERE/.."
FIX_SKILL="$PLUGIN_ROOT/skills/lint-fix/SKILL.md"
FILE_SKILL="$PLUGIN_ROOT/skills/lint-file/SKILL.md"

PASS=0
FAIL=0

assert() {
  local desc="$1" ok="$2"
  if [ "$ok" -eq 0 ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $desc"
  fi
}

assert "lint-fix/SKILL.md exists" "$([ -f "$FIX_SKILL" ]; echo $?)"
assert "lint-file/SKILL.md exists" "$([ -f "$FILE_SKILL" ]; echo $?)"

if [ ! -f "$FIX_SKILL" ]; then
  echo
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

assert "frontmatter name is lint-fix" "$(grep -q '^name: lint-fix$' "$FIX_SKILL"; echo $?)"
assert "allowed-tools includes Edit" "$(grep -q '^allowed-tools:.*Edit' "$FIX_SKILL"; echo $?)"
assert "lint-file's allowed-tools does not include Edit" "$(! grep -q '^allowed-tools:.*Edit' "$FILE_SKILL"; echo $?)"

for n in 1 2 3 4 5 6; do
  assert "a ## Step $n heading exists" "$(grep -q "^## Step $n:" "$FIX_SKILL"; echo $?)"
done

STEP3_LINE="$(grep -n '^## Step 3:' "$FIX_SKILL" | head -1 | cut -d: -f1)"
STEP4_LINE="$(grep -n '^## Step 4:' "$FIX_SKILL" | head -1 | cut -d: -f1)"
STEP5_LINE="$(grep -n '^## Step 5:' "$FIX_SKILL" | head -1 | cut -d: -f1)"
STEP6_LINE="$(grep -n '^## Step 6:' "$FIX_SKILL" | head -1 | cut -d: -f1)"

if [ -n "$STEP3_LINE" ] && [ -n "$STEP4_LINE" ]; then
  STEP3_SECTION="$(sed -n "${STEP3_LINE},${STEP4_LINE}p" "$FIX_SKILL")"
else
  STEP3_SECTION=""
fi
if [ -n "$STEP4_LINE" ] && [ -n "$STEP5_LINE" ]; then
  STEP4_SECTION="$(sed -n "${STEP4_LINE},${STEP5_LINE}p" "$FIX_SKILL")"
else
  STEP4_SECTION=""
fi
if [ -n "$STEP5_LINE" ] && [ -n "$STEP6_LINE" ]; then
  STEP5_SECTION="$(sed -n "${STEP5_LINE},${STEP6_LINE}p" "$FIX_SKILL")"
else
  STEP5_SECTION=""
fi

assert "Step 3 heading mentions Fix" "$(printf '%s' "$STEP3_SECTION" | head -1 | grep -qi 'Fix'; echo $?)"
assert "Step 4 heading mentions second check" "$(printf '%s' "$STEP4_SECTION" | head -1 | grep -qi 'second check'; echo $?)"
assert "Step 5 heading mentions Record" "$(printf '%s' "$STEP5_SECTION" | head -1 | grep -qi 'Record'; echo $?)"

assert "text refers to skills/lint-file/SKILL.md" "$(grep -q 'skills/lint-file/SKILL.md' "$FIX_SKILL"; echo $?)"
assert "lint-file Step 6 names /swe:lint-fix" "$(grep -q '/swe:lint-fix' "$FILE_SKILL"; echo $?)"

# The two skills must run byte-identical fetch and check commands, so a
# future edit to one cannot silently drift from the other (the failure
# mode claude-plugins#29 already found once, inside a single file).
FETCH_FIX="$(grep -m1 'fetch-software-english-data.sh"$' "$FIX_SKILL")"
FETCH_FILE="$(grep -m1 'fetch-software-english-data.sh"$' "$FILE_SKILL")"
assert "fetch command line exists in both files" "$([ -n "$FETCH_FIX" ] && [ -n "$FETCH_FILE" ]; echo $?)"
assert "fetch command line is identical in both files" "$([ "$FETCH_FIX" = "$FETCH_FILE" ]; echo $?)"

RUN_FIX="$(grep -m1 'software_english_lint.py" <file-path> --force-inference' "$FIX_SKILL")"
RUN_FILE="$(grep -m1 'software_english_lint.py" <file-path> --force-inference' "$FILE_SKILL")"
assert "run command line exists in both files" "$([ -n "$RUN_FIX" ] && [ -n "$RUN_FILE" ]; echo $?)"
assert "run command line is identical in both files" "$([ "$RUN_FIX" = "$RUN_FILE" ]; echo $?)"

assert "Step 2 uses mktemp" "$(grep -q 'mktemp' "$FIX_SKILL"; echo $?)"
assert "Step 2's mktemp template uses XXXXXX" "$(grep -q 'XXXXXX' "$FIX_SKILL"; echo $?)"
assert "Step 2 redirects to \"\$out\"" "$(grep -q '> \"\$out\"' "$FIX_SKILL"; echo $?)"
assert "Step 2 joins stderr with 2>&1" "$(grep -q '2>&1' "$FIX_SKILL"; echo $?)"
assert "Step 2 prints the output file's path" "$(grep -q 'swe-lint output:' "$FIX_SKILL"; echo $?)"
assert "Step 2 does not use the non-portable 'mktemp -t swe-lint' form" "$(! grep -q 'mktemp -t swe-lint' "$FIX_SKILL"; echo $?)"

assert "Step 5 passes --recorded-by lint-fix" "$(grep -q -- '--recorded-by lint-fix' "$FIX_SKILL"; echo $?)"
assert "Step 5 has --record-lint-result clean" "$(grep -q -- '--record-lint-result clean' "$FIX_SKILL"; echo $?)"
assert "Step 5 has --record-lint-result failed" "$(grep -q -- '--record-lint-result failed' "$FIX_SKILL"; echo $?)"

FIX_FLAT="$(tr '\n' ' ' < "$FIX_SKILL")"

assert "Step 4 states the first nonce does not match the edited file" "$(grep -q 'does not match the edited file' "$FIX_SKILL"; echo $?)"
assert "intro states no repeated fix pass" "$(printf '%s' "$FIX_FLAT" | grep -q 'does not repeat the fix pass'; echo $?)"
assert "Step 4 states it fixes nothing" "$(grep -q 'Do not fix any finding from this step' "$FIX_SKILL"; echo $?)"
assert "Step 5 states exit 4 does not repeat Step 3" "$(printf '%s' "$FIX_FLAT" | grep -q 'Do not run Step 3 again'; echo $?)"

assert "Step 3 excludes fenced code blocks" "$(grep -q 'fenced code block' "$FIX_SKILL"; echo $?)"
assert "Step 3 excludes blockquotes" "$(grep -q 'blockquote' "$FIX_SKILL"; echo $?)"
assert "Step 3 states facts are kept" "$(grep -q 'Keep every fact' "$FIX_SKILL"; echo $?)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
