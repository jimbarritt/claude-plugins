#!/usr/bin/env bash
# Wraps software_english_lint.py for the Stop hook: exit 1 (lint failure) must become
# exit 2 (block the Stop event) for Claude Code to treat it as a block.
set -uo pipefail
HERE="$(dirname "$0")"

if ! "$HERE/../scripts/fetch-software-english-data.sh" 2>&1; then
  exit 0
fi

OUTPUT="$("$HERE/../scripts/software_english_lint.py" --diff --added-only 2>&1)"
STATUS=$?

if [ "$STATUS" -eq 0 ]; then
  exit 0
fi

echo "$OUTPUT" >&2
echo "" >&2
echo "Software English deterministic-tier violations found in changed Markdown. Fix each one, then finish the turn again." >&2
exit 2
