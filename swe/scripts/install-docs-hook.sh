#!/usr/bin/env bash
# Detects tsk, and installs (or removes) swe's tsk pre-docs-commit hook at
# one of the three places tsk's own `config docs-hook` understands. See
# swe/tsk-hooks/pre-docs-commit.sh for what the installed hook does; this
# script only detects tsk and places the hook.
#
# Usage:
#   install-docs-hook.sh --detect [<repo-path>]
#   install-docs-hook.sh --place {user|clone|repo} [--uninstall] [<repo-path>]
#
# --detect prints one line for tsk's own version state, then, only when
# tsk is new enough, one line per place (user, clone, repo) naming its
# path and state (absent, "swe <n>", foreign, or unavailable with a
# reason), then the raw lines of `tsk config docs-hook`, each prefixed
# "active". Always exits 0: it is informational only.
#
# --place installs or updates the hook at the named place, refusing to
# overwrite a pre-docs-commit file this script did not write (no
# chaining: the issue this script implements says stop, not chain).
# Exits 3 when tsk is absent or older than 0.26.1, 1 when the chosen
# place is unavailable or already holds a foreign file, 2 on a bad
# argument, 0 otherwise. --uninstall removes the file only when it is
# swe-written; a foreign file there is reported and left in place.
#
# A successful --place also (re)writes <git-common-dir>/swe/plugin-root
# for the repository install-docs-hook.sh was run from: the installed
# hook reads that pointer to find the plugin's linter at run time (see
# the hook's own header for why), and re-running this command after a
# swe update is what refreshes it, the same contract
# install-commit-hook.sh's own git hook already has.
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$HERE/tsk-hooks/pre-docs-commit.sh"
MARKER="# swe-docs-hook-version: "
MIN_TSK_VERSION="0.26.1"

MODE=""
PLACE=""
UNINSTALL="false"
REPO="$PWD"
while [ $# -gt 0 ]; do
  case "$1" in
    --detect) MODE="detect"; shift ;;
    --place) MODE="place"; PLACE="${2:-}"; shift 2 ;;
    --uninstall) UNINSTALL="true"; shift ;;
    *) REPO="$1"; shift ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "swe: usage: install-docs-hook.sh --detect [<repo-path>] | --place {user|clone|repo} [--uninstall] [<repo-path>]" >&2
  exit 2
fi

version_ge() {  # version_ge <have> <want> -- both "X.Y.Z"; true if have >= want
  local have="$1" want="$2"
  local -a h w
  IFS=. read -r -a h <<< "$have"
  IFS=. read -r -a w <<< "$want"
  local i hv wv
  for i in 0 1 2; do
    hv="${h[i]:-0}"; wv="${w[i]:-0}"
    [ "$hv" -gt "$wv" ] && return 0
    [ "$hv" -lt "$wv" ] && return 1
  done
  return 0
}

detect_tsk() {  # sets TSK_STATE (ok|absent|too-old|unknown-version) and TSK_VER
  TSK_STATE="absent"
  TSK_VER=""
  command -v tsk >/dev/null 2>&1 || return 0
  local raw
  raw="$(tsk --version 2>/dev/null | head -1)"
  if [[ "$raw" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
    TSK_VER="${BASH_REMATCH[1]}"
    if version_ge "$TSK_VER" "$MIN_TSK_VERSION"; then
      TSK_STATE="ok"
    else
      TSK_STATE="too-old"
    fi
  else
    TSK_STATE="unknown-version"
    TSK_VER="$raw"
  fi
}

user_path() {
  printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/tsk/hooks/pre-docs-commit"
}

repo_path() {  # repo_path <toplevel>
  printf '%s' "$1/.tsk/hooks/pre-docs-commit"
}

clone_path() {  # clone_path <toplevel> -- always prints "ok\t<path>" or
                 # "unavailable\t<reason>" on stdout (never a non-zero exit:
                 # a command-substitution call runs in a subshell, so a
                 # global variable set here would not reach the caller)
  local toplevel="$1" out status
  out="$(cd "$toplevel" && tsk ledger path 2>&1)"
  status=$?
  if [ "$status" -ne 0 ]; then
    printf 'unavailable\t%s' "$(printf '%s\n' "$out" | head -1)"
  else
    printf 'ok\t%s/hooks/pre-docs-commit' "$(dirname "$out")"
  fi
}

is_marked() { [ -f "$1" ] && grep -q "^${MARKER}" "$1" 2>/dev/null; }

state_of() {  # state_of <path> -- prints absent | "swe <n>" | foreign
  local path="$1"
  if [ ! -e "$path" ]; then
    echo "absent"
  elif is_marked "$path"; then
    echo "swe $(sed -n "s/^${MARKER}//p" "$path" | head -1)"
  else
    echo "foreign"
  fi
}

TOPLEVEL="$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null || true)"

cmd_detect() {
  detect_tsk
  case "$TSK_STATE" in
    absent) printf 'tsk\tabsent\n' ;;
    unknown-version) printf 'tsk\tunknown-version\t%s\n' "$TSK_VER" ;;
    too-old) printf 'tsk\ttoo-old\t%s\n' "$TSK_VER" ;;
    ok) printf 'tsk\tok\t%s\n' "$TSK_VER" ;;
  esac
  [ "$TSK_STATE" = "ok" ] || return 0

  local up rp cp_status cp_val
  up="$(user_path)"
  printf 'place\tuser\t%s\t%s\n' "$up" "$(state_of "$up")"

  if [ -n "$TOPLEVEL" ]; then
    IFS=$'\t' read -r cp_status cp_val <<< "$(clone_path "$TOPLEVEL")"
    if [ "$cp_status" = "ok" ]; then
      printf 'place\tclone\t%s\t%s\n' "$cp_val" "$(state_of "$cp_val")"
    else
      printf 'place\tclone\t-\tunavailable\t%s\n' "$cp_val"
    fi
    rp="$(repo_path "$TOPLEVEL")"
    printf 'place\trepo\t%s\t%s\n' "$rp" "$(state_of "$rp")"
  else
    printf 'place\tclone\t-\tunavailable\tnot inside a git repository\n'
    printf 'place\trepo\t-\tunavailable\tnot inside a git repository\n'
  fi

  (cd "${TOPLEVEL:-$REPO}" 2>/dev/null; tsk config docs-hook 2>&1) | while IFS= read -r line; do
    printf 'active\t%s\n' "$line"
  done
  return 0
}

