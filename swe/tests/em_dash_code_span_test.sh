#!/usr/bin/env bash
# Covers the code-span exception to no-em-dash (software-english#27): the
# deterministic tier blanks a code span's contents before the blanket
# [error] no-em-dash count runs, so an em dash inside one never used to be
# a finding. A second, narrower check now looks inside the kept code span
# and reports a [warning] no-em-dash finding there, but only when the span
# reads as natural-language text: has a space, is mostly letters/digits/
# spaces, and shows none of four exemption signals (reads as code; no
# space touches the dash itself; opens with "the"/"a"/"an"; carries an
# inner quote mark). The warning never widens the blanket error check: a
# dash inside a code span is blanked on that check's own view of the
# line and is only ever counted once, by whichever of the two checks can
# see it.
#
# The three exemption signals beyond "reads as code" exist because the
# plain "has a space and is mostly letters" test alone would also warn on
# two real spans already in this repository: a quoted fault example in
# docs/public/presentations/intro/intro-to-software-english.md's own
# habit-catalogue table, and the IEEE standard's title quoted in
# templates/design.md. Both are covered below against SWE_SRC when it is
# the software-english checkout.
#
# Runs twice: against real Software English data (SWE_SRC=<checkout>, or
# the tag pinned in software-english.json; skips that half with exit 0 if
# neither is available), and against a scratch catalogue for the
# catalogue-driven switch (code_span_severity present vs. absent).
#
# Run: swe/tests/em_dash_code_span_test.sh
#      SWE_SRC=/path/to/software-english swe/tests/em_dash_code_span_test.sh
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

make_fixture() {  # make_fixture <dir>: a plugin copy with no data yet
  mkdir -p "$1"
  cp -r "$PLUGIN_ROOT/scripts" "$1/scripts"
  cp "$PLUGIN_ROOT/config.json" "$PLUGIN_ROOT/software-english.json" "$1/"
}

# The linter exits non-zero on a finding, so its output is captured into a
# variable rather than piped straight into grep under `pipefail`.
lint() { printf '%s\n' "$2" | python3 -B "$1/scripts/software_english_lint.py" --text --source-label t --quiet-vocab; }
warns() {  # warns <fixture> <text>: exactly one [warning] [no-em-dash], no [error] [no-em-dash]
  local out
  out="$(lint "$1" "$2")"
  [ "$(grep -c '\[warning\] \[no-em-dash\]' <<<"$out")" -eq 1 ] && [ "$(grep -c '\[error\] \[no-em-dash\]' <<<"$out")" -eq 0 ]
}
clean_of_em_dash() {  # clean_of_em_dash <fixture> <text>: no no-em-dash finding at all
  local out
  out="$(lint "$1" "$2")"
  ! grep -q '\[no-em-dash\]' <<<"$out"
}
errors() {  # errors <fixture> <text> <n>: exactly n [error] [no-em-dash], no warning
  local out n
  out="$(lint "$1" "$2")"
  n="$3"
  [ "$(grep -c '\[error\] \[no-em-dash\]' <<<"$out")" -eq "$n" ]
}

