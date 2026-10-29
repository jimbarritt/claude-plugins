#!/usr/bin/env bash
# Covers claude-plugins#28: software_english_lint.py reports which cached
# rule-data tag a run used, on stderr, and warns when that tag is not the
# one pinned in software-english.json. No age threshold: the age alone is
# never a reason to warn, because fetch-software-english-data.sh pins an
# exact tag and leaves an already-matching marker untouched, so an old but
# matching marker is still exactly correct.
# Deterministic and offline: runs against a scratch fixture copy of
# scripts/ carrying a small data/core-rules.toml (the same fixture
# commit_check_test.sh uses), with the .fetched-tag marker's age and
# content set directly. Never touches $HOME or the network.
#
# Run: swe/tests/data_version_test.sh
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

FIXTURE="$TMP/plugin"
mkdir -p "$FIXTURE"
cp -r "$PLUGIN_ROOT/scripts" "$FIXTURE/scripts"
cp "$PLUGIN_ROOT/config.json" "$FIXTURE/config.json"
mkdir -p "$FIXTURE/data"
cat > "$FIXTURE/data/core-rules.toml" <<'TOML'
[exemptions]
skip_line_marker = "swe:ignore"

[[rules]]
id = "banned-word"
severity = "error"

[[rules]]
id = "no-em-dash"
character = "—"
severity = "error"

[[rules]]
id = "sentence-length"
max_words = 200
severity = "warning"

[[rules]]
id = "no-continuous-tense"
pattern = "\\b(is|are|was|were)\\s+(\\w+ing)\\b"
stoplist = []
severity = "warning"

[[rules]]
id = "no-perfect-tense-for-behaviour"
pattern = "\\b(has|have|had)\\s+(\\w+ed)\\b"
stoplist = []
severity = "warning"

[[rules]]
id = "anthropomorphism-fixed-list"
lookback_words = 3
word_list = []
severity = "warning"

[[rules]]
id = "abstract-location"
lookback_words = 3
word_list = []
severity = "warning"

[[rules]]
id = "vocabulary-membership"
severity = "warning"
TOML
LINTER="$FIXTURE/scripts/software_english_lint.py"
MARKER="$FIXTURE/data/.fetched-tag"
HOME_DIR="$TMP/home"
mkdir -p "$HOME_DIR"

set_marker_age() {  # set_marker_age <seconds-ago>
  python3 -B -c '
import os, sys, time
t = time.time() - float(sys.argv[2])
os.utime(sys.argv[1], (t, t))
' "$MARKER" "$1"
}

CLEAN="$TMP/clean.md"
printf 'This file states one plain fact.\n' > "$CLEAN"
DASH="$TMP/dash.md"
printf 'hello — world\n' > "$DASH"

lint() {  # lint <file> [extra args...]
  local file="$1"; shift
  HOME="$HOME_DIR" python3 -B "$LINTER" "$file" --quiet-vocab "$@" 2>"$TMP/stderr"
}

# --- fresh, matching tag --------------------------------------------------
echo '{"repo": "x/y", "tag": "v9.9.9"}' > "$FIXTURE/software-english.json"
echo "v9.9.9" > "$MARKER"
set_marker_age 259200   # 3 days
OUT="$(lint "$CLEAN")"
STATUS=$?
ERR="$(cat "$TMP/stderr")"

case "$ERR" in
  *"swe: rule data v9.9.9, fetched 3 days ago"*) assert "fresh matching tag: info line names the tag and age" 0 ;;
  *) assert "fresh matching tag: info line names the tag and age" 1 ;;
esac
case "$ERR" in
  *"stale rule data"*) assert "fresh matching tag: no stale warning" 1 ;;
  *) assert "fresh matching tag: no stale warning" 0 ;;
esac
assert "fresh matching tag: clean.md is still clean" "$([ -z "$OUT" ] && [ "$STATUS" -eq 0 ]; echo $?)"

# --- old but still matching: age alone never warns ------------------------
set_marker_age 2592000   # 30 days
OUT="$(lint "$CLEAN")"
ERR="$(cat "$TMP/stderr")"
case "$ERR" in
  *"stale rule data"*) assert "old but matching tag: age alone still gives no stale warning" 1 ;;
  *) assert "old but matching tag: age alone still gives no stale warning" 0 ;;
esac
case "$ERR" in
  *"30 days ago"*) assert "old but matching tag: info line reports the real age" 0 ;;
  *) assert "old but matching tag: info line reports the real age" 1 ;;
esac

# --- stale tag --------------------------------------------------------------
echo "v9.9.8" > "$MARKER"
set_marker_age 3600
lint "$DASH" >/dev/null
ERR_STALE_DASH="$(cat "$TMP/stderr")"

case "$ERR_STALE_DASH" in
  *"swe: stale rule data:"*"v9.9.8"*"v9.9.9"*"fetch-software-english-data.sh"*)
    assert "stale tag: warning names the cached tag, the pin, and the fetch script" 0 ;;
  *) assert "stale tag: warning names the cached tag, the pin, and the fetch script" 1 ;;
