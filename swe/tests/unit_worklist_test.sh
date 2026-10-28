#!/usr/bin/env bash
# Covers the numbered worklist of prose units --force-inference prints
# (prose_units(), format_unit_worklist()), and the --units-judged coverage
# check on --record-lint-result (claude-plugins#20). Also covers a unit's
# own readable rendering of a link and a code span (claude-plugins#27).
# Deterministic and offline: every repository is a throwaway `git init`
# under a scratch directory, and the linter runs against a fixture copy
# of scripts/ carrying a small data/core-rules.toml, the same conventions
# commit_check_test.sh uses. Never touches $HOME or the network.
#
# Run: swe/tests/unit_worklist_test.sh
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

# --- fixture plugin: scripts/ + config.json + a minimal rule catalogue ----
# Same minimal catalogue as commit_check_test.sh: --force-inference needs
# one rule with check = "model-judgement" to reach the sources loop at all.
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

[[rules]]
id = "tone-judgement"
check = "model-judgement"
description = "Judge tone by hand."
TOML
LINTER="$FIXTURE/scripts/software_english_lint.py"

new_repo() {  # new_repo <name>
  local dir="$TMP/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init
  echo "$dir"
}

ledger_path() {  # ledger_path <repo>
  echo "$1/.git/swe/lint-log.ndjson"
}

nonce_for() {  # nonce_for <repo> <file> -- prints "<nonce> <units>" from one force-inference run
  local out nonce units
  out="$(cd "$1" && python3 "$LINTER" "$2" --force-inference --quiet-vocab 2>&1)"
  nonce="$(printf '%s\n' "$out" | sed -n 's/^swe-lint-nonce: //p' | tail -1)"
  units="$(printf '%s\n' "$out" | sed -n 's/^swe-lint-units: //p' | tail -1)"
  printf '%s %s\n' "$nonce" "$units"
}

units_for() {  # units_for <repo> <file> -- prints only swe-lint-units from a fresh run
  (cd "$1" && python3 "$LINTER" "$2" --force-inference --quiet-vocab 2>&1) \
    | sed -n 's/^swe-lint-units: //p' | tail -1
}

# --- the worklist itself ----------------------------------------------------

REPO="$(new_repo worklist)"
cat > "$REPO/doc.md" <<'MD'
# Title

A paragraph that
wraps over
three lines.

```
# not a heading
a paragraph-like line inside a fence
```

~~~
also fenced, a different fence style
~~~

    an indented code block, four spaces

> a blockquote line

a line with swe:ignore on it

## Section

First paragraph after the section.

Second paragraph after the section.

- item one
  - nested bullet under item one
- item two

| a | b |
| - | - |
| 1 | 2 |
MD
git -C "$REPO" add doc.md

FI_OUT="$(cd "$REPO" && python3 "$LINTER" doc.md --force-inference --quiet-vocab 2>&1)"
UNITS="$(printf '%s\n' "$FI_OUT" | sed -n 's/^swe-lint-units: //p' | tail -1)"

# Expected units, in order: heading(Title), paragraph(wraps), heading(Section),
# paragraph(First), paragraph(Second), list-item(item one), list-item(item two),
# table. That's 8. Fenced, indented, blockquoted, and skip-marker lines are
# never units.
assert "swe-lint-units counts exactly the expected 8 units" "$([ "$UNITS" = "8" ]; echo $?)"

UNIT_LINES="$(printf '%s\n' "$FI_OUT" | grep '\[inference-unit\]' | grep -v 'prose unit(s) follow')"
UNIT_COUNT="$(printf '%s\n' "$UNIT_LINES" | grep -c 'unit [0-9]* of 8,')"
assert "exactly 8 numbered unit lines are printed" "$([ "$UNIT_COUNT" -eq 8 ]; echo $?)"

case "$UNIT_LINES" in
  *"unit 1 of 8, heading, line 1: # Title"*) assert "unit 1 is the Title heading, with its raw markdown text" 0 ;;
  *) assert "unit 1 is the Title heading, with its raw markdown text" 1 ;;
esac
case "$UNIT_LINES" in
  *"unit 2 of 8, paragraph, lines 3-5: A paragraph that wraps over three lines."*)
    assert "unit 2 is the wrapped paragraph, as one unit with its line range and joined text" 0 ;;
  *) assert "unit 2 is the wrapped paragraph, as one unit with its line range and joined text" 1 ;;
