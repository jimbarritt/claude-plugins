# Report: claude-plugins#30 — commit-or-pr-text hook lints stale message files and the whole command

Mission: M-SWE-COMMIT-TEXT-LINT-SCOPE
Issue: https://github.com/jimbarritt/claude-plugins/issues/30 (closed)

## Outcome

Commit: `4014c35` on `jimbarritt/claude-plugins` `main` —
"swe: scope bash-check.sh's text extraction to the git/gh invocation"
(`closes #30`).

Release: `swe-v0.24.13` (`swe/.claude-plugin/plugin.json` 0.24.12 ->
0.24.13), via `release-plugin.yml` run
https://github.com/jimbarritt/claude-plugins/actions/runs/40865342691
(success).

Issue closed automatically by the commit's `closes #30`; comment
posted naming the commit, the release tag, and what changed;
`agent:working` label removed.

## What changed

Investigation before planning found that `swe/hooks/bash-check.sh`'s
extraction logic (added 30 Sep, commit 18a0ba8) already satisfied the
issue's three literal fixtures on `main` before this change — verified
directly by piping JSON PreToolUse payloads into the script. The
reporter most likely hit the original bug on an older pinned install.

But three linked defects were still live and reproducible on `main`:

1. `-F`/`--body-file` is read from disk at hook time, before the rest
   of the same Bash command runs, so a command that fixes a flagged
   phrase in a file and then commits/opens a PR with it (e.g.
   `sed -i 's/.../.../ 'body.md && git commit -F body.md`) was blocked
   on the pre-fix, stale content — the same symptom the issue
   describes, via a combined fix-then-commit command rather than the
   issue's standalone example.
2. Flag/file extraction scanned the whole command rather than just the
   git/gh invocation, so an unrelated earlier flag (e.g. `grep -F`)
   could be mistaken for the commit's own `-F`.
3. An inline `--title` was dropped whenever a `--body-file` was also
   read, since the two extraction paths were mutually exclusive.

Fix: split the command at the first `git commit`/`gh pr`/`gh issue`
match. Read all flags and file arguments only from that invocation
(fixes 2). Skip reading a message file whose path also appears earlier
in the same command — failing open, per the hook's own documented rule
that a false negative is safer than a false block (fixes 1). Always
lint an inline `--title`/`--body`/`-m` value alongside any file content
(fixes 3).

Added `swe/tests/bash_check_test.sh`: an offline, fixture-plugin test
(15 assertions) covering a positive control, the issue's three
original fixtures as regressions, the stale-file-read fix (sed+commit
-F, python-write+commit -F, heredoc-write+gh body-file), flag-scoping
(grep -F before the real git -F), title-linted-alongside-clean/faulty
body-file (both directions), no-message commands, and `-F -` (stdin).

Documented two known limitations in `swe/docs/agent-guide.md`: a
message file named earlier in the same command is skipped (by design,
per the fix above), and a `-m "$(...)"` value whose substitution
contains its own double quotes still mis-binds the capture (a false
negative only, same class as the existing heredoc limitation, left as
a documented limitation rather than a code change, since fixing it
would need real shell quote parsing).

## Verification

Full `swe/tests/*.sh` suite run (19 files, all passing, including the
new one). `/swe:lint-file` run on `swe/docs/agent-guide.md`: the file
is listed in `.swe-ignore`, so "No sources to check." — no action
needed. `scripts/check-unshipped.sh` run before and after the version
bump, confirming the pending-release state and, after the release
workflow, that the new tag matched.

## Found along the way

My own live session's installed `swe` hook (the production, pre-fix
version) intercepted one of my own test Bash tool calls mid-investigation
for containing both a flagged phrase and `git commit -F body.md` in
the same literal command text — a live, incidental reproduction of the
exact bug class this issue describes.
