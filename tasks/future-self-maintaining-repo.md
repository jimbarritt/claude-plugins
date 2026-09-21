# Future task: a self-maintaining repo

No GitHub issue filed yet. Raised by Jim in conversation on 2026-09-21.
Status: draft plan, not agreed, not started.

## Ask

Jim, verbatim: "what I want to explore now is making this repo self
maintaining. So basically as gh issues come in we should fire up a
session probably needs to be a clean session to ensure context is free.
Give the session a briefing, it uses our planning branch to write a
plan and then executes, pushes and releases. So far you have got most
of that with minimal intervention. If it really gets stuck it can
escalate to me. We need to discuss ways to do that - can you decide to
send me a Claude notification?"

Read as: a GitHub issue on `claude-plugins` starts an unattended
session. That session reads a briefing, writes a task file on the
`planning` branch, does the work on `main`, tests it, bumps the
version, releases it, closes the issue. When the session cannot
continue without Jim, it escalates, and one escalation path is a
notification to Jim's phone.

## Decisions

Jim has confirmed three points, so these are fixed rather than open:

- The briefing lives on the `planning` branch, not on `main`. See
  `MAINTAINER-RUN.md` in this branch's root.
- The escalation label is `supervisor`, not a name. Jim holds that
  post today; the label names the role, not the person. Escalation
  otherwise runs as first proposed: the issue label plus a Routine
  push notification, no other channel by default.
- Cadence: hourly, restricted to UK waking hours. Jim did not name
  exact bounds, so 07:00 to 22:00 UK local is the working default,
  16 firings a day; Jim can narrow or widen it. No firing happens
  overnight, so an issue filed at 23:00 waits for the 07:00 firing.

  The four hours are UK local, and `create_trigger`'s cron is UTC, so
  the actual UTC range shifts by one hour between BST and GMT. The
  existing "Adjust scheduled tasks for GMT" reminder already retimes
  four other Routines each clock change; add this one to that list
  once it exists, rather than leaving it to drift out of step with UK
  local time.

## What exists today

- **Routines.** `create_trigger` with `create_new_session_on_fire`
  starts a fresh session on a cron schedule, in a named environment,
  with a stored prompt. A Routine takes `notifications: {push, email}`.
  Jim's account has six Routines in this shape already. Two have
  `push: true` (the nightly KB inbox catalogue, the agentic engineering
  brief). The `M-ADMIN-03` Routine in `jimbarritt/tsk` is the closest
  prior art: a daily unattended run against a repo, a prompt that names
  the mission file to read and forbids `AskUserQuestion`, a bootstrap
  step that clones the repo before work starts.
- **GitHub from inside a cloud session.** The `mcp__github__*` tools
  cover what the loop needs: `list_issues`, `issue_read`,
  `issue_write` (labels, state, assignee), `add_issue_comment`,
  `actions_run_trigger` (runs `release-plugin.yml`), `actions_get`
  (checks the release run). `gh` is not available in a cloud session.
- **Release tooling.** `scripts/check-unshipped.sh` and
  `release-plugin.yml` already hold the release rule. CI runs the
  check on every push to `main`.
- **The planning branch.** `STATE.md` and `tasks/` already carry
  state between sessions. The last eight issues went through this
  loop by hand: task file, implement, test, lint, bump, release,
  close.
- **Notification tools in a session.** `PushNotification` sends to
  the terminal, and to the phone when Remote Control is connected.
  The Routine's own `push` notification is sent by the platform when
  a run finishes "with something noteworthy", built from the run's
  final summary.

## Design

### Trigger: how an issue starts a session

Three options.

1. **Hourly Routine that polls.** A fresh session fires on a cron,
   lists open issues, takes one, works it, stops. An idle firing
   lists issues, finds nothing, and stops in under a minute.
   Recommended. It uses only what exists today, and the session has
   the full cloud tool set (GitHub MCP, planning branch, Routines).
2. **GitHub Actions on `issues.opened`** with
   `anthropics/claude-code-action`. Fires within seconds of the
   issue. Runs on a GitHub runner, not in the cloud environment: no
   Routines, no `send_later`, no Remote Control, and the planning
   branch convention has to be rebuilt in the action's prompt. Needs
   an API key in repo secrets. Not recommended for the first version.
3. **`watch_url` webhook.** Session-scoped, ends with the session.
   Rejected.

Latency of option 1 is up to one cron period. That is acceptable for
a plugin repo.

### Claiming an issue

Labels carry the state, so Jim reads it on the issue and two firings
do not take the same issue.

| Label | Meaning |
|---|---|
| `agent:go` | Jim opts the issue in. The Routine takes only labelled issues at first. |
| `agent:working` | A session holds this issue. Set on claim, with a comment naming the session. |
| `supervisor` | The session stopped on a question for whoever holds the supervisor post (Jim, today). The comment above the label holds the question. |
| `agent:hold` | Jim takes the issue out of scope without closing it. |

