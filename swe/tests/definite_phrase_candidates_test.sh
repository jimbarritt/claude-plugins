#!/usr/bin/env bash
# Covers the definite-phrase located-candidate detector added for
# claude-plugins#19: a definite noun phrase ("the"/"these"/"those"/"both
# the") whose head noun's lemma does not occur earlier in the document
# (title and headings included) is a candidate for no-unanchored-reference,
# or for no-unstated-presupposition when the phrase carries a cardinal
# ("the two queues", "both the options"). Surfaced as advisory "candidate
# at line N" lines inside the existing ===INFERENCE_ADVISED=== block, never
# as findings, the same mechanism register_candidates_test.sh covers for
# no-cadence-device and no-mechanical-repetition.
#
# Runs against real Software English data, not a scratch fixture:
# SWE_SRC=<software-english checkout> copies vocabulary/ and rules/ from a
# local checkout; without it, the fixture fetches the tag pinned in
# software-english.json. Skips with exit 0 if neither source is available.
#
# Run: swe/tests/definite_phrase_candidates_test.sh
#      SWE_SRC=/path/to/software-english swe/tests/definite_phrase_candidates_test.sh
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
# grep: under `pipefail`, that non-zero exit would otherwise outrank grep's
# own match/no-match status in the pipeline's exit code.
lint() {
  printf '%s\n' "$1" | HOME="$SCRATCH_HOME" python3 -B "$LINTER" --text --source-label t --force-inference --quiet-vocab 2>&1
}
lint_file() {
  HOME="$SCRATCH_HOME" python3 -B "$LINTER" "$1" --force-inference --quiet-vocab 2>&1
}
has_cand() {  # has_cand <text> <rule-id> <line> <substring>: a candidate for that rule at that line, containing substring
  local out
  out="$(lint "$1")"
  grep "^t:0: \[warning\] \[$2\] candidate at line $3:" <<<"$out" | grep -qF "$4"
}
has_cand_file() {  # has_cand_file <out> <rule-id> <line> <substring>: same, against output already captured (any source label)
  grep "^[^:]*:0: \[warning\] \[$2\] candidate at line $3:" <<<"$1" | grep -qF "$4"
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
no_cand_text() {  # no_cand_text <text> <rule-id> <substring>: no candidate for that rule contains substring
  local out
  out="$(lint "$1")"
  ! grep "\[$2\] candidate at line" <<<"$out" | grep -qF "$3"
}

# --- precondition: real data loaded, both rules present ---------------------
assert "rule catalogue present in the fixture" "$([ -f "$FIXTURE/data/core-rules.toml" ]; echo $?)"
PRECOND_OUT="$(lint "The widget needs no antecedent.")"
case "$PRECOND_OUT" in
  *"[no-unanchored-reference] inference pending:"*) assert "no-unanchored-reference is in the fetched catalogue" 0 ;;
  *) assert "no-unanchored-reference is in the fetched catalogue" 1 ;;
esac
case "$PRECOND_OUT" in
  *"[no-unstated-presupposition] inference pending:"*) assert "no-unstated-presupposition is in the fetched catalogue" 0 ;;
  *) assert "no-unstated-presupposition is in the fetched catalogue" 1 ;;
esac

# --- true positives: the issue's own worked example -------------------------
ISSUE_SENT="How orders are routed: the two queues, the three tiers, and the fields each one sets."
assert "fires: the two queues (cardinal, routed to no-unstated-presupposition)" \
  "$(has_cand "$ISSUE_SENT" no-unstated-presupposition 1 "the two queues"; echo $?)"
assert "fires: the three tiers (cardinal, routed to no-unstated-presupposition)" \
  "$(has_cand "$ISSUE_SENT" no-unstated-presupposition 1 "the three tiers"; echo $?)"
assert "fires: the fields (no cardinal, routed to no-unanchored-reference; head lands on 'fields', 'each' does not restart the scan)" \
  "$(has_cand "$ISSUE_SENT" no-unanchored-reference 1 "the fields"; echo $?)"

printf '# Routing\n\n%s\n' "$ISSUE_SENT" > "$TMP/heading-shift.md"
SHIFT_OUT="$(lint_file "$TMP/heading-shift.md")"
assert "heading-shifted line numbers: the two queues at line 3" \
  "$(has_cand_file "$SHIFT_OUT" no-unstated-presupposition 3 "the two queues"; echo $?)"
assert "heading-shifted line numbers: the fields at line 3" \
  "$(has_cand_file "$SHIFT_OUT" no-unanchored-reference 3 "the fields"; echo $?)"

