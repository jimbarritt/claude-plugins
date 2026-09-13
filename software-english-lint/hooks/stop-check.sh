#!/usr/bin/env bash
# Stop hook: runs the deterministic tier over the chat reply, the transcript
# since the last user message, and changed markdown (tracked and untracked).
# When that is clean and the prose passes a size threshold, also runs the
# inference tier. See ~/.planning/claude-plugins/task9-enforcement-strategy.md
#
# Fails open: any problem fetching rule data, or a missing/unreadable input
# field, lets the turn end rather than blocking on a mechanism problem.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LINTER="$HERE/../scripts/software_english_lint.py"

INPUT="$(cat)"
CWD="$(echo "$INPUT" | jq -r '.cwd // empty')"
TRANSCRIPT="$(echo "$INPUT" | jq -r '.transcript_path // empty')"
STOP_HOOK_ACTIVE="$(echo "$INPUT" | jq -r 'if .stop_hook_active == true then "true" else "false" end')"
REPLY="$(echo "$INPUT" | jq -r '.last_assistant_message // empty')"

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  exit 0
fi
cd "$CWD" || exit 0

if ! "$HERE/../scripts/fetch-software-english-data.sh" >&2; then
  exit 0
fi

REPLY_FILE="$(mktemp)"
trap 'rm -f "$REPLY_FILE"' EXIT
printf '%s' "$REPLY" > "$REPLY_FILE"

ARGS=(--diff --added-only --reply-file "$REPLY_FILE" --run-inference --stop-hook-active "$STOP_HOOK_ACTIVE" --quiet-vocab --cwd "$CWD")
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  ARGS+=(--transcript "$TRANSCRIPT")
fi

OUTPUT="$("$LINTER" "${ARGS[@]}" 2>&1)"
STATUS=$?

if [ -z "$OUTPUT" ] || [ "$OUTPUT" = "No sources to check." ]; then
  exit 0
fi

echo "$OUTPUT" >&2

if [ "$STATUS" -eq 0 ]; then
  exit 0
fi

echo "" >&2
echo "Software English violations found. Fix each one, then finish the turn again." >&2
exit 2
