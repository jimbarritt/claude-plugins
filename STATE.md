# State

Last updated: 2026-09-19

## In progress

- [Issue #2](https://github.com/jimbarritt/claude-plugins/issues/2):
  `software-english-lint` per-hook enable/disable. See
  [tasks/issue-2-per-hook-toggle.md](tasks/issue-2-per-hook-toggle.md).

## Next

- Jim reviews the issue #2 proposal and answers its one remaining
  question (8). Then implement on `main`.
- After issue #2 lands, in priority order (Jim's pick):
  1. [tasks/future-swe-output-style.md](tasks/future-swe-output-style.md):
     a plugin output style, forced on with `force-for-plugin: true`, that
     puts Software English's rules directly in the system prompt instead
     of catching violations reactively. Jim is keen to start this one
     first.
  2. [tasks/future-stop-reply-check.md](tasks/future-stop-reply-check.md):
     the Stop hook's per-reply block-and-retry loop is wasteful for a
     small mechanical fix (e.g. an em dash) — related to, and possibly
     addressed by, the output-style task above.
  3. [tasks/future-inference-tier-rework.md](tasks/future-inference-tier-rework.md):
     hand inference off to a subagent instead of running it in-hook, and
     reconsider when the inference tier triggers at all (not every edit,
     not requiring a manual reminder either).

See [tasks/index.md](tasks/index.md) for the full task list.

## Repos in scope

- `jimbarritt/claude-plugins` - primary repo for this work.
- `jimbarritt/software-english` - upstream spec repo, changed when a
  plugins-repo task needs a spec change.
