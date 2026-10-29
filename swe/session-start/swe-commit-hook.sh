#!/usr/bin/env bash
# swe-session-start-version: 1
#
# SessionStart shim installed by install-commit-hook.sh --session-start as
# <repo>/.claude/hooks/swe-commit-hook.sh, and run by a SessionStart entry
# this repository commits in .claude/settings.json (claude-plugins#31).
# .git/ is never cloned, so a fresh clone or Claude Code cloud session has
# no git pre-commit hook until something installs one; this shim re-runs
# swe's own installer, scripts/install-commit-hook.sh, at every session
# start so the hook is always present without anyone running
# /swe:install-commit-hook by hand.
#
# Fail-open: every path below exits 0. A SessionStart hook runs before an
# agent does any work, so this script never blocks a session over a
# missing plugin, a missing jq, or an installer refusal; it only tells the
# transcript what happened, or that nothing could be done.
#
# Finding the installed swe plugin, in order:
#   1. $SWE_PLUGIN_ROOT, when it holds scripts/install-commit-hook.sh (the
#      same override swe's own git-hooks/pre-commit.sh honours; tests use
#      it to point at a fixture copy).
#   2. ~/.claude/plugins/installed_plugins.json (or $CLAUDE_CONFIG_DIR),
#      read with jq: the newest swe@* entry whose projectPath matches this
#      repository, else the newest user-scope swe@* entry.
#   3. The newest swe/<version>/ directory under
#      ~/.claude/plugins/cache/*/swe/ that holds the installer. A real
#      swe install can be missing from installed_plugins.json (the plugin
#      cache holds it but the install record does not), so this fallback
#      is not hypothetical.
set -uo pipefail

REPO="${CLAUDE_PROJECT_DIR:-$PWD}"
TOPLEVEL="$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$TOPLEVEL" ] || exit 0

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

find_plugin_root() {
  if [ -n "${SWE_PLUGIN_ROOT:-}" ] && [ -f "$SWE_PLUGIN_ROOT/scripts/install-commit-hook.sh" ]; then
    printf '%s' "$SWE_PLUGIN_ROOT"
    return 0
  fi

  local installed="$CONFIG_DIR/plugins/installed_plugins.json"
  if [ -f "$installed" ] && command -v jq >/dev/null 2>&1; then
    local by_project by_user
    by_project="$(jq -r --arg p "$TOPLEVEL" '
      .plugins | to_entries[] | select(.key | startswith("swe@")) | .value[]
      | select(.projectPath == $p) | .installPath
    ' "$installed" 2>/dev/null | tail -1)"
    if [ -n "$by_project" ] && [ -f "$by_project/scripts/install-commit-hook.sh" ]; then
      printf '%s' "$by_project"
      return 0
    fi
    by_user="$(jq -r '
      .plugins | to_entries[] | select(.key | startswith("swe@")) | .value[]
      | select(.scope == "user") | .installPath
    ' "$installed" 2>/dev/null | tail -1)"
    if [ -n "$by_user" ] && [ -f "$by_user/scripts/install-commit-hook.sh" ]; then
      printf '%s' "$by_user"
      return 0
    fi
  fi

  local newest
  newest="$(ls -d "$CONFIG_DIR"/plugins/cache/*/swe/*/ 2>/dev/null | sort -V | tail -1)"
  if [ -n "$newest" ] && [ -f "${newest}scripts/install-commit-hook.sh" ]; then
    printf '%s' "${newest%/}"
    return 0
  fi

  return 1
}

ROOT="$(find_plugin_root)" || {
  echo "swe: the swe plugin is not installed in this session, so the commit check was not installed. Run /swe:install-commit-hook once swe is installed." >&2
  exit 0
}

OUT="$("$ROOT/scripts/install-commit-hook.sh" "$TOPLEVEL" 2>&1)"
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  printf '%s\n' "$OUT" >&2
  exit 0
fi

case "$OUT" in
  *"already installed"*) ;;
  *) printf '%s\n' "$OUT" | grep -E '^swe: (installed|updated)' || true ;;
esac

exit 0