# ---------------------------------------------------------------------------
# Part 1: the real catalogue
# ---------------------------------------------------------------------------
REAL="$TMP/real"
make_fixture "$REAL"
if [ -n "${SWE_SRC:-}" ]; then
  mkdir -p "$REAL/data"
  cp "$SWE_SRC"/vocabulary/*.tsv "$REAL/data/"
  cp "$SWE_SRC"/rules/core-rules.toml "$REAL/data/"
elif ! "$REAL/scripts/fetch-software-english-data.sh" >/dev/null 2>&1; then
  echo "SKIP (real data): no SWE_SRC and the pinned software-english tag could not be fetched"
  REAL=""
fi

if [ -n "$REAL" ]; then
  assert "precondition: the catalogue entry carries code_span_severity" \
    "$(grep -q 'code_span_severity' "$REAL/data/core-rules.toml"; echo $?)"

  # --- the issue's own motivating case: a sample display value ---
  assert "warns: a sample display value (the issue's own example)" \
    "$(warns "$REAL" '| Field | Example |
|---|---|
| Display name | `2 — Main Office` |'; echo $?)"
  assert "warns: a sample message" \
    "$(warns "$REAL" 'The log line is `Saved — 3 files.`'; echo $?)"

  # --- code-shape exemptions, from the issue's own fixtures ---
  assert "clean: a CLI flag with no space" "$(clean_of_em_dash "$REAL" 'Set `--separator=—` on the command.'; echo $?)"
  assert "clean: an identifier with no space" "$(clean_of_em_dash "$REAL" 'The field is named `row—id`.'; echo $?)"
  assert "clean: a function call" "$(clean_of_em_dash "$REAL" 'Call `fmt(a) — b` to format it.'; echo $?)"
  assert "clean: a namespaced name" "$(clean_of_em_dash "$REAL" 'See `a::b — c` for the member.'; echo $?)"
  assert "clean: an arrow" "$(clean_of_em_dash "$REAL" 'The type is `x -> y — z`.'; echo $?)"
  assert "clean: a path" "$(clean_of_em_dash "$REAL" 'Read from `path/to — x`.'; echo $?)"
  assert "clean: a flag with a space in its value" "$(clean_of_em_dash "$REAL" 'Pass `--title Main — Office` on the command.'; echo $?)"
  assert "clean: a fenced block" \
    "$(clean_of_em_dash "$REAL" '```
has — dash
```'; echo $?)"

  # --- the three signals beyond "reads as code" ---
  assert "clean: no space touches the dash (a title/compound)" \
    "$(clean_of_em_dash "$REAL" 'Cite `IEEE Standard for Information Technology—Systems Design—Software Design Descriptions`.'; echo $?)"
  assert "clean: opens with an article (a quoted fault example)" \
    "$(clean_of_em_dash "$REAL" '| Habit | Example |
|---|---|
| The em dash | `the Messages resource — the beating heart` |'; echo $?)"
  assert "clean: carries an inner quote mark (a quoted fault example)" \
    "$(clean_of_em_dash "$REAL" '| Habit | Example |
|---|---|
| Contrast | `It'"'"'s not about which format is "best" — it'"'"'s about ...` |'; echo $?)"
  assert "clean: a low letter/digit ratio fails the text test" \
    "$(clean_of_em_dash "$REAL" 'Marker list: `* — * — *`'; echo $?)"

  # --- no double count, and the blanket error check is unaffected ---
  assert "exactly one error, one warning on a mixed line" \
    "$(out="$(lint "$REAL" 'The value is `2 — Main Office` — see above.')"; [ "$(grep -c '\[error\] \[no-em-dash\]' <<<"$out")" -eq 1 ] && [ "$(grep -c '\[warning\] \[no-em-dash\]' <<<"$out")" -eq 1 ]; echo $?)"
  assert "error check unaffected: a plain prose em dash still errors" \
    "$(errors "$REAL" 'The prose is dense — read it twice.' 1; echo $?)"

  # --- existing exemptions still apply ---
  assert "clean: a blockquote" \
    "$(clean_of_em_dash "$REAL" '> quoted — material here'; echo $?)"
  assert "clean: a skip-marker line" \
    "$(clean_of_em_dash "$REAL" 'Sample: `2 — Main Office` here <!-- swe: ignore -->'; echo $?)"
fi

# ---------------------------------------------------------------------------
# Part 2: the catalogue switch, with a scratch catalogue
# ---------------------------------------------------------------------------
scratch_catalogue() {  # scratch_catalogue <dir> <extra no-em-dash fields>
  mkdir -p "$1/data"
  : > "$1/data/banned.tsv"
  for name in structure operations qualities connectives; do printf 'word\tdefinition\n' > "$1/data/$name.tsv"; done
  cat > "$1/data/core-rules.toml" <<EOF
[[rules]]
id = "banned-word"
severity = "error"

[[rules]]
id = "no-em-dash"
character = "—"
severity = "error"
$2

[[rules]]
id = "sentence-length"
max_words = 200
severity = "warning"

[[rules]]
id = "no-continuous-tense"
pattern = "\\\\b(is|are|was|were)\\\\s+(\\\\w+ing)\\\\b"
stoplist = []
severity = "warning"

[[rules]]
id = "no-perfect-tense-for-behaviour"
pattern = "\\\\b(has|have|had)\\\\s+(\\\\w+ed)\\\\b"
stoplist = []
severity = "warning"

[[rules]]
id = "anthropomorphism-fixed-list"
lookback_words = 4
word_list = []
severity = "error"

[[rules]]
id = "abstract-location"
lookback_words = 4
word_list = []
severity = "error"

[[rules]]
id = "vocabulary-membership"
severity = "warning"

[exemptions]
skip_line_marker = "<!-- swe: ignore -->"
structural_exclusions = []
EOF
}

NEWFIELD="$TMP/newfield"
make_fixture "$NEWFIELD"
scratch_catalogue "$NEWFIELD" 'code_span_severity = "warning"'
assert "code_span_severity present: a sample value warns, not errors" \
  "$(warns "$NEWFIELD" 'The value is `2 — Main Office`.'; echo $?)"

ERRFIELD="$TMP/errfield"
make_fixture "$ERRFIELD"
scratch_catalogue "$ERRFIELD" 'code_span_severity = "error"'
assert "code_span_severity = error: a sample value errors, not warns" \
  "$(errors "$ERRFIELD" 'The value is `2 — Main Office`.' 1; echo $?)"

NOFIELD="$TMP/nofield"
make_fixture "$NOFIELD"
scratch_catalogue "$NOFIELD" ""
assert "no code_span_severity field (older pin): defaults to warning" \
  "$(warns "$NOFIELD" 'The value is `2 — Main Office`.'; echo $?)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
