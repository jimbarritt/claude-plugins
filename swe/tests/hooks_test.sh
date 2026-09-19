#!/usr/bin/env bash
# Unit tests for the per-hook config toggle: hook_enabled() in
# hooks/_lib.sh, and each hook script's early exit when its key is
# disabled. Deterministic and offline: no network call, no `claude` or
# `git` needed, since a disabled hook exits before either runs.
#
# Run: swe/tests/hooks_test.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
HOOKS="$HERE/../hooks"

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $desc"
    echo "  expected: $expected"
    echo "  actual:   $actual"
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FIXTURE_CONFIG="$TMP/config.json"
PROJECT="$TMP/project"
mkdir -p "$PROJECT/.claude"

# --- hook_enabled(): plugin-config default, project override, precedence ---

HERE="$HOOKS"
export SWE_LINT_CONFIG="$FIXTURE_CONFIG"
# shellcheck disable=SC1091
source "$HOOKS/_lib.sh"

cat > "$FIXTURE_CONFIG" <<'EOF'
{ "hooks": { "bash": true, "artifact": true } }
EOF

hook_enabled '.hooks.bash' "$PROJECT"
assert_eq "no project file: falls back to plugin default (true)" "0" "$?"

cat > "$PROJECT/.claude/swe-lint.json" <<'EOF'
{ "hooks": { "bash": false } }
EOF
hook_enabled '.hooks.artifact' "$PROJECT"
assert_eq "project file present, key absent: falls back to plugin default" "0" "$?"
hook_enabled '.hooks.bash' "$PROJECT"
assert_eq "project sets false: disabled" "1" "$?"

cat > "$FIXTURE_CONFIG" <<'EOF'
{ "hooks": { "bash": false } }
EOF
cat > "$PROJECT/.claude/swe-lint.json" <<'EOF'
{ "hooks": { "bash": true } }
EOF
hook_enabled '.hooks.bash' "$PROJECT"
assert_eq "project true overrides plugin false" "0" "$?"

cat > "$FIXTURE_CONFIG" <<'EOF'
{ "hooks": { "stop": { "reply": true, "docs": true } } }
EOF
cat > "$PROJECT/.claude/swe-lint.json" <<'EOF'
{ "hooks": { "stop": { "docs": false } } }
EOF
hook_enabled '.hooks.stop.reply' "$PROJECT"
assert_eq "nested key untouched by project: falls back, enabled" "0" "$?"
hook_enabled '.hooks.stop.docs' "$PROJECT"
assert_eq "nested key disabled by project" "1" "$?"

cat > "$FIXTURE_CONFIG" <<'EOF'
{ "hooks": { "mcp-send": false } }
EOF
rm -f "$PROJECT/.claude/swe-lint.json"
hook_enabled '.hooks["mcp-send"]' "$PROJECT"
assert_eq "hyphenated key needs jq bracket syntax" "1" "$?"

hook_enabled '.hooks.bash' ""
assert_eq "no cwd: fails open, enabled" "0" "$?"

unset SWE_LINT_CONFIG

# --- Full hooks: disabled exits 0 with empty stdout, no network needed ---

cat > "$FIXTURE_CONFIG" <<'EOF'
{
  "hooks": {
    "stop": { "reply": false, "docs": false },
    "file": false,
    "bash": false,
    "artifact": false,
    "mcp-send": false
  }
}
EOF
rm -f "$PROJECT/.claude/swe-lint.json"

run_disabled_hook() {
  local script="$1" payload="$2"
  echo "$payload" | SWE_LINT_CONFIG="$FIXTURE_CONFIG" "$HOOKS/$script"
}

OUT="$(run_disabled_hook stop-check.sh "{\"cwd\": \"$PROJECT\", \"last_assistant_message\": \"hello\"}")"
assert_eq "stop-check.sh disabled: exit 0" "0" "$?"
assert_eq "stop-check.sh disabled: no stdout" "" "$OUT"

DUMMY_MD="$PROJECT/note.md"
echo "hello" > "$DUMMY_MD"
OUT="$(run_disabled_hook file-check.sh "{\"cwd\": \"$PROJECT\", \"tool_input\": {\"file_path\": \"$DUMMY_MD\"}}")"
assert_eq "file-check.sh disabled: exit 0" "0" "$?"
assert_eq "file-check.sh disabled: no stdout" "" "$OUT"

