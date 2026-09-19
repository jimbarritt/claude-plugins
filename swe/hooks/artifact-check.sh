#!/usr/bin/env bash
# PreToolUse on Artifact: checks the file about to be published, on a
# publish action only (not read, list, comments, and similar). Markdown
# files are linted directly; HTML files have their text nodes extracted
# first (a short node, e.g. a button label, is skipped: see config.json).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LINTER="$HERE/../scripts/software_english_lint.py"
source "$HERE/_lib.sh"

INPUT="$(cat)"
ACTION="$(echo "$INPUT" | jq -r '.tool_input.action // "publish"')"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')"
CWD="$(echo "$INPUT" | jq -r '.cwd // empty')"

[ "$ACTION" = "publish" ] || exit 0
[ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ] || exit 0
hook_enabled '.hooks.artifact' "$CWD" || exit 0

if ! "$HERE/../scripts/fetch-software-english-data.sh" >&2; then
  exit 0
fi

case "$FILE_PATH" in
  *.md) ARGS=("$FILE_PATH") ;;
  *.html|*.htm) ARGS=(--html-file "$FILE_PATH") ;;
  *) exit 0 ;;
esac

OUTPUT="$("$LINTER" "${ARGS[@]}" --advise-inference --quiet-vocab 2>&1)"
STATUS=$?
CLEAN_OUTPUT="$(strip_advise_block "$OUTPUT")"
ADVISE_RULES="$(extract_advise_rules "$OUTPUT")"

report_and_maybe_block "$CLEAN_OUTPUT" "$STATUS" "artifact" \
  "Violations found in the artefact about to publish." "pretooluse"

if [ "$STATUS" -eq 0 ] && [ -n "$ADVISE_RULES" ]; then
  advise_inference "Software English: the deterministic check passed for the artefact about to publish ($FILE_PATH), and it is due an inference-tier pass. Dispatch a subagent (Agent tool) to read $FILE_PATH and judge it directly against these rules, no script call needed for this part:

$ADVISE_RULES

Report any violation the same way the deterministic tier does: <file>:<line>: [severity] [rule-id] detail. If it finds anything, fix $FILE_PATH and republish." \
    "pretooluse"
fi
exit 0
