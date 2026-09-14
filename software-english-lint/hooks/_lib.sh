#!/usr/bin/env bash
# Shared by every hook script here. Warnings are never shown to Claude
# or the user (advisory tier, non-blocking by design); an error-severity
# finding gets a JSON response on stdout with a one-line count plus a
# report file path, not the full per-line dump. The detail is only
# useful when fixing something, so the agent reads the file itself.
#
# Always exits 0. Both Claude Code and Copilot CLI read a block decision
# from stdout JSON, not from stderr or the exit code (Claude Code even
# ignores stdout JSON on a nonzero exit), so a block decision must
# always travel as JSON on stdout with exit 0.
#
# Harness detection: Claude Code sets CLAUDECODE=1 in every process it
# spawns, hook scripts included (verified directly, not documented).
# Copilot CLI sets no equivalent env var, so its absence is read as
# Copilot. This has only been tested under Claude Code; the Copilot
# branch is unverified against a real Copilot session.
is_claude_code() {
  [ "${CLAUDECODE:-}" = "1" ]
}

# PreToolUse and Stop schemas are confirmed from each harness's own
# hooks reference. PostToolUse cannot block in Copilot CLI (the tool
# already ran by the time the hook fires): it only supports
# `additionalContext`, an advisory-only field, so a Copilot PostToolUse
# finding is shown to the agent but does not force a retry the way it
# does under Claude Code.
report_and_maybe_block() {
  local output="$1" status="$2" stem="$3" trailer="$4" hook_type="$5"

  [ -z "$output" ] && return 0
  [ "$output" = "No sources to check." ] && return 0
  [ "$status" -eq 0 ] && return 0

  local dir="$HOME/.claude/software-english-lint/reports"
  mkdir -p "$dir"
  local file="$dir/$stem.txt"
  printf '%s\n' "$output" > "$file"

  local errors warnings
  errors="$(grep -c '\[error\]' <<<"$output")"
  warnings="$(grep -c '\[warning\]' <<<"$output")"

  local reason
  reason="$(printf '%s Software English error(s), %s warning(s). Details: %s\n\n%s' \
    "$errors" "$warnings" "$file" "$trailer")"

  if is_claude_code; then
    case "$hook_type" in
      stop)
        jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
        ;;
      pretooluse)
        jq -n --arg reason "$reason" \
          '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
        ;;
      posttooluse)
        jq -n --arg reason "$reason" \
          '{hookSpecificOutput: {hookEventName: "PostToolUse", decision: "block", reason: $reason}}'
        ;;
    esac
  else
    case "$hook_type" in
      stop)
        jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
        ;;
      pretooluse)
        jq -n --arg reason "$reason" \
          '{permissionDecision: "deny", permissionDecisionReason: $reason}'
        ;;
      posttooluse)
        jq -n --arg reason "$reason" '{additionalContext: $reason}'
        ;;
    esac
  fi
}
