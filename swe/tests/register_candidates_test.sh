#!/usr/bin/env bash
# Covers the located-candidate detectors added for claude-plugins#18:
# a verbless fragment right after a long sentence, a matched-pair sentence,
# and a run of three or more bold-lead-in bullet lists, all surfaced as
# advisory "candidate at line N" lines inside the existing
# ===INFERENCE_ADVISED=== block (for no-cadence-device and
# no-mechanical-repetition), never as findings.
#
# Runs against real Software English data, not a scratch fixture, the
# same pattern motion_idiom_test.sh uses: SWE_SRC=<software-english
# checkout> copies vocabulary/ and rules/ from a local checkout; without
# it, the fixture fetches the tag pinned in software-english.json. Skips
# with exit 0 if neither source is available.
#
# Run: swe/tests/register_candidates_test.sh
#      SWE_SRC=/path/to/software-english swe/tests/register_candidates_test.sh
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

# L is the catalogue's own no-cadence-device example sentence (19 words).
L="The consumer retries each failed message three times with exponential backoff, then writes it to the dead-letter topic."

# claude-plugins#25: the issue's own preceding sentences (20 and 16 words).
# Single-quoted: a code span's backtick inside a double-quoted string would
# otherwise be read as command substitution.
S1='The config file sets the retry limit and the timeout for each client, as two integers read once at startup.'
S2='The catalogue lists each shirt once per variant, so a search by style returns many rows.'
F2='The fields `colour`, `size`, `sleeve` and `fabric` tell them apart.'
F2_UNLISTED='The fields `colour`, `size`, `sleeve` and `fabric` distinguish them.'

# The linter itself exits non-zero when it reports a finding, or prints an
# advisory block. Captured to a variable rather than piped directly into
# grep: under `pipefail`, that non-zero exit would otherwise outrank grep's
# own match/no-match status in the pipeline's exit code.
lint() {
  printf '%s\n' "$1" | HOME="$SCRATCH_HOME" python3 -B "$LINTER" --text --source-label t --force-inference --quiet-vocab 2>&1
}
lint_file() {
  HOME="$SCRATCH_HOME" python3 -B "$LINTER" "$1" --force-inference --quiet-vocab 2>&1
}
has_cand() {  # has_cand <text> <rule-id> <line>: a candidate line for that rule at that line
  local out
  out="$(lint "$1")"
  grep -qF "t:0: [warning] [$2] candidate at line $3:" <<<"$out"
}
no_cand() {  # no_cand <text> [rule-id]: no candidate line for that rule (or at all, if omitted)
  local out rule="${2:-}"
  out="$(lint "$1")"
  if [ -n "$rule" ]; then
    ! grep -qF "[$rule] candidate at line" <<<"$out"
  else
    ! grep -q "candidate at line" <<<"$out"
  fi
}

# --- precondition: real data loaded, both rules present --------------------
assert "rule catalogue present in the fixture" "$([ -f "$FIXTURE/data/core-rules.toml" ]; echo $?)"
PRECOND_OUT="$(lint "$L No silent drops.")"
case "$PRECOND_OUT" in
  *"[no-cadence-device] inference pending:"*) assert "no-cadence-device is in the fetched catalogue" 0 ;;
  *) assert "no-cadence-device is in the fetched catalogue" 1 ;;
esac
case "$PRECOND_OUT" in
  *"[no-mechanical-repetition] inference pending:"*) assert "no-mechanical-repetition is in the fetched catalogue" 0 ;;
  *) assert "no-mechanical-repetition is in the fetched catalogue" 1 ;;
esac

# --- true positives: verbless fragment after a 15+-word sentence -----------
assert "fires: No silent drops. (catalogue's own example)" "$(has_cand "$L No silent drops." no-cadence-device 1; echo $?)"
assert "fires: No retries. (determiner exception: 'No' + retries read as a noun)" \
  "$(has_cand "$L No retries." no-cadence-device 1; echo $?)"

printf '%s\n%s\n' "$L" "No silent drops." > "$TMP/wrapped.md"
WRAP_OUT="$(lint_file "$TMP/wrapped.md")"
case "$WRAP_OUT" in
  *"[no-cadence-device] candidate at line 2:"*) assert "fires on its own start line when the fragment wraps onto a new line" 0 ;;
  *) assert "fires on its own start line when the fragment wraps onto a new line" 1 ;;
