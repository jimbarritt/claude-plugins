# Issue #5: gh issue create refused until the target repo is attached to the session

Issue: https://github.com/jimbarritt/claude-plugins/issues/5

## Summary

Filing an issue from a Claude Code Remote session (e.g. via
`/swe:send-feedback`) fails if the target repository is not already in
that session's GitHub scope: `Access denied: repository "..." is not
configured for this session.` The fix is to call `add_repo` for the
target repo first, then retry. Hit while filing issue #4, which needed
`jimbarritt/claude-plugins` added to a session scoped to
`jimbarritt/tsk`/`jimbarritt/tsk-nexus`.

## Why this is not a claude-plugins code fix

This is a restriction imposed by the session harness (Claude Code
Remote), not GitHub's API: GitHub's issue-creation endpoint only needs
the caller's token and repo permissions. Nothing in this repository
controls that behaviour. The issue's own suggested direction is to
raise it with whoever owns the session harness, and, if the answer is
"working as intended," to document the friction somewhere a skill
author or user actually hits it.

## Actionable scope for this repo

Not the harness restriction itself. The one thing worth doing here:
`skills/send-feedback/SKILL.md` Step 4.4 (`gh issue create`) does not
warn that this can happen. Add a line there so a future run of the
skill recognises the denial for what it is and knows the fix
(`add_repo` for the target repo, then retry) instead of treating it as
an unexplained failure.

## Status

Done. The note is on `main` at
[`7e7abdd`](https://github.com/jimbarritt/claude-plugins/commit/7e7abdd),
which closed the issue automatically. Lint run on the edited file: one
real finding (`banned-word` on "refuses"), fixed; the file's ~344
`vocabulary-membership` warnings are pre-existing across the whole
document, not from this change, confirmed by linting the pre-edit
version separately. All three test suites pass.

## Next step

1. ~~Add the one-line note to `skills/send-feedback/SKILL.md` Step 4,
   near the `gh issue create` call.~~ Done.
2. Separately (not tracked as a claude-plugins task): raise the
   underlying harness question with whoever owns Claude Code Remote's
   session-scoping, per the issue's own suggestion. Out of scope for
   this repo to resolve.
