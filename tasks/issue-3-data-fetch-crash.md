# Issue #3: data fetch fails in a cloud session, crashes the Stop hook

Issue: https://github.com/jimbarritt/claude-plugins/issues/3

## Summary

Found live in a `jimbarritt/tsk` cloud session. `data/core-rules.toml`
is fetched at hook run time, not shipped with the plugin. In that
session, `fetch-software-english-data.sh`'s plain `curl` against a raw
`github.com` tarball URL got a 403 from the session's egress proxy (a
policy denial, not a transient failure), and no cache existed yet in
the fresh container to fall back on. `stop-check.sh` called the fetch
script without checking its exit code, then invoked the linter anyway.
`load_rule_catalogue()` did an unguarded `path.open()` on the missing
file, raising `FileNotFoundError`, which crashed the hook.
`report_and_maybe_block` treated the crash as a block but printed a
misleading "0 errors, 0 warnings" summary, since the traceback in the
details file didn't match its `[error]`/`[warning]` grep.

Jim diagnosed and hand-fixed the immediate crash live in that session
(`git clone` the spec repo, copy the files in by hand), then filed this
issue for the underlying gap.

## Fix

Two independent changes, both from the issue's own "Suggested fix":

1. `fetch-software-english-data.sh`: fetch via
   `git clone --depth 1 --branch <tag>` instead of a raw HTTPS tarball
   `curl`. Verified: a cloud session's egress policy can deny the
   generic HTTPS lane while still serving git's smart-HTTP protocol for
   a public repo clone, through a separate proxy lane — this is exactly
   what let Jim's manual fix work live.
2. `software_english_lint.py`'s `load_rule_catalogue()`: returns
   `(None, None)` when `data/core-rules.toml` is missing, instead of
   raising. `main()` treats `None` as "skip this check", prints an
   actionable message, and returns 0 — matching every other data loader
   in the file (`load_vocabulary`, `load_structure_nouns`,
   `load_banned` already fail open the same way; this one didn't).

Also added `tests/lint_fail_open_test.sh`: a deterministic, offline
regression test for fix 2 (copies `scripts/` to a scratch dir with no
`data/`, asserts exit 0, no traceback, and the skip message printed).

Version bump: 0.3.0 to 0.3.1.

## Status

Done. Diagnosed and fixed in one pass (no design discussion needed —
the issue's own root-cause analysis and suggested fix were sufficient).
Shipped on `main` at
[`6f08705`](https://github.com/jimbarritt/claude-plugins/commit/6f08705),
which closed the issue automatically ("closes #3" in the commit
message, pushed directly to the default branch).

Verified by hand before pushing: the new fetch script actually clones
successfully in this session's sandbox; the linter exits 0 with a clean
message (no traceback) when `data/core-rules.toml` is missing; normal
linting (em dash, vocabulary) still works correctly with real cached
data present; both `tests/hooks_test.sh` (20/20) and the new
`tests/lint_fail_open_test.sh` (3/3) pass.

## Next step

None — closed. Not a recurring pattern to track further unless it
resurfaces.
