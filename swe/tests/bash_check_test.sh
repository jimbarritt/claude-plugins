#!/usr/bin/env bash
# Covers the PreToolUse Bash hook (hooks/bash-check.sh): the text it
# extracts from a `git commit`/`gh pr`/`gh issue` call, and in
# particular that it never lints a message file whose path the same
# command also names before that call (claude-plugins#30).
# Deterministic and offline: runs against a fixture copy of the plugin
# with a small data/core-rules.toml and a data/.fetched-tag already in
# place, so scripts/fetch-software-english-data.sh exits at its marker
# check (line 21) without touching the network. Never touches the
# real $HOME or the installed plugin's own data/.
#
# Run: swe/tests/bash_check_test.sh
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

# --- fixture plugin: hooks/ + scripts/ + config.json + a pinned,
#     already-cached rule catalogue (no network) --------------------------

FIXTURE="$TMP/plugin"
mkdir -p "$FIXTURE"
cp -r "$PLUGIN_ROOT/hooks" "$FIXTURE/hooks"
cp -r "$PLUGIN_ROOT/scripts" "$FIXTURE/scripts"
cp "$PLUGIN_ROOT/config.json" "$FIXTURE/config.json"
cat > "$FIXTURE/software-english.json" <<'EOF'
{ "repo": "jimbarritt/software-english", "tag": "v0.0.0-test" }
EOF
mkdir -p "$FIXTURE/data"
echo "v0.0.0-test" > "$FIXTURE/data/.fetched-tag"
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
word_list = ["wants"]
subject_gate = "not-human-subject"
human_referents = []
severity = "error"

[[rules]]
id = "abstract-location"
lookback_words = 3
word_list = []
severity = "warning"

[[rules]]
id = "vocabulary-membership"
severity = "warning"
TOML

HOME_DIR="$TMP/home"
mkdir -p "$HOME_DIR"
WORK="$TMP/work"
mkdir -p "$WORK"

FAULTY="The service wants a token before it proceeds."
CLEAN="The service requires a token before it proceeds."

run_hook() {  # run_hook <command> -- prints the hook's stdout, sets $STATUS
  local cmd="$1"
  OUT="$(cd "$WORK" && jq -n --arg c "$cmd" --arg d "$WORK" '{cwd:$d, tool_input:{command:$c}}' \
    | HOME="$HOME_DIR" CLAUDECODE=1 SWE_LINT_CONFIG="$FIXTURE/config.json" "$FIXTURE/hooks/bash-check.sh")"
  STATUS=$?
}

denies() { [ "$STATUS" -eq 0 ] && [[ "$OUT" == *'"permissionDecision": "deny"'* ]]; }
passes() { [ "$STATUS" -eq 0 ] && [[ "$OUT" != *'"permissionDecision": "deny"'* ]]; }
silent() { [ "$STATUS" -eq 0 ] && [ -z "$OUT" ]; }

# --- positive control: the fixture rule actually fires -------------------

run_hook "git commit -m \"$FAULTY\""
assert "positive control: a faulty -m message is denied" "$(denies; echo $?)"

# --- issue's three original fixtures (regressions; already true on the
#     code before this change, since the gate and extraction already
#     existed) ---------------------------------------------------------

echo "$FAULTY" > "$WORK/f.md"
run_hook 'gh issue create --title "Fix the thing" --body-file f.md'
assert "fixture 1: gh issue create --body-file with a fault in the file: denied" "$(denies; echo $?)"

PYCMD=$'python3 -c "\ns = open(\'body.md\').read()\ns = s.replace(\'the service wants a token\', \'the service requires a token\')\nopen(\'body.md\', \'w\').write(s)\n"'
run_hook "$PYCMD"
assert "fixture 2: standalone python3 -c replace(): silent" "$(silent; echo $?)"

run_hook "sed -i 's/the service wants/the service requires/' f.md"
assert "fixture 3: standalone sed -i: silent" "$(silent; echo $?)"

# --- the confirmed bug: a stale -F/--body-file read is no longer linted,
#     so the command that fixes the fault is not blocked for still
#     containing it (claude-plugins#30) ----------------------------------

echo "$FAULTY" > "$WORK/body.md"
run_hook "sed -i 's/the service wants a token/the service requires a token/' body.md && git commit -F body.md"
assert "sed fixes body.md then commits -F it: silent, not blocked" "$(silent; echo $?)"
assert "the hook never ran the sed: body.md is unchanged" "$([ "$(cat "$WORK/body.md")" = "$FAULTY" ]; echo $?)"

echo "$FAULTY" > "$WORK/body.md"
PYCMD2=$'python3 -c "\ns = open(\'body.md\').read()\ns = s.replace(\'the service wants a token\', \'the service requires a token\')\nopen(\'body.md\', \'w\').write(s)\n" && git commit -F body.md'
run_hook "$PYCMD2"
assert "python3 fixes body.md then commits -F it: silent, not blocked" "$(silent; echo $?)"

echo "$CLEAN" > "$WORK/body4.md"
run_hook "$(printf "cat > body4.md <<'EOF'\n%s\nEOF\ngh pr create --title \"Clean title\" --body-file body4.md" "$FAULTY")"
assert "heredoc overwrites a stale faulty body4.md before gh pr create reads it: silent" "$(silent; echo $?)"

# --- skipping a stale file never skips an inline title (claude-plugins#30
#     defect 3: --title used to be dropped whenever --body-file was read) -

echo "$CLEAN" > "$WORK/body4.md"
run_hook "$(printf "cat > body4.md <<'EOF'\n%s\nEOF\ngh pr create --title \"%s\" --body-file body4.md" "$CLEAN" "$FAULTY")"
assert "title is still linted even though the stale body-file read is skipped: denied" "$(denies; echo $?)"

echo "$CLEAN" > "$WORK/f2.md"
run_hook "gh issue create --title \"$FAULTY\" --body-file f2.md"
assert "a faulty title alongside a clean body-file: denied (title is no longer dropped)" "$(denies; echo $?)"

# --- flag scoping: a flag from an unrelated earlier command is never
#     read as the git/gh call's own flag (claude-plugins#30 defect 2) -----

echo "wants" > "$WORK/notes.txt"
echo "$CLEAN" > "$WORK/body2.md"
run_hook "grep -F wants notes.txt; git commit -F body2.md"
assert "an earlier grep -F is not mistaken for the commit's -F: clean body2.md passes" "$(passes; echo $?)"

echo "$FAULTY" > "$WORK/body2.md"
run_hook "grep -F wants notes.txt; git commit -F body2.md"
assert "the real -F target is still read correctly: faulty body2.md still denied" "$(denies; echo $?)"

run_hook 'echo "the service wants" > /dev/null && git commit -m "Clean message"'
assert "flagged text before the git call, outside any flag, is never linted: passes" "$(passes; echo $?)"

# --- no identifiable message: skipped, per the issue's own proposal 2 ----

run_hook "git commit --amend --no-edit"
assert "no -m/--title/--body/-F at all: silent" "$(silent; echo $?)"

run_hook "git commit -F -"
assert "-F - (stdin): silent, no attempt to read a file literally named '-'" "$(silent; echo $?)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
