# planning

This branch holds working documents for tasks in progress across the
`claude-plugins` and `software-english` repos. It has no history in common
with `main` and is not merged into it.

Purpose: let a session pick up where a previous session left off, when
"update the plan" is said.

## Structure

```text
planning/
  README.md            - this file
  STATE.md             - current status: what's in progress, what's next
  tasks/               - one file per task or workstream, as needed
  MAINTAINER-RUN.md     - briefing for an unattended maintainer session
                          (see tasks/future-self-maintaining-repo.md)
  ALLOWLIST.md          - GitHub accounts the maintainer session
                          auto-processes issues from
```

## Rules

- `STATE.md` holds the live summary. Keep it short and current.
- A task file under `tasks/` holds detail for one workstream: goal,
  decisions made, open questions, next step.
- When a task finishes, say so in `STATE.md` and leave the task file as a
  record rather than deleting it.
- Repos in scope: `jimbarritt/claude-plugins` (primary) and
  `jimbarritt/software-english` (upstream spec, changed when the plugins
  repo needs a spec change).