# --- true positive: the catalogue's own no-unstated-presupposition example --
assert "fires: The four surveyed carriers (modifier-skip past 'surveyed' to reach 'carriers')" \
  "$(has_cand "The four surveyed carriers all reject a weekend dispatch slot." no-unstated-presupposition 1 "The four surveyed carriers"; echo $?)"

# --- true positive: a phrase wrapped across two lines ------------------------
printf 'the two\nqueues drain in order.\n' > "$TMP/wrapped.md"
WRAPPED_OUT="$(lint_file "$TMP/wrapped.md")"
assert "wrapped phrase fires at the determiner's own line (1), not the head's line (2)" \
  "$(has_cand_file "$WRAPPED_OUT" no-unstated-presupposition 1 "the two queues"; echo $?)"

# --- true positive: a phrase inside a heading itself --------------------------
printf '## The two queues\n' > "$TMP/heading-phrase.md"
HP_OUT="$(lint_file "$TMP/heading-phrase.md")"
assert "a phrase inside a heading fires at the heading's own line" \
  "$(has_cand_file "$HP_OUT" no-unstated-presupposition 1 "The two queues"; echo $?)"

# --- true negatives: anchoring ------------------------------------------------
printf '# Queue System\n\nThis describes the two queues in detail.\n' > "$TMP/title-anchors.md"
TITLE_OUT="$(lint_file "$TMP/title-anchors.md")"
assert "clean: the document title anchors a later plural mention" \
  "$(! grep -qF 'candidate at line' <<<"$TITLE_OUT"; echo $?)"

printf 'This describes the two queues in detail.\n\n## Queue system detail\n' > "$TMP/heading-after.md"
AFTER_OUT="$(lint_file "$TMP/heading-after.md")"
assert "a heading appearing only AFTER a phrase does not anchor it (forward-only lookup)" \
  "$(has_cand_file "$AFTER_OUT" no-unstated-presupposition 1 "the two queues"; echo $?)"

assert "clean: an earlier sentence's plural anchors a later singular-determiner mention" \
  "$(no_cand "Orders enter one of two queues. The queues drain in order." no-unstated-presupposition; echo $?)"