esac
case "$UNIT_LINES" in
  *"not a heading"*) assert "fenced content inside a \`\`\` fence is never a unit" 1 ;;
  *) assert "fenced content inside a \`\`\` fence is never a unit" 0 ;;
esac
case "$UNIT_LINES" in
  *"also fenced"*) assert "fenced content inside a ~~~ fence is never a unit" 1 ;;
  *) assert "fenced content inside a ~~~ fence is never a unit" 0 ;;
esac
case "$UNIT_LINES" in
  *"indented code block"*) assert "an indented code block is never a unit" 1 ;;
  *) assert "an indented code block is never a unit" 0 ;;
esac
case "$UNIT_LINES" in
  *"a blockquote line"*) assert "a blockquote line is never a unit" 1 ;;
  *) assert "a blockquote line is never a unit" 0 ;;
esac
case "$UNIT_LINES" in
  *"swe:ignore"*) assert "a skip-marker line is never a unit" 1 ;;
  *) assert "a skip-marker line is never a unit" 0 ;;
esac
case "$UNIT_LINES" in
  *"list-item, lines 28-29: item one"*)
    assert "a nested bullet folds into its parent item's line range, not a separate unit" 0 ;;
  *) assert "a nested bullet folds into its parent item's line range, not a separate unit" 1 ;;
esac
case "$UNIT_LINES" in
  *", table, line"*)
    assert "the table prints as one table unit" 0 ;;
  *) assert "the table prints as one table unit" 1 ;;
esac

# Every unit line is finding-shaped (claude-plugins#14's own invariant),
# always at line 0, never a real finding.
UNIT_NOT_FINDING_SHAPED="$(printf '%s\n' "$UNIT_LINES" | grep -vcE ':\s*\[(error|warning)\]')"
assert "every unit line is findings-shaped" "$([ "$UNIT_NOT_FINDING_SHAPED" -eq 0 ]; echo $?)"
REAL_ERRORS="$(printf '%s\n' "$FI_OUT" | grep -E '^[^:]+:[1-9][0-9]*: \[error\]' | wc -l | tr -d ' ')"
assert "no unit line is counted as a real error at a line 1 or more" "$([ "$REAL_ERRORS" -eq 0 ]; echo $?)"

# Last line is the nonce; the line right before it is the units total.
LAST_LINE="$(printf '%s\n' "$FI_OUT" | tail -1)"
case "$LAST_LINE" in
  "swe-lint-nonce: "*) assert "the nonce is still the very last line" 0 ;;
  *) assert "the nonce is still the very last line" 1 ;;
esac
SECOND_LAST="$(printf '%s\n' "$FI_OUT" | tail -2 | head -1)"
case "$SECOND_LAST" in
  "swe-lint-units: 8") assert "swe-lint-units is the line right before the nonce" 0 ;;
  *) assert "swe-lint-units is the line right before the nonce" 1 ;;
esac

case "$FI_OUT" in
  *"record with --units-judged 8."*) assert "the summary line tells the caller how to record a full pass" 0 ;;
  *) assert "the summary line tells the caller how to record a full pass" 1 ;;
esac

NONCE_STORE="$REPO/.git/swe/lint-nonces.json"
NONCE="$(printf '%s\n' "$FI_OUT" | sed -n 's/^swe-lint-nonce: //p' | tail -1)"
STORE_UNITS="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]]['units'])" "$NONCE_STORE" "$NONCE" 2>/dev/null)"
assert "the nonce entry itself records units == 8" "$([ "$STORE_UNITS" = "8" ]; echo $?)"

# --- a no-prose file: 0 units, and 0 still records clean --------------------

: > "$REPO/empty.md"
git -C "$REPO" add empty.md
EMPTY_UNITS="$(units_for "$REPO" empty.md)"
assert "an empty file's worklist total is 0" "$([ "$EMPTY_UNITS" = "0" ]; echo $?)"
read -r EMPTY_NONCE _ <<< "$(nonce_for "$REPO" empty.md)"
OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$EMPTY_NONCE" --units-judged 0 empty.md 2>&1)"
assert "--units-judged 0 records clean for a 0-unit file" "$([ $? -eq 0 ]; echo $?)"
ROW="$(tail -1 "$(ledger_path "$REPO")")"
GOT_STATUS="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['status'])" "$ROW")"
assert "a 0-of-0 pass records status clean, not partial" "$([ "$GOT_STATUS" = "clean" ]; echo $?)"

