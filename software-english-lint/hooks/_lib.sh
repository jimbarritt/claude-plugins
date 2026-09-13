#!/usr/bin/env bash
# Shared by every hook script here. Warnings are never shown to Claude
# or the user (advisory tier, non-blocking by design); an error-severity
# finding gets a one-line count plus a report file path, not the full
# per-line dump, since the detail is only useful when fixing something.
report_and_maybe_block() {
  local output="$1" status="$2" stem="$3" trailer="$4"

  [ -z "$output" ] && return 0
  [ "$output" = "No sources to check." ] && return 0
  [ "$status" -eq 0 ] && return 0

  local dir="$HOME/.claude/software-english-lint/reports"
  mkdir -p "$dir"
  local file="$dir/$stem.txt"
  printf '%s\n' "$output" > "$file"

  local errors warnings
  errors="$(grep -c '\[error\]' <<<"$output")"
  warnings="$(grep -c '\[warning\]' <<<"$output")"

  echo "$errors Software English error(s), $warnings warning(s). Details: $file" >&2
  echo "" >&2
  echo "$trailer" >&2
  return 2
}