LINK_OUT="$(lint "See [the queue](https://example.com) for details. The queue drains every minute.")"
LINK_CAND_COUNT="$(grep -cF '[no-unanchored-reference] candidate at line' <<<"$LINK_OUT")"
assert "earlier link text anchors a later mention: exactly one candidate (the link itself), not two" \
  "$([ "$LINK_CAND_COUNT" -eq 1 ]; echo $?)"
printf -- '- The widget holds state.\n\nThe widget persists across restarts.\n' > "$TMP/list-anchors.md"
LIST_OUT="$(lint_file "$TMP/list-anchors.md")"
assert "an earlier list item anchors a later mention (only one candidate, at the list item)" \
  "$(has_cand_file "$LIST_OUT" no-unanchored-reference 1 "The widget"; echo $?)"
LIST_CAND_COUNT="$(grep -cF '[no-unanchored-reference] candidate at line' <<<"$LIST_OUT")"
assert "exactly one candidate: the second mention is anchored by the list item" "$([ "$LIST_CAND_COUNT" -eq 1 ]; echo $?)"

printf '| Name | Detail |\n| --- | --- |\n| the widget | holds state |\n\nThe widget drains every minute.\n' > "$TMP/table-anchors.md"
TABLE_OUT="$(lint_file "$TMP/table-anchors.md")"
assert "an earlier table cell anchors a later mention (only one candidate, at the table row)" \
  "$(has_cand_file "$TABLE_OUT" no-unanchored-reference 3 "the widget"; echo $?)"
TABLE_CAND_COUNT="$(grep -cF '[no-unanchored-reference] candidate at line' <<<"$TABLE_OUT")"
assert "exactly one candidate: the second mention is anchored by the table cell" "$([ "$TABLE_CAND_COUNT" -eq 1 ]; echo $?)"

# --- true negatives: same-sentence enumeration --------------------------------
assert "clean: 'the three routes: read, write, and delete' (colon enumeration)" \
  "$(no_cand "The three routes: read, write, and delete." no-unstated-presupposition; echo $?)"
assert "clean: a parenthesis right after the head is also an enumeration marker" \
  "$(no_cand "The three routes (read, write, and delete) all succeed." no-unstated-presupposition; echo $?)"

# --- true negatives: excluded by token shape ----------------------------------
# DEFINITE_TOKEN keeps a hyphenated compound and a multi-digit number as one
# token, so none of these ever reads as a bare cardinal over a plain head:
# "two-phase"/"30-second" are themselves excluded as LITERAL_TOKEN (hyphenated,
# snake_case-like); "404"/"2009" fail the head's lowercase-letter-start test.
assert "clean: 'the two-phase commit' (hyphenated compound stays one token, excluded as a literal token)" \
  "$(no_cand "The team ships the two-phase commit." no-unstated-presupposition; echo $?)"
assert "clean: 'the 30-second timeout' (hyphenated multi-digit token, excluded as a literal token)" \
  "$(no_cand "The team ships the 30-second timeout." no-unstated-presupposition; echo $?)"
assert "clean: 'the 404 response' (numeral head fails the lowercase-start head test)" \
  "$(no_cand "The team ships the 404 response." no-unstated-presupposition; echo $?)"
assert "clean: 'the 2009 edition' (numeral head fails the lowercase-start head test)" \
  "$(no_cand "The team ships the 2009 edition." no-unstated-presupposition; echo $?)"

# --- true negative: a generic head needs no antecedent -----------------------
assert "clean: 'the same approach' (GENERIC_DEFINITE_HEADS catches 'same' as the head; the sentence's own first mention, 'The approach', still fires separately)" \
  "$(no_cand_text "The approach works well. The same approach applies here." no-unanchored-reference "same approach"; echo $?)"

# --- true negative: a capitalised head is out of scope ------------------------
assert "clean: 'the Kafka cluster' (capitalised head fails the lowercase-start test)" \
  "$(no_cand_text "The system reads from the Kafka cluster." no-unanchored-reference "Kafka"; echo $?)"

# --- true negatives: fenced code block and blockquote -------------------------
printf '```\nthe gadget\n```\n\n> the thing\n\nThe gadget needs no definition.\n' > "$TMP/fenced-quoted.md"
FQ_OUT="$(lint_file "$TMP/fenced-quoted.md")"
assert "a mention only inside a fenced code block or a blockquote does not anchor a later real mention" \
  "$(has_cand_file "$FQ_OUT" no-unanchored-reference 7 "The gadget"; echo $?)"
FQ_CAND_COUNT="$(grep -cF 'candidate at line' <<<"$FQ_OUT")"
assert "exactly one candidate: the fenced/quoted mentions produce none themselves" "$([ "$FQ_CAND_COUNT" -eq 1 ]; echo $?)"

# --- precedence: a cardinal phrase never appears under no-unanchored-reference -
PRECEDENCE_OUT="$(lint "$ISSUE_SENT")"
assert "a cardinal phrase's own text never appears on a no-unanchored-reference candidate line" \
  "$(! grep '\[no-unanchored-reference\] candidate at line' <<<"$PRECEDENCE_OUT" | grep -qF 'the two queues'; echo $?)"

# --- cap: 25 distinct unanchored heads produce exactly MAX_CANDIDATES_PER_RULE -
python3 -c "
for i in range(1, 26):
    print(f'The item{i} needs review.')
" > "$TMP/cap.md"
CAP_OUT="$(lint_file "$TMP/cap.md")"
CAP_SHOWN="$(grep -cE '^[^:]+:0: \[warning\] \[no-unanchored-reference\] candidate at line [1-9]' <<<"$CAP_OUT")"
assert "the cap shows exactly MAX_CANDIDATES_PER_RULE (20) candidate lines" "$([ "$CAP_SHOWN" -eq 20 ]; echo $?)"
assert "the cap names the omitted count on a separate line" \
  "$(grep -qF '[no-unanchored-reference] candidate at line 0: 5 more candidate(s) omitted' <<<"$CAP_OUT"; echo $?)"

# --- invariants (mirror register_candidates_test.sh) --------------------------
INV_OUT="$(lint "$ISSUE_SENT")"
REAL_LINE_HITS="$(grep -cE '^t:[1-9][0-9]*: .*\[(no-unanchored-reference|no-unstated-presupposition)\]' <<<"$INV_OUT" || true)"
assert "no candidate is reported at a real (1+) line number" "$([ "$REAL_LINE_HITS" -eq 0 ]; echo $?)"

COUNT_OUT="$(printf '%s\n' "$ISSUE_SENT" | HOME="$SCRATCH_HOME" python3 -B "$LINTER" --text --source-label t --count --quiet-vocab 2>&1)"
case "$COUNT_OUT" in
  "0 errors"*) assert "--count reports 0 errors: a candidate never affects the exit code" 0 ;;
  *) assert "--count reports 0 errors: a candidate never affects the exit code" 1 ;;
esac

assert "the summary line names the located-candidate count" \
  "$(grep -qE '[0-9]+ located candidate\(s\) above are not findings' <<<"$INV_OUT"; echo $?)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