cmd_place() {
  if [ ! -f "$SOURCE" ]; then
    echo "swe: $SOURCE not found; the plugin installation looks incomplete." >&2
    exit 1
  fi

  detect_tsk
  if [ "$TSK_STATE" != "ok" ]; then
    case "$TSK_STATE" in
      absent) echo "swe: the documents hook needs tsk 0.26.1 or later; tsk is not installed. Skipped." >&2 ;;
      too-old) echo "swe: the documents hook needs tsk 0.26.1 or later; found $TSK_VER. Skipped." >&2 ;;
      unknown-version) echo "swe: the documents hook needs tsk 0.26.1 or later; could not read tsk's version. Skipped." >&2 ;;
    esac
    exit 3
  fi

  local target
  case "$PLACE" in
    user)
      target="$(user_path)"
      ;;
    repo)
      if [ -z "$TOPLEVEL" ]; then
        echo "swe: $REPO is not inside a git repository; the repo place is unavailable." >&2
        exit 1
      fi
      target="$(repo_path "$TOPLEVEL")"
      ;;
    clone)
      if [ -z "$TOPLEVEL" ]; then
        echo "swe: $REPO is not inside a git repository; the clone place is unavailable." >&2
        exit 1
      fi
      local cp_status cp_val
      IFS=$'\t' read -r cp_status cp_val <<< "$(clone_path "$TOPLEVEL")"
      if [ "$cp_status" != "ok" ]; then
        echo "swe: the clone place is unavailable: $cp_val" >&2
        exit 1
      fi
      target="$cp_val"
      ;;
    *)
      echo "swe: unknown place '$PLACE'; expected user, clone or repo." >&2
      exit 2
      ;;
  esac

  if [ "$UNINSTALL" = "true" ]; then
    if [ ! -e "$target" ]; then
      echo "swe: no swe documents hook installed at $target; nothing to do."
      exit 0
    fi
    if ! is_marked "$target"; then
      echo "swe: $target is a pre-docs-commit script that swe did not write. Not removing it." >&2
      exit 1
    fi
    rm -f "$target"
    echo "swe: removed the documents hook at $target."
    exit 0
  fi

  if [ -e "$target" ] && ! is_marked "$target"; then
    echo "swe: $target is a pre-docs-commit script that swe did not write. Not overwriting it." >&2
    exit 1
  fi

  local src_version
  src_version="$(sed -n "s/^${MARKER}//p" "$SOURCE" | head -1)"

  if [ -f "$target" ]; then
    local cur_version
    cur_version="$(sed -n "s/^${MARKER}//p" "$target" | head -1)"
    if [ "$cur_version" = "$src_version" ]; then
      echo "swe: documents hook already installed at $target (version $src_version)."
    else
      cp "$SOURCE" "$target"
      chmod 755 "$target"
      echo "swe: updated the documents hook at $target (version $cur_version -> $src_version)."
    fi
  else
    mkdir -p "$(dirname "$target")"
    cp "$SOURCE" "$target"
    chmod 755 "$target"
    echo "swe: installed the documents hook at $target (version $src_version)."
  fi

  bash -n "$target" || { echo "swe: the installed documents hook failed a syntax check; installation aborted." >&2; exit 1; }
  [ -x "$target" ] || { echo "swe: the installed documents hook is not executable." >&2; exit 1; }

  if [ -n "$TOPLEVEL" ]; then
    local git_common
    git_common="$(git -C "$TOPLEVEL" rev-parse --git-common-dir 2>/dev/null || true)"
    case "$git_common" in
      /*) ;;
      *) git_common="$TOPLEVEL/$git_common" ;;
    esac
    if [ -n "$git_common" ]; then
      mkdir -p "$git_common/swe"
      printf '%s' "${CLAUDE_PLUGIN_ROOT:-$HERE}" > "$git_common/swe/plugin-root"
    fi
  else
    echo "swe: not inside a git repository, so this repository's plugin-root pointer was not written. Run this command again from inside a repository with tsk 0.26.1 before relying on the hook there." >&2
  fi

  if [ "$PLACE" = "repo" ]; then
    echo "swe: $target is not committed yet. Commit it so every contributor is checked."
  fi

  echo "swe: tsk config docs-hook reports:"
  (cd "${TOPLEVEL:-$REPO}" 2>/dev/null; tsk config docs-hook 2>&1) | sed 's/^/  /'
  exit 0
}

case "$MODE" in
  detect) cmd_detect ;;
  place) cmd_place ;;
esac
