#!/usr/bin/env bash
# Covers the two located-candidate detectors added for software-english#21:
# define-before-use (a noun occurring 3+ times, with a heading occurrence,
# never defined anywhere in the source) and no-count-list-mismatch (a
# number word before a colon list in the same sentence, whose item count
# differs from the stated number). Surfaced as advisory "candidate at line
# N" lines inside the existing ===INFERENCE_ADVISED=== block, never as
# findings, the same mechanism register_candidates_test.sh and
# definite_phrase_candidates_test.sh cover for the other located-candidate
# rules.
#
# Runs against real Software English data, not a scratch fixture:
# SWE_SRC=<software-english checkout> copies vocabulary/ and rules/ from a
# local checkout; without it, the fixture fetches the tag pinned in
# software-english.json. Skips with exit 0 if neither source is available.
#
# Run: swe/tests/define_and_count_candidates_test.sh
#      SWE_SRC=/path/to/software-english swe/tests/define_and_count_candidates_test.sh
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

lint() {
  printf '%s\n' "$1" | HOME="$SCRATCH_HOME" python3 -B "$LINTER" --text --source-label t --force-inference --quiet-vocab 2>&1
}
lint_file() {
  HOME="$SCRATCH_HOME" python3 -B "$LINTER" "$1" --force-inference --quiet-vocab 2>&1
}
has_cand() {  # has_cand <text> <rule-id> <line> <substring>
  local out
  out="$(lint "$1")"
  grep "^t:0: \[warning\] \[$2\] candidate at line $3:" <<<"$out" | grep -qF "$4"
}
has_cand_file() {  # has_cand_file <out> <rule-id> <line> <substring>
  grep "^[^:]*:0: \[warning\] \[$2\] candidate at line $3:" <<<"$1" | grep -qF "$4"
}
no_cand() {  # no_cand <text> [rule-id]
  local out rule="${2:-}"
  out="$(lint "$1")"
  if [ -n "$rule" ]; then
    ! grep -qF "[$rule] candidate at line" <<<"$out"
  else
    ! grep -q "candidate at line" <<<"$out"
  fi
}
no_cand_file() {  # no_cand_file <out> [rule-id]: same, against output already captured
  local out="$1" rule="${2:-define-before-use}"
  ! grep -qF "[$rule] candidate at line" <<<"$out"
}

# --- precondition: real data loaded, both rules present ---------------------
assert "rule catalogue present in the fixture" "$([ -f "$FIXTURE/data/core-rules.toml" ]; echo $?)"
PRECOND_OUT="$(lint "The widget needs no antecedent.")"
case "$PRECOND_OUT" in
  *"[define-before-use] inference pending:"*) assert "define-before-use is in the fetched catalogue" 0 ;;
  *) assert "define-before-use is in the fetched catalogue" 1 ;;
esac
case "$PRECOND_OUT" in
  *"[no-count-list-mismatch] inference pending:"*"(severity on violation: error)"*)
    assert "no-count-list-mismatch is in the fetched catalogue, at error severity" 0 ;;
  *) assert "no-count-list-mismatch is in the fetched catalogue, at error severity" 1 ;;
esac

# --- true positives: the issue's own worked example --------------------------
printf '# Order routing\n\nThe router sends an order in one of two modes: on the primary queue, with a\npriority flag, or on a queue of its own.\n\n## The first mode\n\nDetails here.\n\n## The second mode\n\nMore details.\n' > "$TMP/issue.md"
ISSUE_OUT="$(lint_file "$TMP/issue.md")"
assert "define-before-use fires on the issue's own example, at its first line" \
  "$(has_cand_file "$ISSUE_OUT" define-before-use 3 "modes"; echo $?)"
assert "define-before-use's detail names the occurrence count" \
  "$(has_cand_file "$ISSUE_OUT" define-before-use 3 "occurs 3 times"; echo $?)"
assert "no-count-list-mismatch fires on the issue's own example" \
  "$(has_cand_file "$ISSUE_OUT" no-count-list-mismatch 3 "colon list of 3 items"; echo $?)"
assert "'router' is not a define-before-use candidate (no heading occurrence)" \
  "$(! grep -F '[define-before-use] candidate' <<<"$ISSUE_OUT" | grep -qF '"router"'; echo $?)"

