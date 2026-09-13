#!/usr/bin/env bash
# PostToolUse on Write|Edit. Two independent cases; PostToolUse cannot
# block (the write already happened), so this only reports either way:
#   - A markdown file the Stop hook's git diff cannot see — outside the
#     working tree, or untracked.
#   - A code file's comments (taxonomy row 5) — nothing else checks these,
#     tracked or not, since stop-check.sh's own diff is markdown-only.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LINTER="$HERE/../scripts/software_english_lint.py"

INPUT="$(cat)"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')"
CWD="$(echo "$INPUT" | jq -r '.cwd // empty')"

[ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ] || exit 0

case "$FILE_PATH" in
  *.md)
    # Only files the Stop hook's own git diff cannot see: outside the
    # working tree entirely, or inside one but untracked. A tracked
    # in-tree file is already covered by stop-check.sh, so skip it here
    # to avoid a duplicate report on the same content.
    if [ -n "$CWD" ] && [ -d "$CWD" ]; then
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

OUTPUT="$("$LINTER" "$FILE_PATH" --run-inference --quiet-vocab 2>&1)"
STATUS=$?

if [ -z "$OUTPUT" ] || [ "$OUTPUT" = "No sources to check." ]; then
  exit 0
fi

echo "$OUTPUT" >&2
if [ "$STATUS" -ne 0 ]; then
  echo "" >&2
  echo "Software English violations found in $FILE_PATH." >&2
fi
exit 0
