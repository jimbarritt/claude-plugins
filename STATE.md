# State

Last updated: 2026-09-19

## In progress

- [Issue #2](https://github.com/jimbarritt/claude-plugins/issues/2):
  `software-english-lint` per-hook enable/disable. See
  [tasks/issue-2-per-hook-toggle.md](tasks/issue-2-per-hook-toggle.md).

## Next

- Jim reviews the issue #2 proposal and answers its remaining questions.
  Then implement on `main`.
- After issue #2 lands: a new task, not yet filed as an issue, to move the
  inference tier out of the hooks entirely. A hook that passes the
  deterministic tier reports back to the main session to run a subagent
  for the inference check, instead of calling `claude -p --safe-mode`
  in-process. See the "New idea" section in
  [tasks/issue-2-per-hook-toggle.md](tasks/issue-2-per-hook-toggle.md)
  for the detail captured so far.

See [tasks/index.md](tasks/index.md) for the full task list.

## Repos in scope

- `jimbarritt/claude-plugins` - primary repo for this work.
- `jimbarritt/software-english` - upstream spec repo, changed when a
  plugins-repo task needs a spec change.
