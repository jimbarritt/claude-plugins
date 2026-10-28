#!/usr/bin/env bash
# Structural regression test for claude-plugins#23: SKILL.md must document
# a Pass 3 (the whole-document pass) between Pass 2 and Step 5, naming its
# five rule ids and its warning severity, and Step 6 must no longer claim
# only two passes exist.
#
# This checks SKILL.md's text only. No automated test can check the model
# judgement Pass 3 asks for; that rests on a manual check (see the mission's
# plan document).
#
# Run: swe/tests/lint_file_pass3_test.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$HERE/.."
SKILL="$PLUGIN_ROOT/skills/lint-file/SKILL.md"

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

assert "SKILL.md exists" "$([ -f "$SKILL" ]; echo $?)"

PASS2_LINE="$(grep -n '^### Pass 2:' "$SKILL" | head -1 | cut -d: -f1)"
PASS3_LINE="$(grep -n '^### Pass 3:' "$SKILL" | head -1 | cut -d: -f1)"
STEP5_LINE="$(grep -n '^## Step 5:' "$SKILL" | head -1 | cut -d: -f1)"

assert "a ### Pass 2 heading exists" "$([ -n "$PASS2_LINE" ]; echo $?)"
assert "a ### Pass 3 heading exists" "$([ -n "$PASS3_LINE" ]; echo $?)"
assert "a ## Step 5 heading exists" "$([ -n "$STEP5_LINE" ]; echo $?)"

if [ -n "$PASS2_LINE" ] && [ -n "$PASS3_LINE" ] && [ -n "$STEP5_LINE" ]; then
  assert "### Pass 3 sits after ### Pass 2" "$([ "$PASS3_LINE" -gt "$PASS2_LINE" ]; echo $?)"
  assert "### Pass 3 sits before ## Step 5" "$([ "$PASS3_LINE" -lt "$STEP5_LINE" ]; echo $?)"
fi

for RULE_ID in \
  "no-contradiction-between-sections" \
  "summary-before-detail" \
  "no-mechanical-repetition" \
  "no-unanchored-reference" \
  "no-precedent-before-subject"
do
  assert "Pass 3 names rule id [$RULE_ID]" "$(grep -q -- "\`\[$RULE_ID\]\`" "$SKILL"; echo $?)"
done

assert "Pass 3 states warning severity" "$(grep -q 'Report each Pass 3 finding at' "$SKILL" && grep -q '.warning. severity' "$SKILL"; echo $?)"

assert "no leftover 'both passes' or 'two passes' text" "$(! grep -q 'both passes\|two passes' "$SKILL"; echo $?)"

assert "Step 6 now says 'all three passes'" "$(grep -q 'all three passes' "$SKILL"; echo $?)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
