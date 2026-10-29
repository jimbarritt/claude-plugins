#!/usr/bin/env bash
# Installs (or removes) swe's git pre-commit check in one repository, and
# optionally a committed, opt-in SessionStart entry that re-installs it at
# every session start (claude-plugins#31: .git/ is never cloned, so a
# fresh clone or Claude Code cloud session starts with no hook until
# something installs one).
#
# See swe/git-hooks/pre-commit.sh for what the installed git hook does,
# and swe/session-start/swe-commit-hook.sh for what the session-start
# shim does; this script only places them.
#
# Usage: install-commit-hook.sh [--uninstall] [--session-start] [<repo-path>]
#
# An existing pre-commit hook at the target, without this script's own
# marker, is kept: moved verbatim to pre-commit.local (still executable)
# and chained, run first, by the installed hook. Does not touch either
# file when both a foreign pre-commit and an existing pre-commit.local
# are already present, since overwriting either would destroy a file
# this script did not create.
#
# --session-start additionally installs .claude/hooks/swe-commit-hook.sh
# (copied from this plugin, with its own version marker) and appends one
# SessionStart group naming it to .claude/settings.json, creating the
# file if absent and leaving every other key and group untouched. It
# never merges into another group: the entry is identified by its exact
# command string, so a repeat run is a no-op. Needs jq; refuses rather
# than touch settings.json when jq is absent, the file holds invalid
# JSON, or a foreign (unmarked) file already sits at the shim's path.
# Combined with --uninstall, it removes only that one SessionStart
# command and the shim (if swe-marked), leaving every other group alone.
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$HERE/git-hooks/pre-commit.sh"
SHIM_SOURCE="$HERE/session-start/swe-commit-hook.sh"
SS_MARKER="# swe-session-start-version: "
SS_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/swe-commit-hook.sh'

UNINSTALL="false"
SESSION_START="false"
REPO="$PWD"
for arg in "$@"; do
  case "$arg" in
    --uninstall) UNINSTALL="true" ;;
    --session-start) SESSION_START="true" ;;
    *) REPO="$arg" ;;
  esac
done

if [ ! -f "$SOURCE" ]; then
  echo "swe: $SOURCE not found; the plugin installation looks incomplete." >&2
  exit 1
fi

TOPLEVEL="$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$TOPLEVEL" ]; then
  echo "swe: $REPO is not inside a git repository." >&2
  exit 1
fi

