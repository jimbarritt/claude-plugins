#!/usr/bin/env bash
# Vendors vocabulary data and the rule catalogue from software-english into
# this plugin. Manual for now — no versioning/release process exists yet.
set -euo pipefail
SRC="${1:-$HOME/Code/github/jimbarritt/software-english}"
DEST="$(dirname "$0")/../data"
mkdir -p "$DEST"
cp "$SRC"/vocabulary/*.tsv "$DEST"/
cp "$SRC"/rules/core-rules.toml "$DEST"/
echo "Synced vocabulary and rule catalogue from $SRC to $DEST"
