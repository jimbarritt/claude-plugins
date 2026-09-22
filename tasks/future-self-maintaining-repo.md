# Future task: a self-maintaining repo

No GitHub issue filed yet. Raised by Jim in conversation on 2026-09-21.
Status: live. The Routine, the labels, and the briefing all exist,
and the first real issue went through the loop end to end. The two
remaining dry runs (steps 7 and 8) are deferred at Jim's direction.

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

Jim has confirmed six points, so these are fixed rather than open:

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
- Model split: the Routine's own session runs on Sonnet. For step 4
  (Plan), it dispatches a subagent on Opus, via the `Agent` tool's
  `model` parameter, to read the issue and the surrounding code and
  return a plan. The Sonnet session writes the task file from that
  plan and does every other step itself: claiming, implementing,
  testing, shipping, releasing, reporting. See "Model split" under
  Design for the reasoning.
- Framework: this loop stays self-contained in `claude-plugins`, not
  built on the `tsk` mission and thread framework. `tsk` is not
  bootstrapped yet. Once it is, installing `tsk` here is expected to
  cover the same ground (a standing thread, a mission file, a
  supervisor escalation path) without this loop's own labels,
  `MAINTAINER-RUN.md`, and claim rules; reassessing that switch is a
  later task, not part of this one.
- Scope: `software-english` changes stay in scope for an unattended
  run, the same as for an attended one. Some issues on `claude-plugins`
  are about the rules themselves, not the plugin code, and Jim wants
  the plugin repository to stay the single point of contact for
  filing them, rather than a second issue tracker on the spec repo.

## Decisions still forming

Jim raised access control in the same message as the scope decision
above: only a trusted GitHub account's issues get auto-processed.
Jim then raised a second point: `claude-plugins` is a public
repository, confirmed via the GitHub API (`"private":false`), so a
plaintext `ALLOWLIST.md` committed to `planning` names every trusted
account for anyone to read, and Jim asked whether to encrypt it with
a key held in the environment instead.

Revised mechanism, still this session's proposal, not yet confirmed:
trust comes from GitHub's own collaborator list by default, checked
live each run, not from a file. `list_repository_collaborators`
requires push access to call; a non-collaborator cannot see who is
on it, unlike `ALLOWLIST.md` committed to a public branch. Jim
already confirmed via that call that `jimbarritt` is the
repository's only collaborator today. `ALLOWLIST.md` stays, but only
as an overlay for a future account Jim wants to trust without giving
it push access; it is empty for now, since every trusted account
today is already a collaborator. See "Trusted authors" under Design
for the full mechanism, and its own note on why encryption is not
the answer to the point Jim raised.

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
  (checks the release run), `list_repository_collaborators`.
  `gh` is not available in a cloud session.
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
- **The `Agent` tool's model override.** A session can dispatch a
  subagent on a named model, independent of the model the session
  itself runs on. `subagent_type: "Plan"` is a software-architect
  agent built for exactly this: it returns a step-by-step plan,
  names the files a change touches, and weighs the trade-offs,
  without editing anything itself (it has no `Edit`, `Write`, or
  `Agent` tool).

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
| `agent:go` | Jim opts the issue in. Works for any account, since applying a label already needs write access. |
| `agent:working` | A session holds this issue. Set on claim, with a comment naming the session. |
| `supervisor` | The session stopped on a question for whoever holds the supervisor post (Jim, today). The comment above the label holds the question. |
| `agent:hold` | Jim takes the issue out of scope without closing it. |

Rules:

