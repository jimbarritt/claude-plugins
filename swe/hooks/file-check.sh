#!/usr/bin/env bash
# PostToolUse on Write|Edit. Two independent cases; PostToolUse cannot
# block the write (it already happened), but exit 2 still shows
# stderr to Claude as a system message, so an error-severity finding
# gets exit 2 to arrive at Claude, not exit 0 (which only arrives at the
# transcript, not the model):
#   - A markdown file the Stop hook's git diff cannot see: outside the
#     working tree, or untracked.
#   - A code file's comments (taxonomy row 5): nothing else checks
#     these, tracked or not, since stop-check.sh's own diff is
#     markdown-only.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LINTER="$HERE/../scripts/software_english_lint.py"
source "$HERE/_lib.sh"

INPUT="$(cat)"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')"
CWD="$(echo "$INPUT" | jq -r '.cwd // empty')"

[ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ] || exit 0
hook_enabled '.hooks.file' "$CWD" || exit 0

case "$FILE_PATH" in
  *.md)
    # Only files the Stop hook's own git diff cannot see: outside the
    # working tree entirely, inside one but untracked, or, when a
    # project turns hooks.stop.docs off, nowhere else checks
    # tracked markdown at all, so this hook takes it over instead. A
    # tracked in-tree file with hooks.stop.docs on is already covered by
    # stop-check.sh, so skip it here to avoid a duplicate report.
    if [ -n "$CWD" ] && [ -d "$CWD" ] && hook_enabled '.hooks.stop.docs' "$CWD"; then
      case "$FILE_PATH" in
        "$CWD"/*)
          if (cd "$CWD" && git ls-files --error-unmatch -- "$FILE_PATH" >/dev/null 2>&1); then
            exit 0
          fi
          ;;
      esac
    fi
    ;;
  *.py|*.sh|*.bash) ;;
  *) exit 0 ;;
esac

if ! "$HERE/../scripts/fetch-software-english-data.sh" >&2; then
  exit 0
fi

CWD_ARGS=()
[ -n "$CWD" ] && [ -d "$CWD" ] && CWD_ARGS=(--cwd "$CWD")
OUTPUT="$("$LINTER" "$FILE_PATH" --advise-inference --quiet-vocab "${CWD_ARGS[@]}" 2>&1)"
STATUS=$?
CLEAN_OUTPUT="$(strip_advise_block "$OUTPUT")"
ADVISE_RULES="$(extract_advise_rules "$OUTPUT")"

report_and_maybe_block "$CLEAN_OUTPUT" "$STATUS" "file" \
  "Violations found in $FILE_PATH. Fix them." "posttooluse"

if [ "$STATUS" -eq 0 ] && [ -n "$ADVISE_RULES" ]; then
  advise_inference "Software English: the deterministic check passed for $FILE_PATH, and it is due another inference-tier pass. Dispatch a subagent (Agent tool) to read $FILE_PATH and judge it directly against these rules, no script call needed for this part:

$ADVISE_RULES

Report any violation the same way the deterministic tier does: <file>:<line>: [severity] [rule-id] detail. Fix anything it finds." \
    "posttooluse"
fi
exit 0
