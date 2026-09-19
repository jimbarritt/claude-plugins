# State

Last updated: 2026-09-19

## In progress

- [tasks/future-swe-output-style.md](tasks/future-swe-output-style.md)
  is implemented and committed to `main` at `24fa005`, one commit ahead
  of `origin/main`. Waiting on Jim to confirm the push.

## Next

In priority order (Jim's pick):

1. [tasks/future-inference-tier-rework.md](tasks/future-inference-tier-rework.md):
   hand inference off to a subagent instead of running it in-hook, and
   reconsider when the inference tier triggers at all (not every edit,
   not requiring a manual reminder either).
2. [tasks/future-stop-reply-check.md](tasks/future-stop-reply-check.md):
   resolved for Claude Code by the output-style task above (the reply
   check no longer runs there, so the block-and-retry loop does not
   fire). Still open for Copilot CLI, which keeps the reply check
   unchanged.

## Recently done

- [tasks/future-swe-output-style.md](tasks/future-swe-output-style.md):
  a plugin output style, forced on with `force-for-plugin: true`, puts
  Software English's rules directly in the system prompt. Claude
  Code's `stop-check.sh` reply/transcript check now skips outright;
  Copilot CLI, which has no output-style mechanism, keeps it unchanged.
  Committed to `main` at `24fa005`, not yet pushed.
- [Issue #2](https://github.com/jimbarritt/claude-plugins/issues/2):
  `software-english-lint` per-hook enable/disable. Shipped on `main` at
  [`36391c4`](https://github.com/jimbarritt/claude-plugins/commit/36391c4),
  which closed the issue automatically. See
  [tasks/issue-2-per-hook-toggle.md](tasks/issue-2-per-hook-toggle.md)
  for the full record, including a jq gotcha the new unit test caught.

See [tasks/index.md](tasks/index.md) for the full task list.

## Repos in scope

- `jimbarritt/claude-plugins` - primary repo for this work.
- `jimbarritt/software-english` - upstream spec repo, changed when a
  plugins-repo task needs a spec change.
