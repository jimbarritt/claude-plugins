#!/usr/bin/env bash
# swe-commit-check-version: 1
#
# Git pre-commit hook installed by /swe:install-commit-hook. Its source
# of truth is swe/git-hooks/pre-commit.sh in the claude-plugins
# repository; the installer copies it verbatim into the target
# repository's git hooks directory, so it runs with no Claude Code
# session, no plugin runtime, and no model attached.
#
# Two parts, in order, over the staged markdown files (commit-check.paths
# in <repo>/.claude/swe-lint.json, default "*.md"):
#
#   1. Advisory. The deterministic tier, run against each file's staged
#      content. Findings print. They never block the commit unless
#      commit-check.block_on_deterministic is true.
#   2. Blocking. <git-common-dir>/swe/lint-log.ndjson must hold a row
#      with status "clean" for each staged file's exact staged git blob
#      id, written by /swe:lint-file's --record-lint-result step. No
#      row, a row for different content, or a "failed" row blocks the
#      commit and names what to run.
#
# Fail-open boundary: the commit proceeds when this hook cannot evaluate
# the ledger at all (no python3, an unreadable log file). It blocks on
# every answer it does evaluate that is not "clean": an absent ledger
# counts as an evaluated "no record", not a failure to evaluate.
#
# git commit --no-verify always bypasses this hook; the block message
# says so.
set -uo pipefail

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_NAME="$(basename "$0")"

# A pre-commit hook already present at install time is kept verbatim as
# <name>.local and runs first, unchanged; its exit code propagates.
CHAINED="$HOOK_DIR/$HOOK_NAME.local"
if [ -x "$CHAINED" ]; then
  "$CHAINED" "$@" || exit $?
fi