esac
case "$ERR_STALE_DASH" in
  *"[error]"*|*"[warning]"*) assert "stale tag: no bracketed [error]/[warning] token in stderr" 1 ;;
  *) assert "stale tag: no bracketed [error]/[warning] token in stderr" 0 ;;
esac

# --- stdout and exit code are unaffected by the stale warning --------------
echo "v9.9.9" > "$MARKER"
set_marker_age 60
OUT_FRESH_DASH="$(lint "$DASH")"
STATUS_FRESH_DASH=$?
echo "v9.9.8" > "$MARKER"
OUT_STALE_DASH="$(lint "$DASH")"
STATUS_STALE_DASH=$?

assert "stale warning does not change dash.md's stdout" "$([ "$OUT_FRESH_DASH" = "$OUT_STALE_DASH" ]; echo $?)"
assert "stale warning does not change dash.md's exit code (1)" "$([ "$STATUS_FRESH_DASH" -eq 1 ] && [ "$STATUS_STALE_DASH" -eq 1 ]; echo $?)"
case "$OUT_STALE_DASH" in
  *"rule data"*) assert "dash.md's stdout never carries the rule-data lines" 1 ;;
  *) assert "dash.md's stdout never carries the rule-data lines" 0 ;;
esac

OUT_CLEAN_STALE="$(lint "$CLEAN")"
STATUS_CLEAN_STALE=$?
assert "stale warning does not change clean.md's exit code (0)" "$([ "$STATUS_CLEAN_STALE" -eq 0 ]; echo $?)"

# --- --count's stdout is unaffected -----------------------------------------
echo "v9.9.9" > "$MARKER"
COUNT_FRESH="$(lint "$DASH" --count)"
echo "v9.9.8" > "$MARKER"
COUNT_STALE="$(lint "$DASH" --count)"
assert "--count's stdout is the same whether the tag is fresh or stale" \
  "$([ "$COUNT_FRESH" = "$COUNT_STALE" ]; echo $?)"
case "$COUNT_STALE" in
  *"errors,"*"warnings across 1 files") assert "--count's stdout keeps its own summary-line shape" 0 ;;
  *) assert "--count's stdout keeps its own summary-line shape" 1 ;;
esac

# --- no marker ---------------------------------------------------------------
rm -f "$MARKER"
OUT="$(lint "$CLEAN")"
ERR="$(cat "$TMP/stderr")"
case "$ERR" in
  *"rule data version unknown"*) assert "no marker: reports the version as unknown" 0 ;;
  *) assert "no marker: reports the version as unknown" 1 ;;
esac
case "$ERR" in
  *"stale rule data"*) assert "no marker: no stale warning (nothing to compare)" 1 ;;
  *) assert "no marker: no stale warning (nothing to compare)" 0 ;;
esac

# --- marker present, no software-english.json pin ---------------------------
echo "v9.9.9" > "$MARKER"
set_marker_age 60
rm -f "$FIXTURE/software-english.json"
OUT="$(lint "$CLEAN")"
ERR="$(cat "$TMP/stderr")"
case "$ERR" in
  *"swe: rule data v9.9.9"*) assert "no pin file: info line still prints" 0 ;;
  *) assert "no pin file: info line still prints" 1 ;;
esac
case "$ERR" in
  *"stale rule data"*) assert "no pin file: no stale warning (nothing to compare)" 1 ;;
  *) assert "no pin file: no stale warning (nothing to compare)" 0 ;;
esac

# --- no rule catalogue at all: unaffected by this change --------------------
rm -f "$FIXTURE/data/core-rules.toml"
OUT="$(lint "$CLEAN")"
STATUS=$?
ERR="$(cat "$TMP/stderr")"
case "$ERR" in
  *"rule data"*) assert "no catalogue: no rule-data line (nothing was linted)" 1 ;;
  *) assert "no catalogue: no rule-data line (nothing was linted)" 0 ;;
esac
case "$OUT" in
  *"skipping this check"*) assert "no catalogue: the existing skip message is unchanged" 0 ;;
  *) assert "no catalogue: the existing skip message is unchanged" 1 ;;
esac
assert "no catalogue: still exits 0" "$([ "$STATUS" -eq 0 ]; echo $?)"

# --- format_age() unit table -------------------------------------------------
AGE_TABLE="$(PYTHONPATH="$FIXTURE/scripts" python3 -B -c '
import software_english_lint as m
cases = [(-5, "less than a minute ago"),
         (30, "less than a minute ago"),
         (60, "1 minute ago"),
         (7200, "2 hours ago"),
         (172800, "2 days ago"),
         (86400 * 3 + 10, "3 days ago")]
for seconds, want in cases:
    got = m.format_age(seconds)
    result = "OK" if got == want else "MISMATCH"
    print(f"{seconds}\t{got}\t{want}\t{result}")
')"
while IFS=$'\t' read -r seconds got want result; do
  assert "format_age($seconds) == '$want'" "$([ "$result" = "OK" ]; echo $?)"
done <<<"$AGE_TABLE"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
