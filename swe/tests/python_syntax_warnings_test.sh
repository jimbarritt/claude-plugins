#!/usr/bin/env bash
# Checks that every .py file under scripts/ (vendored files included)
# compiles with no invalid-escape warning.
#
# Why this exists: a backslash in a normal string literal that is not a
# recognised escape (for example "\s" in a docstring quoting a regex) is
# silently accepted by Python today, but is reported as a warning before
# it becomes an error in a future version. Python 3.12 and later report
# it as a SyntaxWarning; Python 3.11 reports the same fault as a
# DeprecationWarning instead, so a check for SyntaxWarning alone passes
# on 3.11 even with the bug present (claude-plugins#26). This test
# treats both warning classes as failures, on every Python it can find.
#
# Run: swe/tests/python_syntax_warnings_test.sh
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

mapfile -t FILES < <(find "$PLUGIN_ROOT/scripts" -name '*.py' | sort)
assert "at least 5 .py files found under scripts/ to check" "$([ "${#FILES[@]}" -ge 5 ]; echo $?)"

for PY in python3 python3.12 python3.13; do
  command -v "$PY" >/dev/null 2>&1 || { echo "note: $PY not found, skipped"; continue; }
  for f in "${FILES[@]}"; do
    rel="${f#"$PLUGIN_ROOT"/}"
    ERR="$("$PY" -W error::SyntaxWarning -W error::DeprecationWarning -c '
import sys
path = sys.argv[1]
with open(path) as fh:
    source = fh.read()
compile(source, path, "exec")
' "$f" 2>&1)"
    assert "$rel parses with no invalid-escape warning under $PY" "$?"
    if [ -n "$ERR" ]; then
      echo "  $ERR" | tail -1
    fi
  done
done

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