# --- true positive: a heading-first term fires at the heading line -----------
printf '## A widget\n\nA widget runs. A widget stops. A widget restarts.\n' > "$TMP/heading-first.md"
HF_OUT="$(lint_file "$TMP/heading-first.md")"
assert "a term first seen in its own heading fires at the heading's line" \
  "$(has_cand_file "$HF_OUT" define-before-use 1 "widget"; echo $?)"

# --- true negatives: define-before-use, a definition clause exists -----------
printf '## The mode\n\nA **mode** sends an order. One mode runs. Another mode queues it.\n' > "$TMP/bold-defined.md"
assert "clean: a bold-defined term ('**mode**')" \
  "$(no_cand_file "$(lint_file "$TMP/bold-defined.md")"; echo $?)"

printf '## The mode\n\nMode means which queue an order takes. One mode runs. Another mode queues it.\n' > "$TMP/means-defined.md"
assert "clean: 'X means' defines the term" \
  "$(no_cand_file "$(lint_file "$TMP/means-defined.md")"; echo $?)"

printf '## The mode\n\nA mode is a queue choice. One mode runs. Another mode queues it.\n' > "$TMP/is-a-defined.md"
assert "clean: 'a mode is a' defines the term" \
  "$(no_cand_file "$(lint_file "$TMP/is-a-defined.md")"; echo $?)"

printf '## The mode\n\nAn order takes a mode (a queue choice). One mode runs. Another mode queues it.\n' > "$TMP/paren-defined.md"
assert "clean: a parenthetical gloss defines the term" \
  "$(no_cand_file "$(lint_file "$TMP/paren-defined.md")"; echo $?)"

printf '## Glossary\n\n- mode: a queue choice\n\nOne mode runs. Another mode queues it. A third mode waits.\n' > "$TMP/glossary-defined.md"
assert "clean: a glossary bullet defines the term" \
  "$(no_cand_file "$(lint_file "$TMP/glossary-defined.md")"; echo $?)"

# --- true negatives: define-before-use, gates not met ------------------------
printf '## A widget\n\nA widget runs.\n' > "$TMP/too-few.md"
assert "clean: fewer than 3 occurrences" \
  "$(no_cand_file "$(lint_file "$TMP/too-few.md")"; echo $?)"
assert "clean: no heading occurrence at all" \
  "$(no_cand "A widget runs. A widget stops. A widget restarts." define-before-use; echo $?)"
printf '## The queue\n\nA queue holds orders. A queue drains. A queue fills.\n' > "$TMP/vocab-word.md"
assert "clean: a vocabulary word ('queue') never candidates" \
  "$(no_cand_file "$(lint_file "$TMP/vocab-word.md")"; echo $?)"

printf '```\n## A gadget\n\nA gadget runs.\n```\n\nA gadget stops. A gadget restarts.\n' > "$TMP/fenced-term.md"
FT_OUT="$(lint_file "$TMP/fenced-term.md")"
assert "clean: occurrences only inside a fenced code block do not count toward the total" \
  "$(! grep -qF '[define-before-use] candidate' <<<"$FT_OUT"; echo $?)"

# --- true positives: no-count-list-mismatch -----------------------------------
assert "fires: 'The service exposes three endpoints: read and write.' (stated 3, actual 2)" \
  "$(has_cand "The service exposes three endpoints: read and write." no-count-list-mismatch 1 "colon list of 2 items"; echo $?)"
assert "fires: 'three sources: alpha, beta, gamma and delta.' (stated 3, actual 4: a serial 'and' with no Oxford comma is two items) (#24)" \
  "$(has_cand "The service reads from three sources: alpha, beta, gamma and delta." no-count-list-mismatch 1 "colon list of 4 items"; echo $?)"

# --- true negatives: no-count-list-mismatch, counts match --------------------
assert "clean: 'The cache has three tiers: memory, disk, and remote.'" \
  "$(no_cand "The cache has three tiers: memory, disk, and remote." no-count-list-mismatch; echo $?)"
assert "clean: an item itself containing 'or' is not split further" \
  "$(no_cand "It covers two transports: an HTTP API, and an event or message API over Kafka." no-count-list-mismatch; echo $?)"
assert "clean: a range quantity, not a list count ('one or two lines')" \
  "$(no_cand "State the result in one or two lines: what ran, and what it found." no-count-list-mismatch; echo $?)"
assert "clean: 'both' is excluded (an explanatory colon, not a list)" \
  "$(no_cand "On both flags: a pending rule is never a finding." no-count-list-mismatch; echo $?)"
