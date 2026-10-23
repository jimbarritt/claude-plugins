#!/usr/bin/env bash
# Covers the not-human-subject check on anthropomorphism-fixed-list
# (software-english#20): the rule fires unless a human referent precedes
# the match in the same clause, so a proper-noun subject ("Postgres knows")
# and a pronoun subject ("it knows") fire, a human subject ("the user
# knows", "reviewers disagree") stays clean, and an imperative, a noun use
# after a determiner, or a possessive does not count as a subject. Also
# covers the catalogue-driven switch: a rule entry with no subject_gate
# field keeps the older system-subject check, so an older pinned tag
# behaves as before.
#
# Runs twice: against real Software English data (SWE_SRC=<checkout>, or
# the tag pinned in software-english.json; skips that half with exit 0 if
# neither is available), and against a scratch catalogue for the switch.
#
# Run: swe/tests/anthropomorphism_gate_test.sh
#      SWE_SRC=/path/to/software-english swe/tests/anthropomorphism_gate_test.sh
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
fires() {  # fires <fixture> <sentence> <word>: an anthropomorphism finding for exactly that word
  local out
  out="$(lint "$1" "$2")"
  grep -qF "[anthropomorphism] \"$3\"" <<<"$out"
}
clean() {  # clean <fixture> <sentence>: no anthropomorphism finding
  local out
  out="$(lint "$1" "$2")"
  ! grep -qF '[anthropomorphism]' <<<"$out"
}
location() {  # location <fixture> <sentence> <word>: an abstract-location finding
  local out
  out="$(lint "$1" "$2")"
  grep -qF "[abstract-location] \"$3\"" <<<"$out"
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
  assert "precondition: the catalogue entry uses the not-human-subject check" \
    "$(grep -q 'subject_gate = "not-human-subject"' "$REAL/data/core-rules.toml"; echo $?)"

  # --- the issue's own examples ---
  assert "fires: the worker asks the database" "$(fires "$REAL" 'The worker asks the database whether the feature is enabled.' 'asks'; echo $?)"
  assert "fires: the two parsers disagree" "$(fires "$REAL" 'The two parsers disagree on the field type.' 'disagree'; echo $?)"
  assert "fires: the flag is what tells" "$(fires "$REAL" 'The flag is what tells a generated row from a submitted one.' 'tells'; echo $?)"
  assert "fires: the record arrives" "$(fires "$REAL" 'The record arrives with a default status.' 'arrives'; echo $?)"
  assert "fires: both totals arrive" "$(fires "$REAL" 'Both totals arrive as fields on the request.' 'arrive'; echo $?)"

  # --- a proper noun or a pronoun is a system subject ---
  assert "fires: Postgres knows about the row" "$(fires "$REAL" 'Postgres knows about the row.' 'knows'; echo $?)"
  assert "fires: Stripe tells the webhook" "$(fires "$REAL" 'Stripe tells the webhook about the refund.' 'tells'; echo $?)"
  assert "fires: it knows the row" "$(fires "$REAL" 'It knows the row.' 'knows'; echo $?)"
  assert "fires: this decides the retry count" "$(fires "$REAL" 'This decides the retry count.' 'decides'; echo $?)"
  assert "fires: the schema does not move" "$(fires "$REAL" 'The schema does not move.' 'move'; echo $?)"

  # --- a human referent in an earlier clause does not reach across the boundary ---
  assert "fires: if the user asks, the service knows" "$(fires "$REAL" 'If the user asks, the service knows the answer.' 'knows'; echo $?)"
  assert "fires: the possessive user's database knows" "$(fires "$REAL" "The user's database knows the schema." 'knows'; echo $?)"

  # --- a human subject stays clean ---
  assert "clean: the user knows the password" "$(clean "$REAL" 'The user knows the password.'; echo $?)"
  assert "clean: users know the password (plural)" "$(clean "$REAL" 'Users know the password.'; echo $?)"
  assert "clean: reviewers disagree on the name" "$(clean "$REAL" 'Reviewers disagree on the name.'; echo $?)"
  assert "clean: the reviewer expects a passing test" "$(clean "$REAL" 'The reviewer expects a passing test.'; echo $?)"
  assert "clean: a reader who knows the spec" "$(clean "$REAL" 'A reader who knows the spec can skip this section.'; echo $?)"
  assert "clean: if you disagree, open an issue" "$(clean "$REAL" 'If you disagree, open an issue.'; echo $?)"
  assert "clean: the operator moves the file" "$(clean "$REAL" 'The operator moves the file to the archive.'; echo $?)"

  # --- no subject: an imperative, an infinitive, a determiner before a noun ---
  assert "clean: tell the user the build failed" "$(clean "$REAL" 'Tell the user the build failed.'; echo $?)"
  assert "clean: do not tell the user" "$(clean "$REAL" 'Do not tell the user.'; echo $?)"
  assert "clean: do not leave a heading empty" "$(clean "$REAL" 'A heading is always followed by content; do not leave a heading empty.'; echo $?)"
  assert "clean: to enter the value, press Return" "$(clean "$REAL" 'To enter the value, press Return.'; echo $?)"
  assert "clean: the answers are in the log" "$(clean "$REAL" 'The answers are in the log.'; echo $?)"
  assert "clean: a move of the file" "$(clean "$REAL" 'A move of the file to another directory is not tracked.'; echo $?)"
  assert "clean: a quoted word list" "$(clean "$REAL" 'Never give a system a human trait: no "wants", "tries", "knows".'; echo $?)"

  # --- abstract-location keeps the system-subject check ---
  assert "location fires: a rule sits in one tier" "$(location "$REAL" 'A rule sits in one tier.' 'sits'; echo $?)"
  assert "location clean: the operator sits at the console" "$(! location "$REAL" 'The operator sits at the console.' 'sits'; echo $?)"
  assert "location clean: Postgres is a live database" "$(! location "$REAL" 'Postgres is a live database.' 'live'; echo $?)"
fi

# ---------------------------------------------------------------------------
# Part 2: the catalogue switch, with a scratch catalogue
# ---------------------------------------------------------------------------
scratch_catalogue() {  # scratch_catalogue <dir> <extra anthropomorphism fields>
  mkdir -p "$1/data"
  : > "$1/data/banned.tsv"
  printf 'word\tdefinition\ndatabase\tthe store\nrow\tone record\n' > "$1/data/structure.tsv"
  for name in operations qualities connectives; do printf 'word\tdefinition\n' > "$1/data/$name.tsv"; done
  cat > "$1/data/core-rules.toml" <<EOF
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
word_list = ["knows"]
severity = "error"
$2

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

OLD="$TMP/old"
make_fixture "$OLD"
scratch_catalogue "$OLD" ""
assert "older catalogue, no subject_gate: Postgres knows stays clean" "$(clean "$OLD" 'Postgres knows the row.'; echo $?)"
assert "older catalogue, no subject_gate: the database knows fires" "$(fires "$OLD" 'The database knows the row.' 'knows'; echo $?)"

NEW="$TMP/new"
make_fixture "$NEW"
scratch_catalogue "$NEW" 'subject_gate = "not-human-subject"
human_referents = ["user"]'
assert "not-human-subject, empty human list: Postgres knows fires" "$(fires "$NEW" 'Postgres knows the row.' 'knows'; echo $?)"
assert "not-human-subject: the user knows stays clean" "$(clean "$NEW" 'The user knows the row.'; echo $?)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
