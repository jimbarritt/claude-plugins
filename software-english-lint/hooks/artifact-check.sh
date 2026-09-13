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

[ "$ACTION" = "publish" ] || exit 0
[ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ] || exit 0

if ! "$HERE/../scripts/fetch-software-english-data.sh" >&2; then
  exit 0
fi

case "$FILE_PATH" in
  *.md) ARGS=("$FILE_PATH") ;;
  *.html|*.htm) ARGS=(--html-file "$FILE_PATH") ;;
  *) exit 0 ;;
esac

OUTPUT="$("$LINTER" "${ARGS[@]}" --run-inference --quiet-vocab 2>&1)"
STATUS=$?

report_and_maybe_block "$OUTPUT" "$STATUS" "artifact" \
  "Software English violations found in the artefact about to publish."
exit $?
