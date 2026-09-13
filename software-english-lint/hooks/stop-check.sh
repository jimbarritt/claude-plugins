#!/usr/bin/env bash
# Stop hook: runs the deterministic tier over the chat reply, the transcript
# since the last user message, and changed markdown (tracked and untracked).
# No inference tier here: a model call on every turn cost 15-50 seconds
# even on success, and an occasional stall past that. File, artefact,
# commit/PR, and outbound-message checks still run it (once per edit or
# send, not once per turn).
#
# Hard 2-second cap on the whole check, no exceptions: this hook runs on
# every conversational turn, so any stall here (network, a slow git diff,
# anything) is unacceptable. A file/artefact/commit/message check can
# afford to wait; a reply cannot. On a cap failure, fails open silently.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LINTER="$HERE/../scripts/software_english_lint.py"
source "$HERE/_lib.sh"

INPUT="$(cat)"
CWD="$(echo "$INPUT" | jq -r '.cwd // empty')"
TRANSCRIPT="$(echo "$INPUT" | jq -r '.transcript_path // empty')"
STOP_HOOK_ACTIVE="$(echo "$INPUT" | jq -r 'if .stop_hook_active == true then "true" else "false" end')"
REPLY="$(echo "$INPUT" | jq -r '.last_assistant_message // empty')"

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  exit 0
fi

REPLY_FILE="$(mktemp)"
OUT_FILE="$(mktemp)"
STATUS_FILE="$(mktemp)"
trap 'rm -f "$REPLY_FILE" "$OUT_FILE" "$STATUS_FILE"' EXIT
printf '%s' "$REPLY" > "$REPLY_FILE"

(
  cd "$CWD" || exit 0
  "$HERE/../scripts/fetch-software-english-data.sh" >/dev/null 2>&1
  ARGS=(--diff --added-only --reply-file "$REPLY_FILE" --stop-hook-active "$STOP_HOOK_ACTIVE" --quiet-vocab --cwd "$CWD")
  if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    ARGS+=(--transcript "$TRANSCRIPT")
  fi
  "$LINTER" "${ARGS[@]}" > "$OUT_FILE" 2>&1
  echo $? > "$STATUS_FILE"
) &
WORKER=$!

(
  sleep 2
  pkill -9 -P "$WORKER" 2>/dev/null
  kill -9 "$WORKER" 2>/dev/null
) &
WATCHER=$!

wait "$WORKER" 2>/dev/null
kill "$WATCHER" 2>/dev/null
wait "$WATCHER" 2>/dev/null

if [ ! -s "$STATUS_FILE" ]; then
  exit 0
fi

STATUS="$(cat "$STATUS_FILE")"
OUTPUT="$(cat "$OUT_FILE")"

report_and_maybe_block "$OUTPUT" "$STATUS" "stop" \
  "Software English violations found. Fix each one, then finish the turn again."
exit $?