# --- a code file: one unit per run of consecutive comment lines ------------

cat > "$REPO/code.py" <<'PY'
# first comment run
# still the first run
x = 1
# second comment run
PY
git -C "$REPO" add code.py
CODE_UNITS="$(units_for "$REPO" code.py)"
assert "a code file counts one unit per run of consecutive comment lines (2 units)" "$([ "$CODE_UNITS" = "2" ]; echo $?)"

# --- --advise-inference prints no unit lines and no units total -----------

ADVISE_TEXT="$(python3 -c "print('word ' * 80)")"
ADVISE_OUT="$(printf '%s' "$ADVISE_TEXT" | python3 "$LINTER" --text --source-label t --advise-inference --quiet-vocab 2>&1)"
case "$ADVISE_OUT" in
  *"inference-unit"*) assert "--advise-inference prints no [inference-unit] line" 1 ;;
  *) assert "--advise-inference prints no [inference-unit] line" 0 ;;
esac
case "$ADVISE_OUT" in
  *"swe-lint-units"*) assert "--advise-inference prints no swe-lint-units line" 1 ;;
  *) assert "--advise-inference prints no swe-lint-units line" 0 ;;
esac

# --- recording: missing/mismatched/partial/failed --units-judged -----------

REPO2="$(new_repo recording)"
cat > "$REPO2/r.md" <<'MD'
# Heading

Paragraph one.

Paragraph two.
MD
git -C "$REPO2" add r.md
read -r R_NONCE R_UNITS <<< "$(nonce_for "$REPO2" r.md)"
assert "r.md has the expected 3 units" "$([ "$R_UNITS" = "3" ]; echo $?)"

OUT="$(cd "$REPO2" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$R_NONCE" r.md 2>&1)"
assert "no --units-judged given: exits 4" "$([ $? -eq 4 ]; echo $?)"
assert "no --units-judged given: appends no ledger row" "$([ ! -f "$(ledger_path "$REPO2")" ]; echo $?)"

# The nonce must still be usable: the missing-flag check does not consume it.
OUT="$(cd "$REPO2" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$R_NONCE" --units-judged 2 r.md 2>&1)"
assert "a bare count below the total exits 4 (must declare \"of M\" to go partial)" "$([ $? -eq 4 ]; echo $?)"
assert "no ledger row from that mismatch" "$([ ! -f "$(ledger_path "$REPO2")" ]; echo $?)"

# The mismatch above consumed the nonce: a retry with the same nonce fails too.
OUT="$(cd "$REPO2" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$R_NONCE" --units-judged 3 r.md 2>&1)"
assert "a units mismatch consumes the nonce (no retry with the same value)" "$([ $? -eq 4 ]; echo $?)"

read -r R_NONCE2 R_UNITS2 <<< "$(nonce_for "$REPO2" r.md)"
OUT="$(cd "$REPO2" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$R_NONCE2" --units-judged "2 of 4" r.md 2>&1)"
assert "a wrong declared total (M mismatch) exits 4" "$([ $? -eq 4 ]; echo $?)"
assert "that call consumed the nonce too" "$([ ! -f "$(ledger_path "$REPO2")" ]; echo $?)"

read -r R_NONCE3 R_UNITS3 <<< "$(nonce_for "$REPO2" r.md)"
OUT="$(cd "$REPO2" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$R_NONCE3" --units-judged "2 of $R_UNITS3" r.md 2>&1)"
assert "a correctly declared partial exits 0" "$([ $? -eq 0 ]; echo $?)"
ROW="$(tail -1 "$(ledger_path "$REPO2")")"
GOT_STATUS="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['status'])" "$ROW")"
assert "a clean verdict with a partial count records status partial" "$([ "$GOT_STATUS" = "partial" ]; echo $?)"
GOT_TOTAL="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['units_total'])" "$ROW")"
GOT_JUDGED="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['units_judged'])" "$ROW")"
assert "the row records units_total" "$([ "$GOT_TOTAL" = "3" ]; echo $?)"
assert "the row records units_judged" "$([ "$GOT_JUDGED" = "2" ]; echo $?)"
case "$OUT" in
  *"recorded partial (2 of 3 units)"*) assert "the success line states partial coverage" 0 ;;
  *) assert "the success line states partial coverage" 1 ;;
