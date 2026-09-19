#!/usr/bin/env bash
# Regression test for claude-plugins#3: software_english_lint.py must skip
# cleanly, not crash, when data/core-rules.toml hasn't been fetched yet.
# Deterministic and offline: runs the linter directly against a scratch
# copy of scripts/ with no data/ directory, so it never touches the
# network either.
#
# Run: swe/tests/lint_fail_open_test.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$HERE/.."

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

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp -r "$PLUGIN_ROOT/scripts" "$TMP/scripts"
rm -rf "$TMP/data"

SAMPLE="$TMP/sample.md"
echo "hello — world" > "$SAMPLE"

OUT="$(python3 "$TMP/scripts/software_english_lint.py" "$SAMPLE" 2>&1)"
STATUS=$?

assert "exits 0 (no block) when the rule catalogue is missing" "$([ "$STATUS" -eq 0 ]; echo $?)"

case "$OUT" in
  *Traceback*) assert "no Python traceback in the output" 1 ;;
  *) assert "no Python traceback in the output" 0 ;;
esac

case "$OUT" in
  *"skipping this check"*) assert "prints an actionable skip message" 0 ;;
  *) assert "prints an actionable skip message" 1 ;;
esac

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
