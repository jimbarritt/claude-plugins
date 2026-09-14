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

if ! "$HERE/../scripts/fetch-software-english-data.sh" >&2; then
  exit 0
fi

OUTPUT="$(printf '%s' "$TEXT" | "$LINTER" --text --source-label "$TOOL_NAME" --run-inference --quiet-vocab 2>&1)"
STATUS=$?

report_and_maybe_block "$OUTPUT" "$STATUS" "mcp-send" \
  "Fix the text, then send it again." "pretooluse"
exit 0