esac

echo "# edited" >> "$REPO2/r.md"
git -C "$REPO2" add r.md
read -r R_NONCE4 R_UNITS4 <<< "$(nonce_for "$REPO2" r.md)"
OUT="$(cd "$REPO2" && python3 "$LINTER" --record-lint-result failed --findings 2 --nonce "$R_NONCE4" --units-judged "1 of $R_UNITS4" r.md 2>&1)"
assert "a failed verdict with partial coverage still exits 0" "$([ $? -eq 0 ]; echo $?)"
ROW="$(tail -1 "$(ledger_path "$REPO2")")"
GOT_STATUS="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['status'])" "$ROW")"
assert "a failed verdict records failed, never partial, regardless of coverage" "$([ "$GOT_STATUS" = "failed" ]; echo $?)"
GOT_JUDGED="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['units_judged'])" "$ROW")"
assert "a failed row still records units_judged" "$([ "$GOT_JUDGED" = "1" ]; echo $?)"

# --- malformed --units-judged values: malformed call (exit 2) --------------

python3 "$LINTER" --record-lint-result clean --nonce x --units-judged "abc" r.md >/dev/null 2>&1
assert "a non-numeric --units-judged value exits 2" "$([ $? -eq 2 ]; echo $?)"

python3 "$LINTER" --record-lint-result clean --nonce x --units-judged "5 of 3" r.md >/dev/null 2>&1
assert "a judged count above its own declared total exits 2" "$([ $? -eq 2 ]; echo $?)"

# --- a pre-upgrade nonce (minted before this flag existed) ------------------

REPO3="$(new_repo preupgrade)"
echo "# old" > "$REPO3/old.md"
git -C "$REPO3" add old.md
read -r OLD_NONCE _ <<< "$(nonce_for "$REPO3" old.md)"
python3 - "$REPO3/.git/swe/lint-nonces.json" "$OLD_NONCE" <<'PYEOF'
import json, sys
path, nonce = sys.argv[1], sys.argv[2]
with open(path) as f:
    store = json.load(f)
del store[nonce]["units"]
with open(path, "w") as f:
    json.dump(store, f)
PYEOF
OUT="$(cd "$REPO3" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$OLD_NONCE" --units-judged 1 old.md 2>&1)"
assert "a nonce with no stored units total exits 4" "$([ $? -eq 4 ]; echo $?)"
case "$OUT" in
  *"predates the unit worklist"*) assert "the refusal names the pre-upgrade nonce" 0 ;;
  *) assert "the refusal names the pre-upgrade nonce" 1 ;;
esac

# --- outside a git repository: no --units-judged needed --------------------

OUTSIDE_DIR="$(mktemp -d)"
echo "# outside" > "$OUTSIDE_DIR/x.md"
OUT="$(python3 "$LINTER" --record-lint-result clean "$OUTSIDE_DIR/x.md" 2>&1)"
assert "outside a git repo: recording with no --units-judged still exits 0" "$([ $? -eq 0 ]; echo $?)"
rm -rf "$OUTSIDE_DIR"

# --- the pre-commit hook blocks a partial row the same as a failed one -----

REPO4="$(new_repo hook)"
INSTALLER="$PLUGIN_ROOT/scripts/install-commit-hook.sh"
(cd "$REPO4" && "$INSTALLER" . >/dev/null 2>&1)
cat > "$REPO4/h.md" <<'MD'
# H

One.

Two.
MD
git -C "$REPO4" add h.md
read -r H_NONCE H_UNITS <<< "$(nonce_for "$REPO4" h.md)"
(cd "$REPO4" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$H_NONCE" --units-judged "1 of $H_UNITS" h.md >/dev/null 2>&1)
OUT="$(git -C "$REPO4" -c user.email=t@t.com -c user.name=t commit -q -m partial 2>&1)"
assert "a partial lint record blocks the commit, the same as failed" "$([ $? -ne 0 ]; echo $?)"
case "$OUT" in
  *"recorded status: partial"*) assert "the hook names the partial status" 0 ;;
  *) assert "the hook names the partial status" 1 ;;
