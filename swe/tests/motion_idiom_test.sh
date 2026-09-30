#!/usr/bin/env bash
# Covers the deterministic motion-idiom coverage added for
# claude-plugins#15: each fixed motion idiom in vocabulary/banned.tsv
# ("where this/that leaves", "as they/it come(s)") fires as banned-word,
# and the same words used literally, or the four shapes the issue
# proposed but deliberately dropped (go past, pass over, does not move,
# behind the + component), stay clean.
#
# Runs against real Software English data, not a scratch fixture: no
# other test file does this. SWE_SRC=<software-english checkout> copies
# vocabulary/ and rules/ from a local checkout; without it, the fixture
# fetches the tag pinned in software-english.json. Skips with exit 0 if
# neither source is available (offline, no local checkout).
#
# Run: swe/tests/motion_idiom_test.sh
#      SWE_SRC=/path/to/software-english swe/tests/motion_idiom_test.sh
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
cp "$PLUGIN_ROOT/config.json" "$PLUGIN_ROOT/software-english.json" "$FIXTURE/"
if [ -n "${SWE_SRC:-}" ]; then
  mkdir -p "$FIXTURE/data"
  cp "$SWE_SRC"/vocabulary/*.tsv "$FIXTURE/data/"
  cp "$SWE_SRC"/rules/core-rules.toml "$FIXTURE/data/"
elif ! "$FIXTURE/scripts/fetch-software-english-data.sh" >/dev/null 2>&1; then
  echo "SKIP: no SWE_SRC and the pinned software-english tag could not be fetched"
  exit 0
fi
LINTER="$FIXTURE/scripts/software_english_lint.py"

# The linter itself exits non-zero when it reports a finding. Captured to a
# variable rather than piped directly into grep: under `pipefail`, that
# non-zero exit would otherwise outrank grep's own match/no-match status in
# the pipeline's reported exit code.
lint() { printf '%s\n' "$1" | python3 -B "$LINTER" --text --source-label t --quiet-vocab; }
fires() {  # fires <sentence> <phrase>: a banned-word finding for exactly that phrase
  local out
  out="$(lint "$1")"
  grep -qF "[banned-word] \"$2\"" <<<"$out"
}
clean() {  # clean <sentence>: no banned-word, abstract-location, or anthropomorphism finding
  local out
  out="$(lint "$1")"
  ! grep -qE '\[(banned-word|abstract-location|anthropomorphism)\]' <<<"$out"
}

# --- precondition: real data loaded (else every clean assertion is vacuous) ---
assert "rule catalogue present in the fixture" "$([ -f "$FIXTURE/data/core-rules.toml" ]; echo $?)"
assert "an existing transport entry still fires (rides on)" "$(fires 'The event rides on the topic.' 'rides on'; echo $?)"

# --- true positives: the fixed motion idioms (claude-plugins#15) ---
assert "fires: where this leaves the retry policy" "$(fires 'Where this leaves the retry policy is unclear.' 'where this leaves'; echo $?)"
assert "fires: where that leaves" "$(fires 'This is where that leaves the migration.' 'where that leaves'; echo $?)"
assert "fires: where does this leave" "$(fires 'Where does this leave the retry policy?' 'where does this leave'; echo $?)"
assert "fires: where does that leave" "$(fires 'Where does that leave the schema?' 'where does that leave'; echo $?)"
assert "fires: add them as they come" "$(fires 'Add them as they come.' 'as they come'; echo $?)"
assert "fires: as they come in" "$(fires 'Requests are handled as they come in.' 'as they come'; echo $?)"
assert "fires: as it comes" "$(fires 'Handle each event as it comes.' 'as it comes'; echo $?)"

# --- guards: same words, literal or non-idiomatic sense, stay clean ---
assert "clean: this leaves the file unchanged" "$(clean 'This leaves the file unchanged.'; echo $?)"
assert "clean: resumes where it left off" "$(clean 'The job resumes where it left off.'; echo $?)"
assert "clean: that leaves two options" "$(clean 'That leaves two options.'; echo $?)"
assert "clean: as they become available" "$(clean 'As they become available, the queue drains.'; echo $?)"
assert "clean: as they complete" "$(clean 'As they complete, the command exits.'; echo $?)"

# --- guards: motion verbs deliberately left to the inference tier (#15) ---
assert "clean: the file does not move (literal operation)" "$(clean 'The file does not move to the archive directory.'; echo $?)"
assert "clean: a second pass over the input" "$(clean 'A second pass over the input removes duplicates.'; echo $?)"
assert "clean: a read goes past the end of the file" "$(clean 'A read that goes past the end of the file returns an error.'; echo $?)"
assert "clean: the service runs behind the proxy" "$(clean 'The service runs behind the proxy.'; echo $?)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
