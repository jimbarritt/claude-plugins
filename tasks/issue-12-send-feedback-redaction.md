# Issue #12: send-feedback redaction

[Issue #12](https://github.com/jimbarritt/claude-plugins/issues/12),
opened by `jimbarritt-pleo` (trusted collaborator).

## The ask, verbatim

> `send-feedback` drafts a GitHub issue from a feedback entry's `quote`
> and `note` fields. Those fields are written by `/swe:feedback` while
> the user works on whatever they happen to be working on, which is
> often private code. They routinely contain employer and project
> names, service and repository names, ticket ids, internal PR
> numbers, and verbatim excerpts from internal documents. All of that
> is fine in the log, which is local. The issue is public.
>
> The skill never says this. An agent following Step 4 as written
> copies the entry's own detail into the issue body, which is exactly
> the wrong default.
>
> Observed directly: a first issue was drafted quoting an internal
> design document verbatim, including a ticket id, and the user
> stopped it before submission.
>
> ### 1. State the redaction rule
>
> Never pass an internal reference into an issue: no employer or
> project names, no service, domain or repository names, no ticket
> ids, no internal PR or issue numbers, no verbatim excerpts from
> internal documents.
>
> Describe the shape of the fault abstractly instead, preserving only
> what a maintainer needs to reproduce or judge it. Where an example
> sentence is needed, rewrite it with neutral subjects rather than
> quoting the original.
>
> ### 2. Show the draft before submitting
>
> Step 3 already asks whether to file, but it asks before the body
> exists, so the user approves the item rather than the text that
> will be published. Show the redacted title and body, and wait,
> before calling `gh issue create`.
>
> ### 3. State the reason, not only the rule
>
> The tracker is public and the log is not. A rule without its reason
> gets paraphrased away; a reason survives.
>
> ### 4. Open question: should the log hold private information at
> all?
>
> The three changes above put redaction at send time, and keep
> `~/.claude/swe/feedback.jsonl` verbatim. That is one answer, not the
> obvious one.
>
> Redacting at capture time, in `/swe:feedback`, would mean the file
> never holds confidential material. The cost: the log is also what
> the user reviews later, and a redacted entry loses the detail that
> made the fault recognisable. It also moves a judgement call to the
> moment of logging, which is meant to be a single quick append.
>
> Redacting at send time keeps full fidelity, at the cost of a
> plain-text file of confidential excerpts sitting in a home
> directory that may be backed up or synced to a machine the
> employer does not control. The archive compounds this: nothing is
> ever removed from it.
>
> A third option: capture verbatim, and expire or scrub the archive on
> a schedule.
>
> Decide this before implementing 1-3, because the answer determines
> whether redaction belongs in `send-feedback`, in `/swe:feedback`, or
> in both.

## Reading and plan (from an Opus Plan subagent, read against the real code)

Current flow:

- `/swe:feedback` (`swe/skills/feedback/SKILL.md`) appends one JSON
  line to `~/.claude/swe/feedback.jsonl`, `quote` and `note` verbatim,
  no redaction.
- `send-feedback` (`swe/skills/send-feedback/SKILL.md`):
  - Step 3 asks whether to file, before any issue text exists.
  - Step 4.2 says to draft the issue "from the item's own detail
    (... the representative quotes or note ...)" - the fault.
  - Step 4.4 runs `gh issue create` straight away, no preview.
  - Step 4.5 archives the item's log lines unchanged, forever.

Verdict: implement items 1-3 now, in `send-feedback` only. Defer
question 4 to a new task file. This is not the escalation case ("two
readings lead to materially different work"): every reading of
question 4 still needs items 1-3, because:

1. Logs and archives that already exist on a user's machine hold
   verbatim entries; a capture-time change does nothing for those.
2. Capture-time redaction is a quick judgement made while logging; it
   will miss things, so the public boundary needs its own check
   regardless.
3. The agent drafting the issue runs inside whatever project session
   the user has open, and can pull in private context that never
   passed through the log at all.

So "redact in `/swe:feedback` only" is not a real answer to question
4 that would make items 1-3 unnecessary; the real choice is between
"send-feedback only" and "both". Item 2 (show draft, wait) is useful
under any answer.

The issue explicitly asks to decide question 4 first. This was not
followed; the closing comment on the issue says so plainly, so Jim can
reopen if he disagrees with proceeding this way.

## What shipped

See commit and release reference below, added once pushed.

## Outcome

<!-- filled in at Record step -->
