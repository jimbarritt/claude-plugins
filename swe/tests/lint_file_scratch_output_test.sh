#!/usr/bin/env bash
# Structural regression test for claude-plugins#29: Step 3's command must
# redirect its output to a per-run file outside the working tree, using a
# portable `mktemp` template, and must not reintroduce the BSD-only
# `mktemp -t swe-lint` form the issue found broken on GNU coreutils.
#
# This checks SKILL.md's text only, plus a smoke test of the mktemp
# pattern itself. No automated test can check that an agent actually
# avoids writing a scratch file inside the repository; that rests on the
# instruction text SKILL.md gives it.
#
# Run: swe/tests/lint_file_scratch_output_test.sh
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

STEP3_LINE="$(grep -n '^## Step 3:' "$SKILL" | head -1 | cut -d: -f1)"
STEP4_LINE="$(grep -n '^## Step 4:' "$SKILL" | head -1 | cut -d: -f1)"

assert "a ## Step 3 heading exists" "$([ -n "$STEP3_LINE" ]; echo $?)"
assert "a ## Step 4 heading exists" "$([ -n "$STEP4_LINE" ]; echo $?)"

if [ -n "$STEP3_LINE" ] && [ -n "$STEP4_LINE" ]; then
  STEP3_SECTION="$(sed -n "${STEP3_LINE},${STEP4_LINE}p" "$SKILL")"
  STEP3_FLAT="$(printf '%s' "$STEP3_SECTION" | tr '\n' ' ')"
else
  STEP3_SECTION=""
  STEP3_FLAT=""
fi

assert "Step 3 uses mktemp" "$(printf '%s' "$STEP3_SECTION" | grep -q 'mktemp'; echo $?)"
assert "Step 3's mktemp template uses XXXXXX" "$(printf '%s' "$STEP3_SECTION" | grep -q 'XXXXXX'; echo $?)"
assert "Step 3 redirects to \"\$out\"" "$(printf '%s' "$STEP3_SECTION" | grep -q '> "\$out"'; echo $?)"
assert "Step 3 joins stderr with 2>&1" "$(printf '%s' "$STEP3_SECTION" | grep -q '2>&1'; echo $?)"
assert "Step 3 prints the output file's path" "$(printf '%s' "$STEP3_SECTION" | grep -q 'swe-lint output:'; echo $?)"
assert "Step 3 does not use the non-portable 'mktemp -t swe-lint' form" "$(! printf '%s' "$STEP3_SECTION" | grep -q 'mktemp -t swe-lint'; echo $?)"
assert "Step 3 says not to write the output inside the repository" "$(printf '%s' "$STEP3_FLAT" | grep -qi 'inside.*the repository'; echo $?)"
assert "Step 3 says not to use a fixed file name" "$(printf '%s' "$STEP3_SECTION" | grep -q 'fixed'; echo $?)"

# Smoke test: the portable template creates a file outside the working tree.
smoke_out="$(mktemp "${TMPDIR:-/tmp}/swe-lint.XXXXXX" 2>/dev/null)"
smoke_rc=$?
assert "the portable mktemp template succeeds" "$smoke_rc"
if [ "$smoke_rc" -eq 0 ]; then
  assert "the created file exists" "$([ -f "$smoke_out" ]; echo $?)"
  case "$smoke_out" in
    "$PWD"/*) assert "the created file is outside \$PWD" 1 ;;
    *) assert "the created file is outside \$PWD" 0 ;;
  esac
  rm -f "$smoke_out"
fi

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
