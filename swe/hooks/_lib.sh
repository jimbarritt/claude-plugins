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

# Returns 1 when <jq-path> (e.g. '.hooks.stop.reply' or '.hooks["mcp-send"]')
# resolves to false: the project's <cwd>/.claude/swe-lint.json if it sets
# that path, else the plugin's own config.json ($SWE_LINT_CONFIG when set,
# for tests, else "$HERE/../config.json"). Any other case (no cwd, missing
# file, missing path, bad JSON) resolves to true (fail open, matching every
# hook's behaviour before this toggle existed).
#
# Deliberately not "<jq-path> // empty": jq's // treats a literal `false`
# the same as null/missing, which would make an explicit false at the
# project layer fall through to the plugin default instead of disabling
# the check. Read the raw value and check for the string "null" instead.
hook_enabled() {
  local jq_path="$1" cwd="$2"
  local plugin_config="${SWE_LINT_CONFIG:-$HERE/../config.json}"
  local project_file="$cwd/.claude/swe-lint.json"
  local val=""
  if [ -n "$cwd" ] && [ -f "$project_file" ]; then
    val="$(jq -r "$jq_path" "$project_file" 2>/dev/null)"
  fi
  if [ -z "$val" ] || [ "$val" = "null" ]; then
    val="$(jq -r "$jq_path" "$plugin_config" 2>/dev/null)"
  fi
  [ "$val" != "false" ]
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

  local dir="$HOME/.claude/swe/reports"
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

# The linter prints a fenced ===INFERENCE_ADVISED===...===END_INFERENCE_ADVISED===
# block when called with --advise-inference or --force-inference and a
# fresh pass is worth doing (see software_english_lint.py's
# inference_eligible()). It never judges the prose itself; the block
# holds the applicable rules for whoever calls it to judge directly.
#
# Two separate extractions from $1, each a plain command substitution
# (not a side-effect global: a bash function called inside $(...) runs
# in a subshell, so an assignment inside it never arrives back at the
# caller). A caller does CLEAN="$(strip_advise_block "$OUTPUT")" for
# the deterministic-tier report with the block removed, and separately
# ADVISE_RULES="$(extract_advise_rules "$OUTPUT")" for the rules text
# alone (marker lines stripped): empty when no block was present.
strip_advise_block() {
  sed '/^===INFERENCE_ADVISED===$/,/^===END_INFERENCE_ADVISED===$/d' <<<"$1"
}

extract_advise_rules() {
  sed -n '/^===INFERENCE_ADVISED===$/,/^===END_INFERENCE_ADVISED===$/p' <<<"$1" | sed '1d;$d'
}

# A non-blocking advisory: the tool call proceeds (or, for posttooluse,
# already did) exactly as if this hook produced no output. It only
# tells Claude to dispatch a subagent to read the source and judge it
# against the rules in $1 (built by the caller from ADVISE_RULES above,
# which also knows the right file path or the text itself): never to
# re-run this script for the judging step, since it cannot do that.
# Only pretooluse and posttooluse call this; stop-check.sh never runs
# the inference tier at all (see its own header comment on turn-latency
# cost).
#
# permissionDecision: "allow" plus a top-level systemMessage is the
# confirmed advisory shape for Claude Code, both hook types. The Copilot
# CLI branch mirrors report_and_maybe_block's own blocking shape
# (permissionDecisionReason for pretooluse, additionalContext for
# posttooluse) with an "allow" decision instead of "deny": unverified
# against a real Copilot session, same caveat as is_claude_code() above.
advise_inference() {
  local message="$1" hook_type="$2"
  [ -z "$message" ] && return 0
  if is_claude_code; then
    case "$hook_type" in
      pretooluse)
        jq -n --arg msg "$message" \
          '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow"}, systemMessage: $msg}'
        ;;
      posttooluse)
        jq -n --arg msg "$message" \
          '{hookSpecificOutput: {hookEventName: "PostToolUse"}, systemMessage: $msg}'
        ;;
    esac
  else
    case "$hook_type" in
      pretooluse)
        jq -n --arg msg "$message" '{permissionDecision: "allow", permissionDecisionReason: $msg}'
        ;;
      posttooluse)
        jq -n --arg msg "$message" '{additionalContext: $msg}'
        ;;
    esac
  fi
}