Rules:

- One issue per firing. The oldest `agent:go` issue with no other
  `agent:*` label and no `supervisor` label.
- An issue labelled `supervisor` whose newest comment is by Jim is
  taken before any new issue: the answer is in, so the session
  removes `supervisor`, reads the thread and the task file, and
  continues.
- `agent:working` older than three hours with no new commit on
  `main` and no new comment is a dead session. The next firing
  removes the label and takes the issue again.
- Opt-in (`agent:go`) first. Flip to opt-out (every open issue,
  `agent:hold` to exclude) once a few runs go clean.

### The briefing

The briefing lives on the `planning` branch, as `MAINTAINER-RUN.md` at
its root, not on `main`. It is process, not shipped product, so it
belongs with `STATE.md` and `tasks/` rather than in the released
tree; a change to it is never a plugin change and never needs a
version bump or a release. The Routine prompt stays short: clone,
add the `planning` worktree, read `MAINTAINER-RUN.md`, follow it.

The steps, ground rules, and escalation procedure are written out in
`MAINTAINER-RUN.md` itself, not repeated here: bootstrap and claim an
issue, plan on `planning`, do the work and test it on `main`, bump and
release, close the loop, record the outcome on `planning`, report a
one-line summary the Routine push is built from. Update
`MAINTAINER-RUN.md` directly as the design changes rather than
editing this summary out of step with it.

### Escalation

The session is stuck when one of these holds:

- Two readings of the issue lead to materially different work.
- Two attempts at a fix both fail their own tests.
- CI is red on `main` after the push and the cause is not in the diff.
- The release workflow fails for a reason the session cannot correct.
- The work needs a change outside `claude-plugins` and
  `software-english`.

On stuck, in this order:

1. Write the task file: what was tried, what is blocked, the one
   question. Push `planning`.
2. Comment on the issue with that one question. One question only,
   per the working rule in `CLAUDE.md`.
3. Swap `agent:working` for `supervisor`.
4. End the run with the summary line `#N needs supervisor: <question>`.

Jim, as the current supervisor, answers on the issue. The next firing
picks it up per the claim rules.

### Notification channels, assessed

Jim asked whether a session can decide to send him a Claude
notification, and has since confirmed the channel: the issue label is
the record, the Routine push is the signal, nothing else by default.
The table below is the full assessment behind that choice.

| Channel | Who sends it | Reaches | Under the session's control? |
|---|---|---|---|
| Routine `push: true` | The platform, on run finish | Phone | Partly. The session writes the summary. The platform decides whether the run counts as noteworthy. |
| `PushNotification` tool | The session | Terminal, and phone via Remote Control | Yes, but a Routine-fired session has no terminal and no Remote Control. Untested there. |
| Issue comment + `supervisor` label + assign the supervisor | The session, via GitHub | GitHub notifications (email, app) | Yes. Durable. Attached to the issue. |
| Gmail `send_message` | The session, via the Gmail connector | Inbox | Yes, if the Routine is granted the Gmail connector. Heavier. Fallback only. |

Decision: the issue comment plus `supervisor` label is the record and
always happens. The Routine push is the immediate signal. Test
`PushNotification` from a fired session anyway (step 1 below), since
it is cheap to check and useful if it turns out to work. Gmail stays
out of scope unless the two above prove insufficient.

## Steps

1. **Notification experiment.** Create a one-shot Routine
   (`run_once_at` a few minutes out, `create_new_session_on_fire`,
   `notifications: {push: true}`). Prompt: call `PushNotification`
   with a test message, report its result, end with a one-line
   summary. Record what reaches Jim's phone and from which channel.
   Cost: one short session.
2. **Labels.** Create the four labels on `claude-plugins`.
3. **Briefing.** Write `MAINTAINER-RUN.md` on `planning`. Lint it.
4. **Routine.** Create the hourly Routine in the `Default`
   environment, `push: true`, prompt as above. Cron at minute 0,
   restricted to the hours covering 07:00 to 22:00 UK local at
   creation time (`0 6-21 * * *` in BST, `0 7-22 * * *` in GMT).
   Add it to the seasonal clock-change reminder once that Routine
   is set up.
5. **Dry run.** File a small real issue, label it `agent:go`, watch
   one firing end to end. Read the task file and the issue thread it
   leaves.
6. **Escalation dry run.** File an issue written to be ambiguous.
   Confirm the `supervisor` path and the push notification. Answer on
   the issue. Confirm the resume path.
7. **Iterate the briefing** from what those runs wrote. Then consider
   flipping to opt-out.

## Open questions

Escalation channel and cadence are settled (see Decisions above).
Remaining, for Jim, one at a time:

1. Model for the worker session.
2. Whether to reuse the `tsk` mission and thread framework, or keep
   this loop self-contained in `claude-plugins`.
3. Whether `software-english` changes stay in scope for an unattended
   run, as they are for an attended one.
