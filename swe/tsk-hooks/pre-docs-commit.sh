#!/usr/bin/env bash
# swe-docs-hook-version: 1
#
# tsk documents hook installed by /swe:install-commit-hook. Its source of
# truth is swe/tsk-hooks/pre-docs-commit.sh in the claude-plugins
# repository; the installer copies it verbatim to the place the user
# chose (the user config directory, this clone's state directory, or the
# code repository), so it runs with no Claude Code session, no plugin
# runtime, and no model attached. See ADR 0025 in jimbarritt/tsk for the
# hook point tsk calls it through.
#
# Called by `tsk ledger doc put <path>` (one changed path) and
# `tsk ledger push` (every document changed since the last push), with
# the documents worktree as the current directory and TSK_DOCS_WORKTREE
# set to its absolute path. Deleted documents are never passed.
#
# Runs the deterministic tier only, on the Markdown paths among its
# arguments: this hook runs outside any Claude Code session, where no
# model is available, and a push must not wait on one anyway. The full
# two-tier check stays available through /swe:lint-file <path>.
#
# No row is written to the lint ledger (<git-common-dir>/swe/lint-log.ndjson):
# that ledger records a two-tier, nonce-guarded verdict, read only by the
# git pre-commit hook, and a ledger document's path could collide with a
# code-repository path of the same name. Exit status and the printed
# output are this hook's whole answer.
#
# Fail-open boundary: a document passes unevaluated when this hook
# cannot evaluate it at all (no python3, the swe plugin's linter not
# found, no rule catalogue cached, or any linter exit code other than 0
# or 1). It blocks only on an evaluated error-severity finding.
set -uo pipefail

PY="$(command -v python3 2>/dev/null || true)"
if [ -z "$PY" ]; then
  echo "swe: python3 is not on PATH, so the documents check did not run. Documents allowed." >&2
  exit 0
fi

WORKTREE="${TSK_DOCS_WORKTREE:-$PWD}"
cd "$WORKTREE" 2>/dev/null || true

# --- arguments: existing Markdown paths only, documents that are not --
# Markdown pass with no check.
FILES=()
for arg in "$@"; do
  case "$arg" in
    *.md | *.markdown) ;;
    *) continue ;;
  esac
  [ -f "$arg" ] || continue
  case "$arg" in
    -*) FILES+=("./$arg") ;;
    *) FILES+=("$arg") ;;
  esac
done
[ "${#FILES[@]}" -gt 0 ] || exit 0

# --- find the plugin's linter at run time ------------------------------
# The documents worktree is a linked worktree of the code repository, so
# git rev-parse --git-common-dir from here resolves to that repository's
# own .git, the same one /swe:install-commit-hook's git hook already
# points at. install-docs-hook.sh refreshes this pointer on every run, so
# re-running /swe:install-commit-hook after a swe update is what keeps
# this hook working, the same contract the git hook already has.
GIT_COMMON="$(git rev-parse --git-common-dir 2>/dev/null || true)"
if [ -n "$GIT_COMMON" ]; then
  case "$GIT_COMMON" in
    /*) ;;
    *) GIT_COMMON="$WORKTREE/$GIT_COMMON" ;;
  esac
fi

LINTER=""
if [ -n "${SWE_PLUGIN_ROOT:-}" ] && [ -f "$SWE_PLUGIN_ROOT/scripts/software_english_lint.py" ]; then
  LINTER="$SWE_PLUGIN_ROOT/scripts/software_english_lint.py"
elif [ -n "$GIT_COMMON" ] && [ -f "$GIT_COMMON/swe/plugin-root" ]; then
  ROOT="$(cat "$GIT_COMMON/swe/plugin-root" 2>/dev/null || true)"
  if [ -n "$ROOT" ] && [ -f "$ROOT/scripts/software_english_lint.py" ]; then
    LINTER="$ROOT/scripts/software_english_lint.py"
  fi
fi

if [ -z "$LINTER" ]; then
  echo "swe: the swe plugin's linter was not found, so the documents check did not run. Run /swe:install-commit-hook again to refresh this hook. Documents allowed." >&2
  exit 0
fi

OUT="$("$PY" "$LINTER" --quiet-vocab --cwd "$WORKTREE" "${FILES[@]}" 2>&1)"
STATUS=$?

case "$STATUS" in
  0)
    case "$OUT" in
      *"no rule catalogue cached"*)
        printf '%s\n' "$OUT" >&2
        exit 0
        ;;
    esac
    if [ -n "$OUT" ] && [ "$OUT" != "No sources to check." ]; then
      printf '%s\n' "$OUT"
    fi
    echo "swe: documents check passed; no error-severity findings in the checked document(s)."
    exit 0
    ;;
  1)
    echo "swe: documents check failed (deterministic tier)."
    printf '%s\n' "$OUT"
    echo
    echo "Fix the error lines above, then run the tsk command again."
    echo "/swe:lint-file <path> runs both tiers on one document, including inference-tier judgement."
    exit 1
    ;;
  *)
    echo "swe: the documents check could not run (linter exit $STATUS). Documents allowed." >&2
    [ -n "$OUT" ] && printf '%s\n' "$OUT" >&2
    exit 0
    ;;
esac