assert "clean: a section numeral is not a count word" \
  "$(no_cand "SPEC seven point nine exempts them: a documented limit." no-count-list-mismatch; echo $?)"
assert "clean: ambiguous and/or split (more than one conjunction) is not reported" \
  "$(no_cand "The service exposes two endpoints: read and write and delete." no-count-list-mismatch; echo $?)"
assert "clean: 'Two of the five routes drop an entry: read and write.' (a part of a larger set)" \
  "$(no_cand "Two of the five routes drop an entry: read and write." no-count-list-mismatch; echo $?)"
assert "clean: seven items, a serial 'and' with no Oxford comma (#24)" \
  "$(no_cand "The service reads from seven sources: alpha, beta, gamma, delta, the Northwind Order Archive, epsilon and zeta." no-count-list-mismatch; echo $?)"
assert "clean: the same seven items with an Oxford comma (#24)" \
  "$(no_cand "The service reads from seven sources: alpha, beta, gamma, delta, the Northwind Order Archive, epsilon, and zeta." no-count-list-mismatch; echo $?)"
assert "clean: ambiguous serial and/or in the last comma-part (more than one conjunction) is not reported (#24)" \
  "$(no_cand "The service exposes three endpoints: read, write and delete or purge." no-count-list-mismatch; echo $?)"

printf '```\nThree costs follow from that: one, two, three, four.\n```\n' > "$TMP/fenced-count.md"
FC_OUT="$(lint_file "$TMP/fenced-count.md")"
assert "clean: a colon list inside a fenced code block" \
  "$(! grep -qF '[no-count-list-mismatch] candidate' <<<"$FC_OUT"; echo $?)"

# --- real-file sweep: zero no-count-list-mismatch candidates on this repo's own prose
for f in "$PLUGIN_ROOT/README.md" "$PLUGIN_ROOT/docs/agent-guide.md" "$PLUGIN_ROOT/skills/lint-file/SKILL.md"; do
  if [ -f "$f" ]; then
    SWEEP_OUT="$(lint_file "$f")"
    assert "zero no-count-list-mismatch candidates on $(basename "$f")" \
      "$(! grep -qF '[no-count-list-mismatch] candidate' <<<"$SWEEP_OUT"; echo $?)"
  fi
done

# --- cap: 25 distinct undefined heading terms show exactly 20, plus the tail -
python3 -c "
for i in range(25):
    suffix = chr(ord('a') + i // 26) + chr(ord('a') + i % 26)
    word = f'widget{suffix}'
    print(f'## A {word}')
    print()
    print(f'A {word} runs. A {word} stops. A {word} restarts.')
    print()
" > "$TMP/cap.md"
CAP_OUT="$(lint_file "$TMP/cap.md")"
CAP_SHOWN="$(grep -cE '^[^:]+:0: \[warning\] \[define-before-use\] candidate at line [1-9]' <<<"$CAP_OUT")"
assert "the cap shows exactly 20 candidate lines" "$([ "$CAP_SHOWN" -eq 20 ]; echo $?)"
assert "the cap names the omitted count on a separate line" \
  "$(grep -qF '[define-before-use] candidate at line 0: 5 more candidate(s) omitted' <<<"$CAP_OUT"; echo $?)"

# --- invariants ----------------------------------------------------------------
INV_OUT="$(lint "The service exposes three endpoints: read and write.")"
REAL_LINE_HITS="$(grep -cE '^t:[1-9][0-9]*: .*\[(define-before-use|no-count-list-mismatch)\]' <<<"$INV_OUT" || true)"
assert "no candidate is reported at a real (1+) line number" "$([ "$REAL_LINE_HITS" -eq 0 ]; echo $?)"

COUNT_OUT="$(printf '%s\n' "The service exposes three endpoints: read and write." | HOME="$SCRATCH_HOME" python3 -B "$LINTER" --text --source-label t --count --quiet-vocab 2>&1)"
case "$COUNT_OUT" in
  "0 errors"*) assert "--count reports 0 errors: a candidate never affects the exit code" 0 ;;
  *) assert "--count reports 0 errors: a candidate never affects the exit code" 1 ;;
esac

assert "the summary line names the located-candidate count" \
  "$(grep -qE '[0-9]+ located candidate\(s\) above are not findings' <<<"$INV_OUT"; echo $?)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