command -v git >/dev/null 2>&1 || exit 0
TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$TOPLEVEL" ] || exit 0
GIT_COMMON="$(git rev-parse --git-common-dir 2>/dev/null)"
[ -n "$GIT_COMMON" ] || exit 0
case "$GIT_COMMON" in
  /*) ;;
  *) GIT_COMMON="$TOPLEVEL/$GIT_COMMON" ;;
esac
LOG="$GIT_COMMON/swe/lint-log.ndjson"
PROJECT_CONFIG="$TOPLEVEL/.claude/swe-lint.json"

PY="$(command -v python3 2>/dev/null || true)"
if [ -z "$PY" ]; then
  echo "swe: python3 is not on PATH, so the commit check cannot check the lint ledger. Commit allowed." >&2
  exit 0
fi

# --- project configuration, from <toplevel>/.claude/swe-lint.json only ---
# This hook runs outside the plugin, so the plugin's own config.json is
# not available to it; the defaults below are used instead.
CFG_ENABLED="true"
CFG_BLOCK_DET="false"
PATTERNS=()
if [ -f "$PROJECT_CONFIG" ] && command -v jq >/dev/null 2>&1; then
  v="$(jq -r '.["commit-check"].enabled' "$PROJECT_CONFIG" 2>/dev/null)"
  [ "$v" = "false" ] && CFG_ENABLED="false"
  v="$(jq -r '.["commit-check"].block_on_deterministic' "$PROJECT_CONFIG" 2>/dev/null)"
  [ "$v" = "true" ] && CFG_BLOCK_DET="true"
  while IFS= read -r line; do
    [ -n "$line" ] && [ "$line" != "null" ] && PATTERNS+=("$line")
  done < <(jq -r '(.["commit-check"].paths // [])[]' "$PROJECT_CONFIG" 2>/dev/null)
fi
[ "$CFG_ENABLED" = "false" ] && exit 0
[ "${#PATTERNS[@]}" -gt 0 ] || PATTERNS=("*.md")

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# NUL-delimited git output must never pass through a bash variable (a
# command substitution silently drops embedded NUL bytes). Every git
# call producing -z output below is piped straight into python, and the
# python scripts themselves live in $TMP rather than a heredoc, so the
# heredoc's own stdin redirection never competes with that pipe.

# Mirrors is_path_ignored()/load_ignore_patterns() in
# scripts/software_english_lint.py. Duplicated deliberately: this hook
# runs standalone and must behave the same whether or not the plugin
# that generated it is still installed.
cat > "$TMP/filter_ignored.py" <<'PYEOF'
import fnmatch
import sys
from pathlib import Path

root = Path(sys.argv[1])
patterns = []
ignore = root / ".swe-ignore"
if ignore.exists():
    for raw in ignore.read_text().splitlines():
        line = raw.strip()
        if line and not line.startswith("#"):
            patterns.append(line)

data = sys.stdin.buffer.read().decode()
for rel in data.split("\0"):
    if not rel:
        continue
    name = rel.rsplit("/", 1)[-1]
    hit = any(
        fnmatch.fnmatch(rel, p) if "/" in p else fnmatch.fnmatch(name, p)
        for p in patterns
    )
    if not hit:
        sys.stdout.write(rel + "\0")
PYEOF

# --- staged files matching commit-check.paths, minus .swe-ignore --------
FILES=()
while IFS= read -r -d '' f; do
  [ -n "$f" ] && FILES+=("$f")
done < <(git diff --cached --name-only --diff-filter=ACM -z -- "${PATTERNS[@]}" \
  | "$PY" "$TMP/filter_ignored.py" "$TOPLEVEL")
[ "${#FILES[@]}" -gt 0 ] || exit 0

# --- part 1: the deterministic tier, advisory, against staged content --
LINTER=""
if [ -n "${SWE_PLUGIN_ROOT:-}" ] && [ -f "$SWE_PLUGIN_ROOT/scripts/software_english_lint.py" ]; then
  LINTER="$SWE_PLUGIN_ROOT/scripts/software_english_lint.py"
elif [ -f "$GIT_COMMON/swe/plugin-root" ]; then
  ROOT="$(cat "$GIT_COMMON/swe/plugin-root" 2>/dev/null || true)"
  if [ -n "$ROOT" ] && [ -f "$ROOT/scripts/software_english_lint.py" ]; then
    LINTER="$ROOT/scripts/software_english_lint.py"
  fi
fi

DET_STATUS=0
if [ -n "$LINTER" ]; then
  STAGED_DIR="$TMP/staged"
  mkdir -p "$STAGED_DIR"
  for f in "${FILES[@]}"; do
    mkdir -p "$STAGED_DIR/$(dirname "$f")"
    git show ":$f" > "$STAGED_DIR/$f" 2>/dev/null
  done
  [ -f "$TOPLEVEL/.swe-ignore" ] && cp "$TOPLEVEL/.swe-ignore" "$STAGED_DIR/.swe-ignore"
  DET_OUT="$(cd "$STAGED_DIR" && "$PY" "$LINTER" "${FILES[@]}" --quiet-vocab 2>&1)"
  DET_STATUS=$?
  if [ -n "$DET_OUT" ] && [ "$DET_OUT" != "No sources to check." ]; then
    echo "swe: deterministic check of the staged markdown (advisory):"
    printf '%s\n' "$DET_OUT"
    echo
  fi
else
  echo "swe: the plugin's linter was not found, so the deterministic check was skipped. The ledger check below still ran." >&2
fi

# --- part 2: the ledger, blocking ---------------------------------------
ALGO="$(git rev-parse --show-object-format 2>/dev/null || true)"
[ -n "$ALGO" ] || ALGO="sha1"

cat > "$TMP/check_ledger.py" <<'PYEOF'
import json
import sys

log_path, algo = sys.argv[1], sys.argv[2]

data = sys.stdin.buffer.read().decode()
order, wanted = [], set()
for entry in data.split("\0"):
    if not entry.strip():
        continue
    meta, _, path = entry.partition("\t")
    parts = meta.split()
    if len(parts) < 2 or not path:
        continue
    key = (path, parts[1])
    if key not in wanted:
        wanted.add(key)
        order.append(key)

latest = {}
try:
    with open(log_path) as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                row = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if not isinstance(row, dict):
                continue
            if row.get("algo") not in (None, algo):
                continue
            key = (row.get("path"), row.get("blob"))
            if key in wanted:
                latest[key] = row  # append order, so the last write wins
except FileNotFoundError:
    pass
except OSError as exc:
    print("UNREADABLE\t%s" % exc)
    raise SystemExit(2)

blocked = 0
for path, blob in order:
    row = latest.get((path, blob))
    if row is None:
        print("%s\tno lint record for the staged content" % path)
        blocked += 1
    elif row.get("status") != "clean":
        print("%s\trecorded status: %s" % (path, row.get("status")))
        blocked += 1
raise SystemExit(1 if blocked else 0)
PYEOF

RESULT="$(git ls-files --stage -z -- "${FILES[@]}" | "$PY" "$TMP/check_ledger.py" "$LOG" "$ALGO")"
LEDGER_STATUS=$?

if [ "$LEDGER_STATUS" -eq 2 ]; then
  echo "swe: the lint ledger could not be read ($LOG), so the commit check could not check it. Commit allowed." >&2
  exit 0
fi

if [ "$LEDGER_STATUS" -eq 1 ]; then
  COUNT="$(printf '%s\n' "$RESULT" | grep -c .)"
  echo "swe: commit blocked. $COUNT staged markdown file(s) have no clean lint record for their staged content:"
  echo
  printf '%s\n' "$RESULT" | while IFS=$'\t' read -r path reason; do
    printf '  %-40s %s\n' "$path" "$reason"
  done
  echo
  echo "Run the full lint on each file, fix anything it reports, stage the fix,"
  echo "then commit again:"
  echo
  printf '%s\n' "$RESULT" | while IFS=$'\t' read -r path _; do
    echo "  /swe:lint-file $path"
  done
  echo
  echo "To commit without this check: git commit --no-verify"
  exit 1
fi

if [ "$CFG_BLOCK_DET" = "true" ] && [ "$DET_STATUS" -ne 0 ]; then
  echo "swe: commit blocked by the deterministic tier (commit-check.block_on_deterministic is true)."
  echo "Fix the findings above, stage the fix, then commit again."
  exit 1
fi

exit 0