GIT_COMMON="$(git -C "$TOPLEVEL" rev-parse --git-common-dir 2>/dev/null || true)"
[ -n "$GIT_COMMON" ] || GIT_COMMON=".git"
case "$GIT_COMMON" in
  /*) ;;
  *) GIT_COMMON="$TOPLEVEL/$GIT_COMMON" ;;
esac

HOOKS_DIR="$(git -C "$TOPLEVEL" rev-parse --git-path hooks 2>/dev/null || true)"
[ -n "$HOOKS_DIR" ] || HOOKS_DIR="$GIT_COMMON/hooks"
case "$HOOKS_DIR" in
  /*) ;;
  *) HOOKS_DIR="$TOPLEVEL/$HOOKS_DIR" ;;
esac
mkdir -p "$HOOKS_DIR"

TARGET="$HOOKS_DIR/pre-commit"
CHAINED="$TARGET.local"
MARKER="# swe-commit-check-version: "
SRC_VERSION="$(sed -n "s/^${MARKER}//p" "$SOURCE" | head -1)"

SETTINGS="$TOPLEVEL/.claude/settings.json"
SHIM_TARGET="$TOPLEVEL/.claude/hooks/swe-commit-hook.sh"

is_marked() {  # is_marked <path> <marker-prefix>
  [ -f "$1" ] && grep -q "^${2}" "$1" 2>/dev/null
}

session_start_install() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "swe: jq is needed to edit .claude/settings.json; the session-start entry was not written." >&2
    return 1
  fi
  if [ ! -f "$SHIM_SOURCE" ]; then
    echo "swe: $SHIM_SOURCE not found; the plugin installation looks incomplete." >&2
    return 1
  fi
  if [ -e "$SHIM_TARGET" ] && ! is_marked "$SHIM_TARGET" "$SS_MARKER"; then
    echo "swe: $SHIM_TARGET is a file this script did not write. Not overwriting it; the session-start entry was not installed." >&2
    return 1
  fi

  mkdir -p "$(dirname "$SHIM_TARGET")"
  local shim_src_version shim_cur_version shim_changed="false"
  shim_src_version="$(sed -n "s/^${SS_MARKER}//p" "$SHIM_SOURCE" | head -1)"
  if [ -f "$SHIM_TARGET" ]; then
    shim_cur_version="$(sed -n "s/^${SS_MARKER}//p" "$SHIM_TARGET" | head -1)"
    if [ "$shim_cur_version" != "$shim_src_version" ]; then
      cp "$SHIM_SOURCE" "$SHIM_TARGET"
      shim_changed="true"
    fi
  else
    cp "$SHIM_SOURCE" "$SHIM_TARGET"
    shim_changed="true"
  fi
  chmod 755 "$SHIM_TARGET"
  bash -n "$SHIM_TARGET" || { echo "swe: the installed session-start shim failed a syntax check; installation aborted." >&2; return 1; }

  if [ -f "$SETTINGS" ] && ! jq empty "$SETTINGS" >/dev/null 2>&1; then
    echo "swe: $SETTINGS is not valid JSON; the session-start entry was not written." >&2
    return 1
  fi
  mkdir -p "$(dirname "$SETTINGS")"
  [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

  if jq -e --arg c "$SS_CMD" '(.hooks.SessionStart // []) | any(.[].hooks[]?; .command == $c)' "$SETTINGS" >/dev/null 2>&1; then
    echo "swe: session-start entry already present in $SETTINGS."
  else
    local tmp
    tmp="$(mktemp "$(dirname "$SETTINGS")/.settings.json.XXXXXX")"
    jq --arg c "$SS_CMD" '
      .hooks //= {} |
      .hooks.SessionStart //= [] |
      .hooks.SessionStart += [{"hooks": [{"type": "command", "command": $c}]}]
    ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    echo "swe: added a session-start entry to $SETTINGS."
  fi

  if [ "$shim_changed" = "true" ]; then
    echo "swe: installed the session-start shim at $SHIM_TARGET (version $shim_src_version)."
  fi
  echo "swe: commit .claude/settings.json and .claude/hooks/swe-commit-hook.sh so every clone installs the commit check at session start."
  return 0
}

session_start_uninstall() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "swe: jq is needed to edit .claude/settings.json; the session-start entry was not removed." >&2
    return 1
  fi
  if [ -f "$SETTINGS" ] && jq empty "$SETTINGS" >/dev/null 2>&1; then
    if jq -e --arg c "$SS_CMD" '(.hooks.SessionStart // []) | any(.[].hooks[]?; .command == $c)' "$SETTINGS" >/dev/null 2>&1; then
      local tmp
      tmp="$(mktemp "$(dirname "$SETTINGS")/.settings.json.XXXXXX")"
      jq --arg c "$SS_CMD" '
        .hooks.SessionStart = (
          .hooks.SessionStart
          | map(.hooks |= map(select(.command != $c)))
          | map(select((.hooks | length) > 0))
        )
        | if (.hooks.SessionStart | length) == 0 then .hooks |= del(.SessionStart) else . end
        | if (.hooks | length) == 0 then del(.hooks) else . end
      ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
      echo "swe: removed the session-start entry from $SETTINGS."
    else
      echo "swe: no swe session-start entry found in $SETTINGS; nothing to do there."
    fi
  fi

  if [ -f "$SHIM_TARGET" ] && is_marked "$SHIM_TARGET" "$SS_MARKER"; then
    rm -f "$SHIM_TARGET"
    echo "swe: removed the session-start shim ($SHIM_TARGET)."
  fi
  return 0
}

if [ "$UNINSTALL" = "true" ]; then
  if is_marked "$TARGET" "$MARKER"; then
    rm -f "$TARGET"
    if [ -f "$CHAINED" ]; then
      mv "$CHAINED" "$TARGET"
      echo "swe: removed the commit check and restored the pre-commit hook that was chained under it ($TARGET)."
    else
      echo "swe: removed the commit check ($TARGET)."
    fi
    echo "swe: the lint ledger under $GIT_COMMON/swe/ was left in place."
  else
    echo "swe: no swe commit check installed at $TARGET; nothing to do."
  fi

  SS_STATUS=0
  if [ "$SESSION_START" = "true" ]; then
    session_start_uninstall
    SS_STATUS=$?
  elif [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1 && jq -e --arg c "$SS_CMD" '(.hooks.SessionStart // []) | any(.[].hooks[]?; .command == $c)' "$SETTINGS" >/dev/null 2>&1; then
    echo "swe: a committed session-start entry is still in $SETTINGS; it will reinstall the git hook at the next session start. Pass --session-start to remove it too."
  fi

  exit "$SS_STATUS"
fi

GIT_HOOK_STATUS="installed"

if [ -f "$TARGET" ] && is_marked "$TARGET" "$MARKER"; then
  CUR_VERSION="$(sed -n "s/^${MARKER}//p" "$TARGET" | head -1)"
  if [ "$CUR_VERSION" = "$SRC_VERSION" ]; then
    GIT_HOOK_STATUS="current"
    echo "swe: commit check already installed at $TARGET (version $SRC_VERSION)."
  else
    cp "$SOURCE" "$TARGET"
    chmod 755 "$TARGET"
    GIT_HOOK_STATUS="updated"
    echo "swe: updated the commit check at $TARGET (version $CUR_VERSION -> $SRC_VERSION)."
  fi
elif [ -f "$TARGET" ]; then
  if [ -f "$CHAINED" ]; then
    echo "swe: $TARGET is a pre-existing hook this script did not install, and $CHAINED already exists too. Not overwriting either. Move one aside by hand, then re-run this command." >&2
    exit 1
  fi
  mv "$TARGET" "$CHAINED"
  chmod +x "$CHAINED"
  cp "$SOURCE" "$TARGET"
  chmod 755 "$TARGET"
  echo "swe: an existing pre-commit hook was kept as $CHAINED and is chained: it runs first, unchanged."
  echo "swe: installed the commit check at $TARGET (version $SRC_VERSION)."
else
  cp "$SOURCE" "$TARGET"
  chmod 755 "$TARGET"
  echo "swe: installed the commit check at $TARGET (version $SRC_VERSION)."
fi

bash -n "$TARGET" || { echo "swe: the installed hook failed a syntax check; installation aborted." >&2; exit 1; }
[ -x "$TARGET" ] || { echo "swe: the installed hook is not executable." >&2; exit 1; }

mkdir -p "$GIT_COMMON/swe"
NEW_POINTER="${CLAUDE_PLUGIN_ROOT:-$HERE}"
OLD_POINTER="$(cat "$GIT_COMMON/swe/plugin-root" 2>/dev/null || true)"
if [ "$OLD_POINTER" != "$NEW_POINTER" ]; then
  printf '%s' "$NEW_POINTER" > "$GIT_COMMON/swe/plugin-root"
fi

if [ "$GIT_HOOK_STATUS" != "current" ]; then
  echo "swe: lint ledger: $GIT_COMMON/swe/lint-log.ndjson"
  echo "swe: a commit staging a markdown file now needs a clean /swe:lint-file pass on its exact staged content."
  echo "swe: bypass for one commit: git commit --no-verify. Remove the check: install-commit-hook.sh --uninstall"
fi

if [ "$SESSION_START" = "true" ]; then
  session_start_install
fi
