#!/usr/bin/env bash
# Installs (or removes) swe's git pre-commit check in one repository.
# See swe/git-hooks/pre-commit.sh for what the installed hook does; this
# script only places it.
#
# Usage: install-commit-hook.sh [--uninstall] [<repo-path>]
#
# An existing pre-commit hook at the target, without this script's own
# marker, is kept: moved verbatim to pre-commit.local (still executable)
# and chained, run first, by the installed hook. Does not touch either
# file when both a foreign pre-commit and an existing pre-commit.local
# are already present, since overwriting either would destroy a file
# this script did not create.
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$HERE/git-hooks/pre-commit.sh"

UNINSTALL="false"
REPO="$PWD"
for arg in "$@"; do
  case "$arg" in
    --uninstall) UNINSTALL="true" ;;
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

is_marked() {
  [ -f "$1" ] && grep -q "^${MARKER}" "$1" 2>/dev/null
}

if [ "$UNINSTALL" = "true" ]; then
  if ! is_marked "$TARGET"; then
    echo "swe: no swe commit check installed at $TARGET; nothing to do."
    exit 0
  fi
  rm -f "$TARGET"
  if [ -f "$CHAINED" ]; then
    mv "$CHAINED" "$TARGET"
    echo "swe: removed the commit check and restored the pre-commit hook that was chained under it ($TARGET)."
  else
    echo "swe: removed the commit check ($TARGET)."
  fi
  echo "swe: the lint ledger under $GIT_COMMON/swe/ was left in place."
  exit 0
fi

if [ -f "$TARGET" ] && is_marked "$TARGET"; then
  CUR_VERSION="$(sed -n "s/^${MARKER}//p" "$TARGET" | head -1)"
  if [ "$CUR_VERSION" = "$SRC_VERSION" ]; then
    echo "swe: commit check already installed at $TARGET (version $SRC_VERSION)."
    exit 0
  fi
  cp "$SOURCE" "$TARGET"
  chmod 755 "$TARGET"
  echo "swe: updated the commit check at $TARGET (version $CUR_VERSION -> $SRC_VERSION)."
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
printf '%s' "${CLAUDE_PLUGIN_ROOT:-$HERE}" > "$GIT_COMMON/swe/plugin-root"

echo "swe: lint ledger: $GIT_COMMON/swe/lint-log.ndjson"
echo "swe: a commit staging a markdown file now needs a clean /swe:lint-file pass on its exact staged content."
echo "swe: bypass for one commit: git commit --no-verify. Remove the check: install-commit-hook.sh --uninstall"