esac

read -r H_NONCE2 H_UNITS2 <<< "$(nonce_for "$REPO4" h.md)"
(cd "$REPO4" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$H_NONCE2" --units-judged "$H_UNITS2" h.md >/dev/null 2>&1)
OUT="$(git -C "$REPO4" -c user.email=t@t.com -c user.name=t commit -q -m full 2>&1)"
assert "a full lint record unblocks the same commit" "$([ $? -eq 0 ]; echo $?)"

# --- a unit's own text renders links and code spans readably (claude-plugins#27) --

REPO5="$(new_repo links)"
cat > "$REPO5/links.md" <<'MD'
# The `retry` flag

See [Rotating the signing key](#rotating-the-signing-key).

Do **not** add `orders.write` to the read-only role.

`orders.read`, `orders.write` and `orders.admin` grant access to one service.

- See [the guide](https://example.com/guide) for setup.

A span with a link inside it: `[x](y)`.
MD
git -C "$REPO5" add links.md
LINKS_OUT="$(cd "$REPO5" && python3 "$LINTER" links.md --force-inference --quiet-vocab 2>&1)"
LINKS_UNITS="$(printf '%s\n' "$LINKS_OUT" | grep '\[inference-unit\]' | grep -v 'prose unit(s) follow')"

case "$LINKS_UNITS" in
  *'unit 1 of 6, heading, line 1: # The `retry` flag'*)
    assert "a heading's own code span stays verbatim" 0 ;;
  *) assert "a heading's own code span stays verbatim" 1 ;;
esac
case "$LINKS_UNITS" in
  *'unit 2 of 6, paragraph, line 3: See Rotating the signing key (link: #rotating-the-signing-key).'*)
    assert "an in-document link renders as text plus a resolved (link: target), brackets gone" 0 ;;
  *) assert "an in-document link renders as text plus a resolved (link: target), brackets gone" 1 ;;
esac
case "$LINKS_UNITS" in
  *'[Rotating'*) assert "no unit shows the link's broken opening bracket" 1 ;;
  *) assert "no unit shows the link's broken opening bracket" 0 ;;
esac
case "$LINKS_UNITS" in
  *'unit 3 of 6, paragraph, line 5: Do **not** add `orders.write` to the read-only role.'*)
    assert "a code span as the sentence object stays verbatim, not blanked" 0 ;;
  *) assert "a code span as the sentence object stays verbatim, not blanked" 1 ;;
esac
case "$LINKS_UNITS" in
  *'add              to'*) assert "no unit shows the code span blanked to spaces" 1 ;;
  *) assert "no unit shows the code span blanked to spaces" 0 ;;
esac
case "$LINKS_UNITS" in
  *'unit 4 of 6, paragraph, line 7: `orders.read`, `orders.write` and `orders.admin` grant access to one service.'*)
    assert "a list of code spans as the sentence subject stays verbatim (the #25 shape)" 0 ;;
  *) assert "a list of code spans as the sentence subject stays verbatim (the #25 shape)" 1 ;;
esac
case "$LINKS_UNITS" in
  *'unit 5 of 6, list-item, line 9: See the guide (link: https://example.com/guide) for setup.'*)
    assert "a link in a list item renders the same readable way" 0 ;;
  *) assert "a link in a list item renders the same readable way" 1 ;;
esac
case "$LINKS_UNITS" in
  *'unit 6 of 6, paragraph, line 11: A span with a link inside it: `[x](y)`.'*)
    assert "a link inside a code span is left alone, the span still verbatim" 0 ;;
  *) assert "a link inside a code span is left alone, the span still verbatim" 1 ;;
esac

# The deterministic tier still blanks code-span contents: an unknown word
# inside one of the spans above ("orders") must not be flagged, proving
# strip_noise()'s own blanking (used by check_line(), never readable_line())
# is unaffected by this change.
VOCAB_OUT="$(cd "$REPO5" && python3 "$LINTER" links.md 2>&1)"
case "$VOCAB_OUT" in
  *orders*) assert "the deterministic tier's own vocabulary check still never sees code-span contents" 1 ;;
  *) assert "the deterministic tier's own vocabulary check still never sees code-span contents" 0 ;;
esac

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
