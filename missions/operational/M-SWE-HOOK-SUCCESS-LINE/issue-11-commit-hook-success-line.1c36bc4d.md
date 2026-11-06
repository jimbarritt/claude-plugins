# Issue #11: commit hook: print a success line, not only a failure one

[github.com/jimbarritt/claude-plugins/issues/11](https://github.com/jimbarritt/claude-plugins/issues/11)

## The ask, verbatim

> ## Verdict
>
> `feature-request` (logged via `/swe:feedback`, 2026-09-21).
>
> ## The problem
>
> The pre-commit hook prints on failure only. A passing commit prints
> nothing from swe, so there is no way to tell a hook that ran and passed
> from one that never fired at all: not installed, wrong repository, or
> skipped.
>
> ## Observed
>
> A commit was blocked for a missing lint record on staged content. After
> `/swe:lint-file` recorded both files clean, the retry succeeded in
> silence. The state of the hook was unreadable from the commit output.
>
> ## Proposed fix direction
>
> Print a success line, naming what was checked rather than only that
> something passed. For example:
>
> ```
> [swe-lint hook] 2 staged markdown files, lint record clean
> ```
>
> The count and the verdict make the line evidence. A bare "clean" would
> still leave a misconfigured hook and a passing one hard to tell apart at
> a glance.

## Reading

`swe/git-hooks/pre-commit.sh` already prints on every path that blocks a
commit or falls open on an error. The one silent success path is the one
that matters here: the ledger evaluated every staged file as clean, and no
later gate blocked the commit, so it fell through to the final `exit 0`
with no output at all. Every other silent path (no git, no staged files
matching the configured patterns, `commit-check.enabled: false`) checked
nothing, so staying silent there is correct and not part of this fix.

## Plan (from an Opus-dispatched Plan subagent, against the real code)

1. Add the success line directly before the final `exit 0` in
   `pre-commit.sh` (after the `CFG_BLOCK_DET` check), not right after the
   ledger check passes — so a commit that check passes the ledger but is
   then blocked by `block_on_deterministic` never shows a false "passed"
   line ahead of the block message.
2. Use the file's own existing `swe: ` prefix convention, not the issue's
   `[swe-lint hook]` example (that was illustrating the content the line
   should carry, not asking for a new prefix style; a second prefix would
   fragment grepping for this hook's output).
3. Wording, mirroring the grammar of the existing block message:
   `swe: commit check passed. N staged markdown file(s) have a clean lint
   record for their staged content.` The count is `${#FILES[@]}`, the same
   set already passed to the ledger check, so no extra git call is needed.
   Goes to stdout, like the other pass/block messages.
4. No separate line for the deterministic (advisory) tier: it already
   reports findings when there are any, and doubling the noise on every
   commit for a "ran, no findings" case is scope creep the issue did not
   ask for.
5. Bump the hook's own version marker (`# swe-commit-check-version: 1` ->
   `2`) at the top of `pre-commit.sh`, so `/swe:install-commit-hook`
   re-copies it into repositories that already have the hook installed.
   Without this, existing installs silently keep the old, silent hook.
6. Tests in `swe/tests/commit_check_test.sh`, in the existing
   `git-hooks/pre-commit.sh, exercised through a real commit` section:
   capture output on the existing clean-commit case and assert the new
   line and count; add a two-file case for the count; assert the line is
   *absent* on every path that should stay silent (no staged markdown,
   blocked commit, `enabled: false`, ledger-unreadable fail-open).
7. Update `swe/README.md` and `swe/docs/agent-guide.md` with the new
   success-line behaviour in the commit-check description.
8. Ship: bump `swe/.claude-plugin/plugin.json` version (currently
   `0.13.0`), run the release workflow, note in the release comment that
   existing installs need `/swe:install-commit-hook` re-run to pick up the
   new hook.

Full detail (exact line numbers, exact test additions) is in the Plan
subagent's report, applied directly in the implementation rather than
duplicated here.
