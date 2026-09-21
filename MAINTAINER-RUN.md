# Maintainer run briefing

This file is the briefing for an unattended session that fires from
the self-maintaining-repo Routine. Draft only: the Routine described
in [tasks/future-self-maintaining-repo.md](tasks/future-self-maintaining-repo.md)
does not exist yet, so nothing calls this file today. Update this
file directly whenever that design changes, so the two stay
consistent.

This file is committed to `planning`, not to `main`, because it is
process, not shipped product. A change to it is never a plugin
change and never needs a version bump or a release.

## Ground rules

- Unattended. Never call `AskUserQuestion`. Never wait for input.
- One issue per run.
- No force push, no history rewrite, on either repo.
- No change outside `jimbarritt/claude-plugins` and
  `jimbarritt/software-english`.
- Two failed attempts at the same fix are the limit. Escalate on the
  third.

## Steps

1. **Bootstrap.** Clone `claude-plugins`. Add the `planning` worktree
   and read this file from there. Read `CLAUDE.md` on `main`.
2. **Claim an issue.** The oldest open issue labelled `agent:go` with
   no other `agent:*` label and no `supervisor` label. If an issue
   labelled `supervisor` has a newer comment from the supervisor than
   the session's own last comment, take that one first: remove
   `supervisor`, read the thread and its task file, and continue that
   work instead of starting new. If nothing qualifies, stop.
3. **Claim it.** Label the issue `agent:working`. Comment naming this
   session.
4. **Plan.** Dispatch a subagent on Opus (`Agent` tool,
   `subagent_type: "Plan"`, `model: "opus"`) with the issue text and
   the surrounding code, to read it and return a plan. Write
   `tasks/issue-N-<slug>.md` on `planning` from what it returns: the
   ask verbatim, your reading of it, the plan. Update `STATE.md`'s "In
   progress". Push `planning`.
5. **Work.** Do the work on `main`. Run the test suites. Run
   `/swe:lint-file` on every prose file touched. Run
   `scripts/check-unshipped.sh`.
6. **Ship.** Bump `version` in the affected plugin's `plugin.json`.
   Commit with `closes #N`. Push `main`.
7. **Release.** Run `release-plugin.yml` via `actions_run_trigger`.
   Poll `actions_get` until it finishes. Treat a failed run as
   blocked work: go to Escalate.
8. **Close the loop.** Comment on the issue: commit, release tag,
   what changed. Close the issue if the commit didn't.
9. **Record.** Update `STATE.md` and the task file with the outcome.
   Push `planning`.
10. **Report.** End your final message with one line first:
    `#N done: <plugin>-vX.Y.Z` or `#N needs supervisor: <question>`.
    The Routine's push notification is built from this line.

## Escalate

Stuck means one of:

- Two readings of the issue lead to materially different work.
- Two attempts at a fix both fail their own tests.
- CI is red on `main` after the push and the cause is not in your diff.
- The release workflow fails for a reason you cannot correct.
- The work needs a change outside the two repos in scope.

On stuck:

1. Write the task file: what was tried, what is blocked, the one
   question. Push `planning`.
2. Comment on the issue with that one question. One question only.
3. Swap `agent:working` for `supervisor`.
4. End the run with `#N needs supervisor: <question>`.

The supervisor (Jim, today) answers on the issue. The next firing
picks it up at step 2 above.
