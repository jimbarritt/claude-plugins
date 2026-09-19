#!/usr/bin/env bash
# PreToolUse on Bash: checks a git commit message or any `gh pr`/`gh issue`
# body before the command runs (create, comment, edit, review: any
# subcommand can set a PR description).
# Every other Bash call passes through untouched.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LINTER="$HERE/../scripts/software_english_lint.py"
source "$HERE/_lib.sh"

INPUT="$(cat)"
COMMAND="$(echo "$INPUT" | jq -r '.tool_input.command // empty')"
CWD="$(echo "$INPUT" | jq -r '.cwd // empty')"

[ -n "$COMMAND" ] || exit 0
hook_enabled '.hooks.bash' "$CWD" || exit 0

if ! echo "$COMMAND" | grep -qE '(^|[;&|]) *(git commit|gh pr|gh issue)'; then
  exit 0
fi

TEXT=""
if [[ "$COMMAND" == *"-F "* ]] || [[ "$COMMAND" == *"--body-file "* ]] || [[ "$COMMAND" == *"--file "* ]]; then
  FILE_ARG="$(echo "$COMMAND" | grep -oE '(-F|--body-file|--file) +[^ ]+' | head -1 | awk '{print $2}' | tr -d "'\"")"
  if [ -n "$FILE_ARG" ] && [ -f "$FILE_ARG" ]; then
    TEXT="$(cat "$FILE_ARG")"
  fi
fi

if [ -z "$TEXT" ]; then
  # Pull the first -m/--message/--body/--title argument's quoted value,
  # double- or single-quoted (\x27 avoids fighting bash's own quoting for
  # a literal ' inside this single-quoted perl -e string).
  # A heredoc-based commit ($(cat <<'EOF' ... EOF)) is not parsed here.
  # The surrounding quotes defeat a simple regex; skip rather than
  # misparse, since a false negative here is safer than a false block.
  TEXT="$(echo "$COMMAND" | perl -ne 'while (/(?:-m|--message|--body|--title)\s+(?:"((?:[^"\\]|\\.)*)"|\x27([^\x27]*)\x27)/g) { print defined($1) ? "$1\n" : "$2\n"; }')"
fi

[ -n "$TEXT" ] || exit 0

if ! "$HERE/../scripts/fetch-software-english-data.sh" >&2; then
  exit 0
fi

OUTPUT="$(printf '%s' "$TEXT" | "$LINTER" --text --source-label commit-or-pr-text --advise-inference --quiet-vocab 2>&1)"
STATUS=$?
CLEAN_OUTPUT="$(strip_advise_marker "$OUTPUT")"
ADVISED=$?

report_and_maybe_block "$CLEAN_OUTPUT" "$STATUS" "bash" \
  "Fix the text, then run the command again." "pretooluse"

if [ "$STATUS" -eq 0 ] && [ "$ADVISED" -eq 0 ]; then
  SCRATCH_DIR="$HOME/.claude/swe/pending-inference"
  mkdir -p "$SCRATCH_DIR"
  SCRATCH_FILE="$SCRATCH_DIR/bash-$(date +%s)-$$.txt"
  printf '%s' "$TEXT" > "$SCRATCH_FILE"
  advise_inference "Software English: the deterministic check passed for this commit/PR text, and it is due an inference-tier pass. Dispatch a subagent (Agent tool) to run: python3 \"$HERE/../scripts/software_english_lint.py\" --text --source-label commit-or-pr-text --force-inference --quiet-vocab < \"$SCRATCH_FILE\". It only reports findings, it does not fix anything. Read what it reports; if it finds anything, the command you just ran already used the original text, so fix it in a follow-up (an amended commit, or a PR edit). Delete $SCRATCH_FILE once you are done with it." \
    "pretooluse"
fi
exit 0
