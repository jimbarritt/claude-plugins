#!/usr/bin/env bash
# Covers software-english#24: the no-reader-reaction-prediction inference
# rule (SPEC §5.3), and five fixed phrases added to vocabulary/banned.tsv
# for the same issue: "you will be glad", "you'll be glad", "before you
# find out", "exactly what you want", and "may be what you want".
#
# Phrases with a plausible correct use ("it helps to", "you may want to")
# were deliberately left out of banned.tsv and stay inference-only: this
# test asserts they do NOT fire banned-word, alongside the deterministic
# fires for the five new rows and a regression check on the pre-existing
# "you may find" row.
#
# Runs against real Software English data, not a scratch fixture, the
# same pattern motion_idiom_test.sh and register_candidates_test.sh use:
# SWE_SRC=<software-english checkout> copies vocabulary/ and rules/ from a
# local checkout; without it, the fixture fetches the tag pinned in
# software-english.json. Skips with exit 0 if neither source is available.
#
# Run: swe/tests/reader_reaction_test.sh
#      SWE_SRC=/path/to/software-english swe/tests/reader_reaction_test.sh
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
SCRATCH_HOME="$TMP/home"
mkdir -p "$SCRATCH_HOME"

# The linter itself exits non-zero when it reports a finding, or prints an
# advisory block. Captured to a variable rather than piped directly into
# grep: under `pipefail`, that non-zero exit would otherwise outrank
# grep's own match/no-match status in the pipeline's exit code.
lint() { printf '%s\n' "$1" | python3 -B "$LINTER" --text --source-label t --quiet-vocab; }
lint_inference() {
  printf '%s\n' "$1" | HOME="$SCRATCH_HOME" python3 -B "$LINTER" --text --source-label t --force-inference --quiet-vocab 2>&1
}
fires() {  # fires <sentence> <phrase>: a banned-word finding for exactly that phrase
  local out
  out="$(lint "$1")"
  grep -qF "[banned-word] \"$2\"" <<<"$out"
}
clean() {  # clean <sentence>: no banned-word finding
  local out
  out="$(lint "$1")"
  ! grep -q '\[banned-word\]' <<<"$out"
}

# --- precondition: real data loaded, rule present in the catalogue ---------
assert "rule catalogue present in the fixture" "$([ -f "$FIXTURE/data/core-rules.toml" ]; echo $?)"
PRECOND_OUT="$(lint_inference 'A placeholder sentence with no reader-reaction wording at all.')"
case "$PRECOND_OUT" in
  *"[no-reader-reaction-prediction] inference pending:"*) assert "no-reader-reaction-prediction is in the fetched catalogue" 0 ;;
  *) assert "no-reader-reaction-prediction is in the fetched catalogue" 1 ;;
esac

# --- true positives: the five new banned.tsv rows (software-english#24) ---
assert "fires: you will be glad of the second replica" \
  "$(fires 'You will be glad of the second replica.' 'you will be glad'; echo $?)"
assert "fires: you'll be glad you did" \
  "$(fires "You'll be glad you did." "you'll be glad"; echo $?)"
assert "fires: before you find out after the first deploy" \
  "$(fires 'Choose the region now, before you find out after the first deploy.' 'before you find out'; echo $?)"
assert "fires: that may be exactly what you want" \
  "$(fires 'That may be exactly what you want.' 'exactly what you want'; echo $?)"
assert "fires: that may be what you want" \
  "$(fires 'That may be what you want.' 'may be what you want'; echo $?)"

# --- regression: the pre-existing row the issue's own example already hits ---
assert "fires: you may find the defaults enough (pre-existing row)" \
  "$(fires 'You may find the defaults enough.' 'you may find'; echo $?)"

# --- guards: phrases deliberately kept inference-only, stay clean ----------
assert "clean: it helps to keep a terminal open" \
  "$(clean 'It helps to keep a terminal open as you go.'; echo $?)"
assert "clean: it helps to keep each scan short (it names a component)" \
  "$(clean 'The index is small, and it helps to keep each scan short.'; echo $?)"
assert "clean: a conditional imperative in a how-to guide" \
  "$(clean 'If you want a dry run, pass the check flag.'; echo $?)"
assert "clean: a stated consequence of an action" \
  "$(clean 'If you skip this step, the first deploy fails.'; echo $?)"
assert "clean: a plain instruction" \
  "$(clean 'Open a terminal.'; echo $?)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
