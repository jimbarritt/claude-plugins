#!/usr/bin/env bash
# PreToolUse on Bash: checks a git commit message or any `gh pr`/`gh issue`
# body before the command runs (create, comment, edit, review: any
# subcommand can set a PR description).
# Every other Bash call passes through untouched.
#
# Flags and file arguments are read only from the git/gh invocation
# itself (the part of the command from `git commit`/`gh pr`/`gh issue`
# onward), never from whatever runs earlier in the same command, so an
# unrelated flag before it (e.g. `grep -F ...`) is never mistaken for the
# commit/PR flag. A `-F`/`--body-file` target whose name also appears
# earlier in the same command (edited with `sed -i`, written by a
# redirect or heredoc, or by a script's own `open(path, "w")`) is read
# from disk before that earlier part has run, so its on-disk content
# cannot be trusted as the final message: the hook skips reading it
# rather than lint stale, pre-fix text and block the command that fixes
# the fault (claude-plugins#30). An inline --title/--body/-m value is
# always linted too, alongside any file content, so a title is never
# dropped just because a body file is also present.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LINTER="$HERE/../scripts/software_english_lint.py"
source "$HERE/_lib.sh"

INPUT="$(cat)"
COMMAND="$(echo "$INPUT" | jq -r '.tool_input.command // empty')"
CWD="$(echo "$INPUT" | jq -r '.cwd // empty')"

[ -n "$COMMAND" ] || exit 0
hook_enabled '.hooks.bash' "$CWD" || exit 0

# Split at the first git/gh call: PRE is the shell plumbing before it,
# INVOCATION is that call onward. Everything below reads only INVOCATION
# for flags, and PRE only to check whether a file was named earlier.
SPLIT="$(printf '%s' "$COMMAND" | perl -0777 -ne '
  if (/(?:^|[;&|]) *(?=git commit|gh pr|gh issue)/m) {
    print substr($_, 0, $-[0]), "\n\x01\n", substr($_, $+[0]);
  }
')"
[ -n "$SPLIT" ] || exit 0
PRE="${SPLIT%%$'\n\x01\n'*}"
INVOCATION="${SPLIT#*$'\n\x01\n'}"

TEXT=""
if [[ "$INVOCATION" == *"-F "* ]] || [[ "$INVOCATION" == *"--body-file "* ]] || [[ "$INVOCATION" == *"--file "* ]]; then
  FILE_ARG="$(echo "$INVOCATION" | grep -oE '(^| )(-F|--body-file|--file) +[^ ]+' | head -1 | awk '{print $NF}' | tr -d "'\"")"
  if [ -n "$FILE_ARG" ] && [ "$FILE_ARG" != "-" ] && [ -f "$FILE_ARG" ] \
     && ! grep -qF -- "$(basename -- "$FILE_ARG")" <<<"$PRE"; then
    TEXT="$(cat -- "$FILE_ARG")"
  fi
fi

# Pull the first -m/--message/--body/--title argument's quoted value,
# double- or single-quoted (\x27 avoids fighting bash's own quoting for
# a literal ' inside this single-quoted perl -e string), in addition to
# any file text found above.
# A heredoc-based commit ($(cat <<'EOF' ... EOF)) is not parsed here, nor
# is a -m "$(...)" value whose own substitution contains a double quote
# (the capture stops at that inner quote). The surrounding quotes defeat
# a simple regex; skip rather than misparse, since a false negative here
# is safer than a false block.
INLINE_TEXT="$(echo "$INVOCATION" | perl -ne 'while (/(?:-m|--message|--body|--title)\s+(?:"((?:[^"\\]|\\.)*)"|\x27([^\x27]*)\x27)/g) { print defined($1) ? "$1\n" : "$2\n"; }')"

if [ -n "$INLINE_TEXT" ]; then
  if [ -n "$TEXT" ]; then
    TEXT="$INLINE_TEXT
$TEXT"
  else
    TEXT="$INLINE_TEXT"
  fi
fi

[ -n "$TEXT" ] || exit 0

if ! "$HERE/../scripts/fetch-software-english-data.sh" >&2; then
  exit 0
fi

OUTPUT="$(printf '%s' "$TEXT" | "$LINTER" --text --source-label commit-or-pr-text --advise-inference --quiet-vocab 2>&1)"
STATUS=$?
CLEAN_OUTPUT="$(strip_advise_block "$OUTPUT")"
ADVISE_RULES="$(extract_advise_rules "$OUTPUT")"

report_and_maybe_block "$CLEAN_OUTPUT" "$STATUS" "bash" \
  "Fix the text, then run the command again." "pretooluse"

if [ "$STATUS" -eq 0 ] && [ -n "$ADVISE_RULES" ]; then
  advise_inference "Software English: the deterministic check passed for this commit/PR text, and it is due an inference-tier pass. Dispatch a subagent (Agent tool) to judge the text below directly against these rules, no script call needed for this part:

$ADVISE_RULES

Each line above names one rule to check (line 0 means the whole text, and \"inference pending\" means not yet judged); a \"candidate at line N\" line under a rule points at a place to check first for it, not a finding; the last line is a summary, not a rule.

Text:
---
$TEXT
---

Report any violation the same way the deterministic tier does: commit-or-pr-text:1: [severity] [rule-id] detail. The command you just ran already used this text, so if it finds anything, fix it in a follow-up (an amended commit, or a PR edit)." \
    "pretooluse"
fi
exit 0