OUT="$(run_disabled_hook bash-check.sh "{\"cwd\": \"$PROJECT\", \"tool_input\": {\"command\": \"git commit -m fix\"}}")"
assert_eq "bash-check.sh disabled: exit 0" "0" "$?"
assert_eq "bash-check.sh disabled: no stdout" "" "$OUT"

DUMMY_ART="$PROJECT/page.md"
echo "hello" > "$DUMMY_ART"
OUT="$(run_disabled_hook artifact-check.sh "{\"cwd\": \"$PROJECT\", \"tool_input\": {\"action\": \"publish\", \"file_path\": \"$DUMMY_ART\"}}")"
assert_eq "artifact-check.sh disabled: exit 0" "0" "$?"
assert_eq "artifact-check.sh disabled: no stdout" "" "$OUT"

OUT="$(run_disabled_hook mcp-send-check.sh "{\"cwd\": \"$PROJECT\", \"tool_name\": \"mcp__claude_ai_Gmail__send_message\", \"tool_input\": {\"body\": \"hello\"}}")"
assert_eq "mcp-send-check.sh disabled: exit 0" "0" "$?"
assert_eq "mcp-send-check.sh disabled: no stdout" "" "$OUT"

# --- stop-check.sh: reply check skips under Claude Code, output style
#     covers it there; Copilot CLI keeps the config-gated check ---

cat > "$FIXTURE_CONFIG" <<'EOF'
{
  "hooks": {
    "stop": { "reply": true, "docs": false }
  }
}
EOF
rm -f "$PROJECT/.claude/swe-lint.json"

VIOLATION='{"cwd": "'"$PROJECT"'", "last_assistant_message": "a b — c"}'

OUT="$(echo "$VIOLATION" | SWE_LINT_CONFIG="$FIXTURE_CONFIG" CLAUDECODE=1 "$HOOKS/stop-check.sh")"
assert_eq "stop-check.sh under Claude Code: reply check skipped, no block" "" "$OUT"

OUT="$(echo "$VIOLATION" | SWE_LINT_CONFIG="$FIXTURE_CONFIG" env -u CLAUDECODE "$HOOKS/stop-check.sh")"
case "$OUT" in
  *'"decision": "block"'*) assert_eq "stop-check.sh under Copilot CLI: reply check still runs, blocks" "blocked" "blocked" ;;
  *) assert_eq "stop-check.sh under Copilot CLI: reply check still runs, blocks" "blocked" "$OUT" ;;
esac

# --- strip_advise_block()/extract_advise_rules(): separate the linter's
#     fenced INFERENCE_ADVISED rules block from the rest of a hook's
#     output ---

BLOCK_OUTPUT="$(printf 'line one\n===INFERENCE_ADVISED===\n- rule-a: desc a\n- rule-b: desc b\n===END_INFERENCE_ADVISED===\nline two')"
CLEAN="$(strip_advise_block "$BLOCK_OUTPUT")"
RULES="$(extract_advise_rules "$BLOCK_OUTPUT")"
assert_eq "strip_advise_block: block present, removed from report" "$(printf 'line one\nline two')" "$CLEAN"
assert_eq "extract_advise_rules: block present, rules extracted" "$(printf -- '- rule-a: desc a\n- rule-b: desc b')" "$RULES"

NO_BLOCK_OUTPUT="$(printf 'line one\nline two')"
CLEAN="$(strip_advise_block "$NO_BLOCK_OUTPUT")"
RULES="$(extract_advise_rules "$NO_BLOCK_OUTPUT")"
assert_eq "strip_advise_block: no block, output unchanged" "$(printf 'line one\nline two')" "$CLEAN"
assert_eq "extract_advise_rules: no block, empty" "" "$RULES"

# --- advise_inference(): non-blocking shape, both harnesses, both hook types ---

OUT="$(CLAUDECODE=1 advise_inference "check this" "pretooluse")"
case "$OUT" in
  *'"permissionDecision": "allow"'*'"systemMessage": "check this"'*) assert_eq "advise_inference: Claude Code pretooluse allows with a systemMessage" "0" "0" ;;
  *) assert_eq "advise_inference: Claude Code pretooluse allows with a systemMessage" "0" "1: $OUT" ;;
esac

OUT="$(unset CLAUDECODE; advise_inference "check this" "posttooluse")"
assert_eq "advise_inference: Copilot posttooluse uses additionalContext" \
  '{"additionalContext":"check this"}' "$(echo "$OUT" | jq -c .)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
