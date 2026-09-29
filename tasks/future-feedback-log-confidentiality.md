# Future task: should the feedback log hold private information?

## Origin

Split from [claude-plugins#12](https://github.com/jimbarritt/claude-plugins/issues/12),
item 4. Items 1-3 of that issue (send-time redaction in
`send-feedback`, and showing the draft before filing) shipped as
`swe-v0.15.0`; see
[tasks/issue-12-send-feedback-redaction.md](issue-12-send-feedback-redaction.md).

## The ask, verbatim (item 4 of issue #12)

> Open question: should the log hold private information at all?
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

## Options, with the tradeoffs the issue gives

- **(A) Redact at send time only, as shipped today.** The log stays
  fully detailed. Cost: a plain-text file of confidential excerpts
  sits in the home directory, which may be backed up or synced to a
  machine the employer does not control. The archive makes this
  worse, since nothing is ever removed from it.
- **(B) Redact at capture time, in `/swe:feedback`.** The log never
  holds confidential text. Costs: the user reviews this same log
  later, and a redacted entry loses the detail that made the fault
  recognisable; and a judgement call moves into what is meant to be
  one quick append.
- **(C) Capture verbatim, and expire or scrub the archive** (and
  perhaps old live-log entries) on a schedule.

## Constraint already fixed by #12's implementation

Send-time redaction in `send-feedback` stays needed under every
option above, because existing logs and archives are already
verbatim, and the session drafting the issue can hold private
context that never passed through the log. So this task only decides
whether `/swe:feedback` and/or the archive step also change; it does
not undo anything shipped for #12.

## Status

Waiting for Jim's decision. Not started.
