#!/usr/bin/env bash
# PreToolUse on outbound-message MCP tools (Slack, Gmail send/reply/forward,
# `create_file`): checks the message body before it arrives at another
# person. Verified tool names in this Claude Code installation:
#   mcp__claude_ai_Gmail__send_message   (fields: body, htmlBody)
#   mcp__claude_ai_Gmail__reply          (fields: body, htmlBody)
#   mcp__claude_ai_Gmail__forward        (fields: body, htmlBody)
#   mcp__claude_ai_Google_Drive__create_file  (field: textContent)
# No Slack send tool exists in this session's tool registry to verify
# against (only authenticate/complete_authentication are present). The
# matcher below guesses the naming convention this integration otherwise
# follows (mcp__claude_ai_<Service>__<action>) so it starts working the
# moment such a tool is added, without needing this hook rewritten. See
# open question 6 in task9-enforcement-strategy.md.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LINTER="$HERE/../scripts/software_english_lint.py"
source "$HERE/_lib.sh"

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"
CWD="$(echo "$INPUT" | jq -r '.cwd // empty')"

TEXT=""
case "$TOOL_NAME" in
  mcp__claude_ai_Gmail__send_message|mcp__claude_ai_Gmail__reply|mcp__claude_ai_Gmail__forward)
    TEXT="$(echo "$INPUT" | jq -r '.tool_input.body // empty')"
    ;;
  mcp__claude_ai_Google_Drive__create_file)
    TEXT="$(echo "$INPUT" | jq -r '.tool_input.textContent // empty')"
    ;;
  mcp__claude_ai_Slack__send_message|mcp__claude_ai_Slack__post_message)
    TEXT="$(echo "$INPUT" | jq -r '.tool_input.text // .tool_input.message // empty')"
    ;;
  *) exit 0 ;;
esac

[ -n "$TEXT" ] || exit 0
hook_enabled '.hooks["mcp-send"]' "$CWD" || exit 0

if ! "$HERE/../scripts/fetch-software-english-data.sh" >&2; then
  exit 0
fi

OUTPUT="$(printf '%s' "$TEXT" | "$LINTER" --text --source-label "$TOOL_NAME" --advise-inference --quiet-vocab 2>&1)"
STATUS=$?
CLEAN_OUTPUT="$(strip_advise_marker "$OUTPUT")"
ADVISED=$?

report_and_maybe_block "$CLEAN_OUTPUT" "$STATUS" "mcp-send" \
  "Fix the text, then send it again." "pretooluse"

if [ "$STATUS" -eq 0 ] && [ "$ADVISED" -eq 0 ]; then
  SCRATCH_DIR="$HOME/.claude/swe/pending-inference"
  mkdir -p "$SCRATCH_DIR"
  SCRATCH_FILE="$SCRATCH_DIR/mcp-send-$(date +%s)-$$.txt"
  printf '%s' "$TEXT" > "$SCRATCH_FILE"
  advise_inference "Software English: the deterministic check passed for this outbound $TOOL_NAME message, and it is due an inference-tier pass. Dispatch a subagent (Agent tool) to run: python3 \"$HERE/../scripts/software_english_lint.py\" --text --source-label \"$TOOL_NAME\" --force-inference --quiet-vocab < \"$SCRATCH_FILE\". It only reports findings, it does not fix anything. The message has already been sent by the time this runs, so it cannot be un-sent; read what it reports so you know for next time. Delete $SCRATCH_FILE once you are done with it." \
    "pretooluse"
fi
exit 0
