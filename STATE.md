# State

Last updated: 2026-09-19

## In progress

- Nothing right now. Issue #2 shipped — see "Recently done" below.

## Next

In priority order (Jim's pick):

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

## Recently done

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