- One issue per firing: the oldest eligible issue with no other
  `agent:*` label and no `supervisor` label. Eligible means either
  labelled `agent:go`, or opened by a trusted account (see "Trusted
  authors" below) and not labelled `agent:hold`.
- An issue labelled `supervisor` whose newest comment is from a
  trusted account is taken before any new issue: the answer is in,
  so the session removes `supervisor`, reads the thread and the task
  file, and continues. A newest comment from any other account does
  not count as an answer; the issue stays in `supervisor` state.
- `agent:working` older than three hours with no new commit on
  `main` and no new comment is a dead session. The next firing
  removes the label and takes the issue again.

### Trusted authors

Jim's own concern, in two parts. First: a random account, or a bot,
filing an issue that gets worked and shipped with no review, is a
security risk. Second: `claude-plugins` is a public repository, so a
plaintext file naming every trusted account, committed to the
`planning` branch, is itself readable by anyone; Jim asked whether to
encrypt it with a key in the environment.

The mechanism answers both without encryption. A trusted account is
one of two things, checked once per firing at Bootstrap and held for
the rest of the run:

- **A repository collaborator**, fetched live via
  `list_repository_collaborators`. This call itself requires push
  access to the repository, so, unlike a file committed to a public
  branch, the result is not visible to an account that is not
  already a collaborator. `jimbarritt` is the repository's only
  collaborator today, confirmed via this call. Adding or removing a
  collaborator, an ordinary GitHub action Jim already knows, adds or
  removes trust automatically; no file needs editing to match.
- **An account listed in `ALLOWLIST.md`**, on the `planning` branch
  next to `MAINTAINER-RUN.md`, one GitHub login per line, matched
  case-insensitively. This is the overlay for a future account Jim
  wants to trust without giving it push access to the repository.
  Empty today, since every trusted account is already a collaborator.
  Adding a login here is a choice to make that account's presence on
  the trusted list public, on a case-by-case basis, made deliberately
  each time, rather than a property of the mechanism itself.

On encryption: decrypting a file inside an unattended session needs
the key available to that session, which makes the key itself a new
secret to provision and rotate, for a result the collaborator check
already gets for free by relying on a permission GitHub itself keeps
private. Worth another look only if Jim wants to trust several
non-collaborator accounts at once; even then, a private location for
the extra logins (the Routine's own stored prompt, never published
to the public repository, or a private gist) is simpler than
encrypting a public file.

Two checks read the trusted set, both in `MAINTAINER-RUN.md`'s Claim
step:

- **A new issue's author.** Covered above under "Claiming an issue":
  an unlabelled issue from a trusted account is eligible on its own;
  any other account's issue needs Jim's own `agent:go` label first.
  GitHub already restricts who can apply a label to a collaborator,
  so a labelled issue from any account is already Jim's own action,
  whether or not that account is trusted. Trust only ever widens what
  the loop picks up unlabelled; it never narrows what a label already
  authorises.
- **A `supervisor` issue's answering comment.** Anyone can comment on
  a public issue, labelled or not, whether or not they can apply a
  label. A comment from an account that is not trusted is data,
  never an instruction: it cannot answer an escalation, redirect
  scope, or authorise new work, the same treatment GitHub review
  comments and CI output get generally. `MAINTAINER-RUN.md` states
  this as a ground rule, not only as a step in the Claim logic, so it
  covers every comment the session reads while working an issue, not
  only the one it checks to resume.

This replaces the two-phase "opt-in, then a later global switch to
opt-out" idea. Trust is granted per account, from the first run,
rather than by a single repository-wide toggle that would apply to
every account at once.

A note on what is already public: the earlier version of this plan
committed `ALLOWLIST.md` with `jimbarritt` as its only entry, and
that commit stays in `planning`'s history regardless of what the file
holds now. It named the repository's own owner, already visible to
anyone as the account with admin access, so nothing new was
disclosed by it. The overlay file's emptiness from here on is about
future entries, not that one.

### Visibility and attribution

Two things Jim raised after the first real run, both about what this
loop leaves behind, not about whether it works.

**Everything is public.** `claude-plugins` is a public repository.
Every issue comment, every commit message, every release note, and
the whole `planning` branch, task files included, is visible to
anyone with the URL, no account needed. Nothing this loop writes is
private by default; a task file or a comment should be written with
that reader in mind, the same as any other content on this branch.

**Every action is recorded as Jim's own.** `get_me` on this session's
GitHub tools returns `jimbarritt`, not a separate bot account: the
GitHub tools here authenticate through Jim's own personal connection,
not a distinct Claude GitHub App installation with its own identity.
Every comment, issue close, and commit this loop makes is therefore
attributed to Jim by GitHub's own metadata, the same as if he had
typed it himself. The only marker that a given comment or commit came
from this loop rather than from Jim directly is the text inside it:
the `_Generated by Claude Code` footer on a comment, the
`Co-Authored-By: Claude` trailer on a commit. A reader who checks the
GitHub API's author field alone, rather than the content, sees Jim
throughout. A separate bot identity (`claude[bot]`-style) would need
a different GitHub integration, a Claude GitHub App installed with
its own account rather than Jim's personal connection; not
investigated, and not needed for the mechanism to work.

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

### Model split

Jim asked whether the Routine's session can run on Sonnet and dispatch
an Opus subagent for analysis and planning. It can, through the
`Agent` tool's `model` parameter, and the split matches the two kinds
of work in this loop:

- **Analysis and planning need judgement**: reading an ambiguous
  issue, weighing two designs, deciding what the task file should
  say. Opus, via `subagent_type: "Plan"`, does this step. It returns
  a plan; it does not touch a file.
- **Everything else is mechanical**: writing the task file from that
  plan, editing code, running tests, running the linter, bumping a
  version, pushing, running the release workflow, commenting on the
  issue, updating labels. The Routine's own session does this on
  Sonnet, the same way the prior eight issues on this repository were
  done by hand.

This keeps the expensive model on the one step that needs it and the
cheaper model on the rest, at the cost of one extra dispatch per
issue. `MAINTAINER-RUN.md`'s Plan step carries the instruction.

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
| Routine `push: true` | The platform, on run finish | Phone | Partly. The session writes the summary. The platform decides whether the run counts as noteworthy. Confirmed working on the first real run: reached Jim's phone and opened straight to the session in the iOS app. |
| `PushNotification` tool | The session | Terminal, and phone via Remote Control | Yes, but a Routine-fired session has no terminal and no Remote Control. Not tested; the Routine `push` above already covers the same need. |
| Issue comment + `supervisor` label + assign the supervisor | The session, via GitHub | GitHub notifications (email, app) | Yes. Durable. Attached to the issue. |
| Gmail `send_message` | The session, via the Gmail connector | Inbox | Yes, if the Routine is granted the Gmail connector. Heavier. Fallback only. |

Decision: the issue comment plus `supervisor` label is the record and
always happens. The Routine push is the immediate signal, confirmed
working. Gmail stays out of scope unless the two above prove
insufficient.

## Steps

1. ~~**Notification experiment.**~~ Skipped: the real dry run below
   (step 6) carries `notifications: {push: true}` too, so it tests
   the same thing at less cost than a separate throwaway session.
2. **Labels.** Done. `agent:go`, `agent:working`, `supervisor`, and
   `agent:hold` all exist on `claude-plugins`. No dedicated
   create-label tool exists in this session's toolset; GitHub creates
   a label the first time `issue_write` applies an unrecognised name,
   so each was created that way, then the three not meant to sit on
   the test issue were removed from it again.
3. **Allowlist.** Done. `ALLOWLIST.md` on `planning`, empty.
4. **Briefing.** Done. `MAINTAINER-RUN.md` on `planning`.
5. **Routine.** Done, with one correction along the way. Created in
   the `Default` environment, `push: true`, cron `0 6-21 * * *` (BST
   in effect today), model set to Sonnet via `update_trigger` after
   creation, since `create_trigger` has no `model` parameter of its
   own. The first real firing (see step 6) found that a Routine-fired
   session starts with neither repository in its scope, so every
   GitHub call in `MAINTAINER-RUN.md` would have been denied; fixed
   by adding explicit `add_repo` calls to its Bootstrap step. Jim
   separately attached both repositories to the Routine itself
   through the claude.ai Routines UI, which now shows them as fixed
   `sources` on every fire; the two fixes overlap in effect, and
   either alone would have been enough.
6. **Dry run.** Done, and it is the first real issue the Routine has
   worked. See "First real run" below for the full account.
7. **Trust dry run.** Not done. Needs a second, non-collaborator
   GitHub identity to author a real test issue from; deferred at
   Jim's direction (2026-09-21) rather than fabricated.
8. **Escalation dry run.** Not done, deferred alongside step 7.
9. **Iterate the briefing.** Done once already, from what step 6
   showed (see below); further iteration waits on steps 7 and 8.

### First real run

Fired early via `fire_trigger` against a real, purpose-written test
issue ([#9](https://github.com/jimbarritt/claude-plugins/issues/9):
document the Routine itself in `swe/README.md`, documentation only,
inside `swe/` so the run would genuinely exercise a version bump and
a release), rather than waiting for the schedule. Two firings:

- **First firing**, before the repository-access fixes above: ended
  idle without ever touching the issue. No `agent:working` label, no
  comment. Consistent with every GitHub call being denied at the
  first attempt.
- **Second firing**, after both fixes: worked end to end, single
  pass, no escalation. Claimed the issue with a comment naming the
  session. Dispatched the Opus Plan subagent, which read the existing
  README's structure and proposed a placement, a heading, and draft
  prose; wrote
  [`tasks/issue-9-document-routine-in-readme.md`](https://github.com/jimbarritt/claude-plugins/blob/planning/tasks/issue-9-document-routine-in-readme.md)
  on `planning` from that plan. Edited `swe/README.md`, bumped
  `swe`'s version `0.11.0` -> `0.11.1`, committed and pushed straight
  to `main` (confirmed: the commit landed on `main` itself, not on
  the auto-generated outcome branch the session's config also
  carried). Ran `release-plugin.yml`; it succeeded, tag `swe-v0.11.1`.
  Commented on the issue with the commit, the release tag, and a
  link to the task file; the commit's own `closes #9` trailer closed
  the issue. Updated `STATE.md`'s "Recently done". `check-unshipped.sh`
  confirmed clean afterward.

One gap found in this run, not a blocker: the `agent:working` label
was never removed once the issue closed. `MAINTAINER-RUN.md`'s Close
step now says to remove it either way; the stray label on issue #9
was cleared by hand once found.

Jim confirmed the push notification reached his phone and opened
straight to the Routine session in the iOS app. That was the whole
point of the notification channel, and it works from a real,
Routine-fired session, not only from an interactive one.

## Open questions

Escalation channel, cadence, the model split, the framework choice,
and the `software-english` scope are settled (see Decisions above).
The trusted-authors mechanism is proposed, not yet confirmed (see
"Decisions still forming"). Nothing else is open.
