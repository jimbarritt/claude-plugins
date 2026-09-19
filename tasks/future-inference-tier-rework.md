# Future task: rework when and how the inference tier runs

No GitHub issue filed yet. Spun out of
[issue-2-per-hook-toggle.md](issue-2-per-hook-toggle.md) while discussing
that task's Q4. Not started — issue #2's config work finishes first.

## Idea 1: hand off to a subagent instead of running in-hook

Jim, verbatim: the plugin should never run the inference tier itself. When
the deterministic tier passes on a file, the hook should report back to
the main session — "you now need to run a sub agent to do the inference
check on this file `<path>`" — rather than calling `claude -p --safe-mode`
in-process. This runs the inference tier as a subagent the main session
dispatches, not a blocking call inside the hook.

Motivation: this plugin's in-hook inference calls have timed out before.
Moving the call out of the hook removes that failure mode and makes the
check's background work visible instead of hidden inside a hook process.

Today only `file-check.sh`, `bash-check.sh`, `artifact-check.sh`, and
`mcp-send-check.sh` run inference synchronously (`stop-check.sh` already
skips it — see its own header comment on turn-latency cost). So this
touches all four of those hooks.

## Idea 2: reconsider when the inference tier triggers at all

Jim, verbatim: if a full inference check already found 20 issues, re-running
it after every single edit is wasteful — most of those edits are fixing
one of the 20, not introducing new prose. At the same time, Jim does not
want to have to manually remind the agent to run the check, but also does
not think it needs to run on every turn.

So this needs a trigger policy in between "every edit" and "only when
asked": something that knows whether a fresh inference pass is likely to
find something new, without needing a person to ask for it each time.

## Status

Not scoped. No design work done yet — captured as raised, per Jim's
instruction to finish the issue #2 config work first.

## Open questions (not yet asked)

- Does idea 2's trigger policy replace `file-check.sh`'s per-edit
  `--run-inference` call entirely, or sit alongside it?
- What signal decides "worth an inference pass now"? Candidates: a batch
  of edits since the last pass, a explicit end-of-task signal, a time or
  edit-count threshold, or something else.
- Does idea 1 (subagent hand-off) change what idea 2's trigger can even
  see — e.g. does the subagent track "20 known issues" as state across
  calls, or does each invocation start fresh?

## Next step

Return to this once issue #2 ships. Read `file-check.sh`,
`bash-check.sh`, `artifact-check.sh`, `mcp-send-check.sh`, and the
inference-tier code path in `software_english_lint.py` again with these
two ideas in mind, then bring a proposal back to Jim.