esac

# --- true positives that still fire (claude-plugins#25) --------------------
# A code span contributes a word to the length cap but never a verb, and a
# preposition/negator/quantifier right before a pronoun is not a verb
# either; none of these must stop firing once a code span counts as a noun
# phrase and a word before a pronoun can count as a verb.
assert "fires: None of them. (preposition before a pronoun is not a verb)" \
  "$(has_cand "$S1 None of them." no-cadence-device 1; echo $?)"
assert "fires: Not for these. (preposition before a pronoun is not a verb)" \
  "$(has_cand "$S1 Not for these." no-cadence-device 1; echo $?)"
assert "fires: Only \`colour\` and \`size\`. (code spans count as words, give no verb)" \
  "$(has_cand "$S2 Only \`colour\` and \`size\`." no-cadence-device 1; echo $?)"
assert "fires: The \`read\` path. (contents of a code span are never read as a verb)" \
  "$(has_cand "$S2 The \`read\` path." no-cadence-device 1; echo $?)"

DETAIL_OUT="$(lint "$S2 Only \`colour\` and \`size\`.")"
assert "candidate detail quotes the code span's own text, not blanks" \
  "$(grep -qF 'verbless sentence "Only `colour` and `size`."' <<<"$DETAIL_OUT"; echo $?)"

# --- true negatives: the fragment has a verb --------------------------------
assert "clean: It retries. (has a verb)" "$(no_cand "$L It retries." no-cadence-device; echo $?)"
assert "clean: The read fails. (has a verb)" "$(no_cand "$L The read fails." no-cadence-device; echo $?)"
assert "clean: Each write is logged. (has a verb)" "$(no_cand "$L Each write is logged." no-cadence-device; echo $?)"

# --- true negatives: a finite verb the closed list misses (claude-plugins#25) ---
# Each sentence has a finite present-tense verb outside the closed lexicon
# (operations.tsv/AUXILIARY_VERBS/COMMON_VERBS). All of these fired as
# false-positive no-cadence-device candidates before the fix.
assert "clean: Every client reads them. (issue #25, shape 1, verbatim)" \
  "$(no_cand "$S1 Every client reads them." no-cadence-device; echo $?)"
assert "clean: Every client trusts them. (verb outside the lexicon, before 'them')" \
  "$(no_cand "$S1 Every client trusts them." no-cadence-device; echo $?)"
assert "clean: Every client ignores it. (verb outside the lexicon, before 'it')" \
  "$(no_cand "$S1 Every client ignores it." no-cadence-device; echo $?)"
assert "clean: Each worker copies these. (verb outside the lexicon, before 'these')" \
  "$(no_cand "$S1 Each worker copies these." no-cadence-device; echo $?)"
assert "clean: ...tell them apart. (issue #25, shape 2, verbatim)" \
  "$(no_cand "$S2 $F2" no-cadence-device; echo $?)"
assert "clean: ...distinguish them. (code-span subject, verb outside the lexicon)" \
  "$(no_cand "$S2 $F2_UNLISTED" no-cadence-device; echo $?)"

printf '%s\n%s\n%s\n' \
  "The catalogue lists each shirt once per variant, so a search by" \
  'style returns many rows. The fields `colour`, `size`, `sleeve` and' \
  '`fabric` tell them apart.' > "$TMP/codespan.md"
CODESPAN_OUT="$(lint_file "$TMP/codespan.md")"
assert "clean: issue #25 shape 2, wrapped across lines, code spans intact" \
  "$(! grep -qF '[no-cadence-device] candidate at line' <<<"$CODESPAN_OUT"; echo $?)"

# --- true negatives: structural exclusions ----------------------------------
assert "clean: preceding sentence under 15 words" \
  "$(no_cand "The consumer retries each message. No silent drops." no-cadence-device; echo $?)"
assert "clean: preceding sentence ends in a question mark" \
  "$(no_cand "Where does this leave the retry policy? No silent drops." no-cadence-device; echo $?)"
assert "clean: fragment over the 6-word cap" \
  "$(no_cand "$L No silent drops and no lost writes ever." no-cadence-device; echo $?)"

printf '%s\n\n- No silent drops.\n' "$L" > "$TMP/listitem.md"
LISTITEM_OUT="$(lint_file "$TMP/listitem.md")"
assert "clean: fragment is a list item, not a sentence" \
  "$(! grep -qF '[no-cadence-device] candidate at line' <<<"$LISTITEM_OUT"; echo $?)"

printf '%s\n\n# No silent drops\n' "$L" > "$TMP/heading.md"
HEADING_OUT="$(lint_file "$TMP/heading.md")"
assert "clean: fragment is a heading, not a sentence" \
  "$(! grep -qF '[no-cadence-device] candidate at line' <<<"$HEADING_OUT"; echo $?)"

printf '%s\n\n```\nNo silent drops.\n```\n' "$L" > "$TMP/fenced.md"
FENCED_OUT="$(lint_file "$TMP/fenced.md")"
assert "clean: fragment is inside a fenced code block" \
  "$(! grep -qF '[no-cadence-device] candidate at line' <<<"$FENCED_OUT"; echo $?)"

# --- true positive: matched-pair sentences ----------------------------------
assert "fires: matched pair (catalogue's own example)" \
  "$(has_cand "The parser reads each file once. It never reads a file twice." no-cadence-device 1; echo $?)"
assert "clean: same-length sentences, different shape" \
  "$(no_cand "The parser reads each file once. Then the build writes the output to disk and exits." no-cadence-device; echo $?)"

# --- bold-lead-in list run: fires on 3+, stays clean under 3 ----------------
THREE_RUN='## First

Intro sentence here for section one.

- **Fast startup.** The service starts in 200 ms.
- **Low memory.** The service uses 40 MB at idle.

## Second

Intro sentence here for section two.

- **One config.** The service reads one file.
- **No secrets.** The service stores no credentials.

## Third

Intro sentence here for section three.

- **Simple API.** The service exposes one endpoint.
- **Clear errors.** The service reports one error shape.'
printf '%s\n' "$THREE_RUN" > "$TMP/three.md"
THREE_OUT="$(lint_file "$TMP/three.md")"
case "$THREE_OUT" in
  *"[no-mechanical-repetition] candidate at line 5:"*"3 lists in a row"*) assert "fires once on a run of 3 bold-lead-in lists" 0 ;;
  *) assert "fires once on a run of 3 bold-lead-in lists" 1 ;;
esac
RUN_COUNT="$(grep -cF '[no-mechanical-repetition] candidate at line' <<<"$THREE_OUT")"
assert "exactly one candidate line for the run, not one per list" "$([ "$RUN_COUNT" -eq 1 ]; echo $?)"

TWO_RUN='## First

- **Fast startup.** The service starts in 200 ms.
- **Low memory.** The service uses 40 MB at idle.

## Second

- **One config.** The service reads one file.
- **No secrets.** The service stores no credentials.'
printf '%s\n' "$TWO_RUN" > "$TMP/two.md"
TWO_OUT="$(lint_file "$TMP/two.md")"
assert "clean: only 2 qualifying lists" "$(! grep -qF '[no-mechanical-repetition] candidate at line' <<<"$TWO_OUT"; echo $?)"

BROKEN_RUN='## First

- **Fast startup.** The service starts in 200 ms.
- **Low memory.** The service uses 40 MB at idle.

## Second

- Plain bullet with no bold lead-in at all.
- Another plain bullet item here.

## Third

- **Simple API.** The service exposes one endpoint.
- **Clear errors.** The service reports one error shape.'
printf '%s\n' "$BROKEN_RUN" > "$TMP/broken.md"
BROKEN_OUT="$(lint_file "$TMP/broken.md")"
assert "clean: run broken by a non-qualifying list in the middle" \
  "$(! grep -qF '[no-mechanical-repetition] candidate at line' <<<"$BROKEN_OUT"; echo $?)"

FIVE_BULLET='## Required sections

- **Summary.** States the outcome.
- **Context.** States the background.
- **Decision.** States the choice.
- **Consequences.** States the effect.
- **Status.** States the state.'
printf '%s\n' "$FIVE_BULLET" > "$TMP/five.md"
FIVE_OUT="$(lint_file "$TMP/five.md")"
assert "clean: a single 5-bullet bold list (a template's required-sections list)" \
  "$(! grep -qF '[no-mechanical-repetition] candidate at line' <<<"$FIVE_OUT"; echo $?)"

WHOLLY_BOLD='## First

- **Fast startup.**
- **Low memory.**

## Second

- **One config.**
- **No secrets.**

## Third

- **Simple API.**
- **Clear errors.**'
printf '%s\n' "$WHOLLY_BOLD" > "$TMP/whollybold.md"
WB_OUT="$(lint_file "$TMP/whollybold.md")"
assert "clean: bullets that are wholly bold, no lead-in text after" \
  "$(! grep -qF '[no-mechanical-repetition] candidate at line' <<<"$WB_OUT"; echo $?)"

printf '```markdown\n%s\n```\n' "$THREE_RUN" > "$TMP/fencedrun.md"
FENCEDRUN_OUT="$(lint_file "$TMP/fencedrun.md")"
assert "clean: the 3-list run is inside a fenced code block" \
  "$(! grep -qF '[no-mechanical-repetition] candidate at line' <<<"$FENCEDRUN_OUT"; echo $?)"

# --- true-negative sweep: this repo's own real prose ------------------------
for f in README.md swe/docs/agent-guide.md swe/skills/lint-file/SKILL.md swe/output-styles/software-english.md CLAUDE.md; do
  REAL_PATH="$PLUGIN_ROOT/../$f"
  [ -f "$REAL_PATH" ] || REAL_PATH="$PLUGIN_ROOT/$f"
  if [ -f "$REAL_PATH" ]; then
    REAL_OUT="$(HOME="$SCRATCH_HOME" python3 -B "$LINTER" --text --source-label t --force-inference --quiet-vocab < "$REAL_PATH" 2>&1)"
    # Scoped to the two rule ids this file's detectors own: the
    # definite-phrase detector (claude-plugins#19) fires on this repo's
    # own real prose by design, since no-unanchored-reference and
    # no-unstated-presupposition are general prose rules, not narrow
    # structural patterns (see definite_phrase_candidates_test.sh).
    assert "clean: real file $f has no no-cadence-device/no-mechanical-repetition candidates" \
      "$(! grep -qE '\[(no-cadence-device|no-mechanical-repetition)\] candidate at line' <<<"$REAL_OUT"; echo $?)"
  fi
done

# --- invariant: a candidate is advisory, never a finding --------------------
INV_OUT="$(lint "$L No silent drops.")"
printf '%s\n' "$INV_OUT" | python3 -B "$LINTER" --text --source-label t --force-inference --quiet-vocab < /dev/null >/dev/null 2>&1
REAL_LINE_HITS="$(grep -cE '^t:[1-9][0-9]*: .*\[(no-cadence-device|no-mechanical-repetition)\]' <<<"$INV_OUT" || true)"
assert "no candidate is reported at a real (1+) line number" "$([ "$REAL_LINE_HITS" -eq 0 ]; echo $?)"

STRIPPED="$(sed '/^===INFERENCE_ADVISED===$/,/^===END_INFERENCE_ADVISED===$/d' <<<"$INV_OUT")"
assert "outside the advisory block, no candidate line leaks into the plain report" \
  "$(! grep -q 'candidate at line' <<<"$STRIPPED"; echo $?)"

COUNT_OUT="$(printf '%s\n' "$L No silent drops." | HOME="$SCRATCH_HOME" python3 -B "$LINTER" --text --source-label t --count --quiet-vocab 2>&1)"
case "$COUNT_OUT" in
  "0 errors"*) assert "--count reports 0 errors: a candidate never affects the exit code" 0 ;;
  *) assert "--count reports 0 errors: a candidate never affects the exit code" 1 ;;
esac

assert "the summary line names the located-candidate count" \
  "$(grep -qE '[0-9]+ located candidate\(s\) above are not findings' <<<"$INV_OUT"; echo $?)"

GREP_FINDINGS="$(grep -E ':\s*\[(error|warning)\]' <<<"$INV_OUT")"
assert "a findings-shaped grep over the output keeps the candidate line" \
  "$(grep -qF 'candidate at line' <<<"$GREP_FINDINGS"; echo $?)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
