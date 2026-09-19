#!/usr/bin/env bash
# Populates ../data/ from the pinned tag in ../software-english.json. Runs on
# every invocation but does no network work once the pinned tag is already
# cached (see MARKER below). Fails open: if a fetch cannot run (no network)
# but a cache from any earlier fetch exists, that cache is used as-is.
#
# Fetches via `git clone --depth 1 --branch <tag>`, not a raw HTTPS tarball
# download. A cloud session's egress policy can deny a generic HTTPS
# download (curl against a raw github.com URL) while still serving git's
# own smart-HTTP protocol for a public repo clone, through a separate,
# git-specific proxy lane. See claude-plugins#3.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$HERE/software-english.json"
DATA_DIR="$HERE/data"
MARKER="$DATA_DIR/.fetched-tag"

REPO="$(python3 -c "import json; print(json.load(open('$CONFIG'))['repo'])")"
TAG="$(python3 -c "import json; print(json.load(open('$CONFIG'))['tag'])")"

if [ -f "$MARKER" ] && [ "$(cat "$MARKER")" = "$TAG" ]; then
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

URL="https://github.com/$REPO.git"

if ! git clone --depth 1 --branch "$TAG" "$URL" "$TMP/src" >"$TMP/git.log" 2>&1; then
  echo "swe: could not clone $URL at $TAG" >&2
  cat "$TMP/git.log" >&2
  if [ -d "$DATA_DIR" ] && [ -n "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
    echo "swe: using existing cached data instead" >&2
    exit 0
  fi
  echo "swe: no cached data available; skipping this check" >&2
  exit 1
fi

mkdir -p "$DATA_DIR"
cp "$TMP/src"/vocabulary/*.tsv "$DATA_DIR/"
cp "$TMP/src"/rules/core-rules.toml "$DATA_DIR/"
echo "$TAG" > "$MARKER"
