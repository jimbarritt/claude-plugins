# State

Last updated: 2026-09-19

## In progress

- [Issue #2](https://github.com/jimbarritt/claude-plugins/issues/2):
  `software-english-lint` per-hook enable/disable. See
  [tasks/issue-2-per-hook-toggle.md](tasks/issue-2-per-hook-toggle.md).

## Next

- Jim reviews the issue #2 proposal and answers its remaining questions
  (5-8). Then implement on `main`.
- After issue #2 lands:
  [tasks/future-inference-tier-rework.md](tasks/future-inference-tier-rework.md),
  not yet filed as an issue. Two ideas: hand inference off to a subagent
  instead of running it in-hook, and reconsider when the inference tier
  triggers at all (not every edit, not requiring a manual reminder
  either).

See [tasks/index.md](tasks/index.md) for the full task list.

## Repos in scope

- `jimbarritt/claude-plugins` - primary repo for this work.
- `jimbarritt/software-english` - upstream spec repo, changed when a
  plugins-repo task needs a spec change.
