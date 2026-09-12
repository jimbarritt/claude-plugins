#!/usr/bin/env bash
# Populates ../data/ from the pinned tag in ../software-english.json. Runs on
# every invocation but does no network work once the pinned tag is already
# cached (see MARKER below). Fails open: if a fetch cannot run (no network)
# but a cache from any earlier fetch exists, that cache is used as-is.
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

URL="https://github.com/$REPO/archive/refs/tags/$TAG.tar.gz"

if ! curl -fsSL "$URL" -o "$TMP/src.tar.gz" 2>"$TMP/curl.err"; then
  echo "software-english-lint: could not fetch $URL" >&2
  cat "$TMP/curl.err" >&2
  if [ -d "$DATA_DIR" ] && [ -n "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
    echo "software-english-lint: using existing cached data instead" >&2
    exit 0
  fi
  echo "software-english-lint: no cached data available; skipping this check" >&2
  exit 1
fi

tar -xzf "$TMP/src.tar.gz" -C "$TMP"
SRC_DIR="$(find "$TMP" -maxdepth 1 -type d -name 'software-english-*')"

mkdir -p "$DATA_DIR"
cp "$SRC_DIR"/vocabulary/*.tsv "$DATA_DIR/"
cp "$SRC_DIR"/rules/core-rules.toml "$DATA_DIR/"
echo "$TAG" > "$MARKER"
