# The issue Routine and tsk: findings

Task: M-ADMIN T-01, make sure the issue Routine runs in a good tsk environment.
Recorded on 2026-10-24.

## Facts

- The issue Routine is the scheduled task `trig_01NpiD8Xnk1Zmqg5qpaLnCrq`,
  "Self-maintaining claude-plugins: issue Routine". It fires hourly from 06:00
  to 21:00 UTC on `claude-sonnet-5`.
- The Routine runs in environment `env_0173H2wsxugkZUm5Whrkmtv9`, the same
  environment as interactive sessions on this repo. That environment has
  tsk 0.26.1 and dolt in `/usr/local/bin`.
- The Routine starts with both repositories attached as sources. The runner
  clones `claude-plugins` to `/home/user/claude-plugins` and `software-english`
  beside it before the session starts.
- The session starts in `/home/user`, the parent directory of the two clones
  (init event of `session_01Kxgz5bvg4rAH2FMwoDqBYh`: `"cwd":"/home/user"`).
  So Claude Code does not load `/home/user/claude-plugins/.claude/settings.json`.
  The `SessionStart` hooks do not run, and the tsk and swe plugins do not load.
  The init event lists only the built-in plugins. No thread is bound, and the
  tsk Stop hook check does not run.
- A plugin installed after session start does not load in that session.
  The Routine can use the `tsk` command directly.
- `MAINTAINER-RUN.md` on `planning` records each issue in `STATE.md` and
  `tasks/` only. Nothing in the Routine writes to the ledger.
- The run that fired at 14:06 on 2026-10-24 (session
  `session_01Kxgz5bvg4rAH2FMwoDqBYh`) works claude-plugins#22, which is
  `M-DOCS-HOOK` in the ledger. At 14:22 it was writing the hook script and the
  installer. The ledger shows all six `M-DOCS-HOOK` tasks as `todo`.

## Changes needed

1. The Routine prompt: after the clone, run the tsk setup by hand. Fetch the
   ledger and bind a thread, or record `tsk thread skip`. `update_trigger`
   can change the prompt.
2. `MAINTAINER-RUN.md`: steps 4 and 9 write the issue to the ledger as a
   mission, with its tasks, its decisions, and the task file as a document.
   The run pauses its thread at the end.

## Reference

The `M-ADMIN-03` Routine in `jimbarritt/tsk` (`trig_019AVSCvfqAWSVzeKV88p863`)
already runs under tsk. Its prompt resumes a standing thread with the
`resume-thread` skill, falls back to `start-thread` for its mission, and runs
`pause-thread` at the end.

## Outcome, 2026-10-24

- Jim answered the open question: ledger only. The `planning` branch is
  deprecated.
- The briefing and the allowlist are now ledger documents of
  `M-SELF-MAINTAIN`: `MAINTAINER-RUN.md` and `ALLOWLIST.md`. The briefing
  creates a mission per issue (`M-CP-<N>` or `M-SE-<N>`), starts a thread on
  it, writes the plan and the report as documents, and pauses the thread at
  the end.
- The Routine prompt now runs `tsk ledger fetch` in `/home/user/claude-plugins`
  and reads the briefing with `tsk ledger doc get`.
- `CLAUDE.md` on `main` points cross-session planning at the ledger
  (commit `7be7379`).
