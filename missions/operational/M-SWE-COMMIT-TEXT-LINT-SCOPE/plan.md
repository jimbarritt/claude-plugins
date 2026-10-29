# Plan: claude-plugins#30 — commit-or-pr-text hook lints stale message files and the whole command

Mission: M-SWE-COMMIT-TEXT-LINT-SCOPE
Issue: https://github.com/jimbarritt/claude-plugins/issues/30

## The ask (verbatim)

> ## Verdict
>
> False positive, `anthropomorphism`, from the PreToolUse Bash hook that
> lints commit and PR text.
>
> ## Problem
>
> The hook lints the full text of the Bash command, including the shell
> plumbing around the message. A command that removes a flagged phrase
> from a message must contain that phrase, so the hook blocks the command
> that fixes the fault.
>
> Shape, with a neutral example:
>
>     python3 -c "
>     s = open('body.md').read()
>     s = s.replace('the service wants a token', 'the service requires a token')
>     open('body.md', 'w').write(s)
>     "
>
> The first argument to `replace` contains the flagged phrase, and the
> hook reports an `anthropomorphism` error for the whole command. The
> message itself has no fault after the command runs. The same applies to
> the search pattern of a `sed` call.
>
> ## Proposed fix
>
> 1. Lint only the message text the hook can identify: the `--title`
>    value, the `--body` value, the contents of the `--body-file` file,
>    and the `-m` value of `git commit`. Skip all other parts of the command.
> 2. If a command has none of these, skip it, or lint it at warning
>    severity only.
>
> Fixtures:
>
> - `gh issue create --title "..." --body-file f.md` with a fault in
>   `f.md`: error;
> - the `python3 -c` command above: no finding;
> - `sed -i 's/the service wants/the service requires/' f.md`: no
>   finding.

## Reading: what's already fixed on main, what's still broken

`swe/hooks/bash-check.sh` already (commit 18a0ba8, 30 Sep) limits
extraction to `-F`/`--body-file`/`--file` contents or the quoted value
after `-m`/`--message`/`--body`/`--title`, gated on the command
containing `git commit`/`gh pr`/`gh issue`. Verified directly against
the issue's three fixtures on current main (HEAD 12f182c): all three
already give the desired result (standalone `python3 -c` and `sed -i`:
no finding; `gh issue create --title ... --body-file f.md` with a fault
in f.md: error). The reporter most likely hit this on an older pinned
install, predating the 30 Sep fix.

But three linked defects remain, all real and reproducible on current
main:

1. **Stale file read.** The `-F`/`--body-file` target is read from disk
   at hook time, before the rest of the same Bash command has run. So
   `sed -i 's/the service wants a token/the service requires a token/' body.md && git commit -F body.md`
   lints the pre-fix, still-faulty `body.md` and blocks the exact
   command that fixes it — the same symptom the issue describes, via a
   combined fix-then-commit command rather than the issue's simplified
   standalone example. This is the confirmed, in-scope bug.
2. **Flag extraction scans the whole command, not just the git/gh
   call.** E.g. `grep -F wants notes.txt && git commit -F body.md`
   picks up the `-F` from `grep`, not from the commit.
3. **`--title` is dropped whenever a body file is read** (the file
   branch and the inline-regex branch are mutually exclusive), so
   `gh issue create --title "..." --body-file f.md` never lints the
   title, though the issue's own proposal lists both.

## Fix design

Split `COMMAND` at the first `git commit`/`gh pr`/`gh issue` match:
- `PRE` = everything before it.
- `INVOCATION` = that match onward.

Run all flag/file-argument extraction on `INVOCATION` only (fixes
defect 2). Lint the `-F`/`--body-file` contents **and** any inline
`--title`/`--body`/`-m` value found in `INVOCATION`, always both when
present (fixes defect 3). Before reading the file, check whether its
basename appears anywhere in `PRE`; if so, skip reading it (fail open —
consistent with the script's own documented rule, "a false negative
here is safer than a false block") since the file is provably about to
be/have been touched by an earlier part of the same command and its
on-disk content cannot be trusted as the final message (fixes defect
1). No command substitution or edit simulation; no shell parsing beyond
what's already there.

Secondary quirk — `-m "$(...)"` with nested quotes mis-bounding the
capture — is a false negative only (never a false block), same class as
the heredoc limitation already documented. Out of scope for this
change: document it as a known limitation, no code change, no new
issue.

## Tasks

1. Edit `swe/hooks/bash-check.sh`: split command at the git/gh gate,
   scope all extraction to the invocation half, add the
   basename-in-PRE staleness check before reading a file, always lint
   inline title/body/-m value alongside file contents when both
   present, update the header/inline comments to describe the new
   behaviour and name claude-plugins#30.
2. Add `swe/tests/bash_check_test.sh`: offline, fixture-plugin test
   (adapt the `data/core-rules.toml` fixture catalogue from
   `swe/tests/commit_check_test.sh`, add a `word_list = ["wants"]`
   anthropomorphism rule) covering: a positive control; the issue's
   three original fixtures as regressions; the stale-file-read bug
   fixed (sed+commit -F, python-write+commit -F); heredoc-write+gh
   body-file; title-linted-alongside-clean-body-file; flag-scoping
   (grep -F before the real git/gh -F); PRE-text-not-linted; no-message
   commands silent; `-F -` (stdin) silent.
3. Update `swe/docs/agent-guide.md`'s known-limitations bullet (~line
   694) with the two new documented limitations (file named in PRE is
   skipped; nested-quote `-m "$(...)"` mis-bounding).
4. Bump `swe/.claude-plugin/plugin.json` version 0.24.12 -> 0.24.13.
5. Run `swe/tests/bash_check_test.sh`, `swe/tests/hooks_test.sh`,
   `swe/tests/commit_check_test.sh`, and the rest of `swe/tests/*.sh`;
   run `/swe:lint-file` on `agent-guide.md`; run
   `scripts/check-unshipped.sh`.
6. Commit with `closes #30`, push `main`.
7. Run `release-plugin.yml` for `swe`, poll to completion.
8. Comment on the issue, close the loop, remove `agent:working`.
