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
- The Routine starts with no repository attached. Its prompt clones
  `claude-plugins` after the session starts, and `MAINTAINER-RUN.md` step 1
  calls `add_repo` for both repositories.
- The `SessionStart` hook in `.claude/settings.json`
  (`tsk thread session-start --install-plugin claude-cli`) runs only when the
  repository is attached at session start. In a Routine session it does not
  run. So the tsk plugin is not installed, the ledger is not fetched, no thread
  is bound, and the tsk Stop hook check does not run.
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

## Open question

While the `planning` branch stays, does the Routine write each issue to the
ledger only, or to both the ledger and `STATE.md`/`tasks/`? The
recommendation is both, until Jim removes the `planning` branch.

## Reference

The `M-ADMIN-03` Routine in `jimbarritt/tsk` (`trig_019AVSCvfqAWSVzeKV88p863`)
already runs under tsk. Its prompt resumes a standing thread with the
`resume-thread` skill, falls back to `start-thread` for its mission, and runs
`pause-thread` at the end.
