# Plan: software-english#29

## The ask, verbatim

> Anthropomorphism list: add the third-person form of "ask"
>
> The anthropomorphism word list catches `tells`, `says` and `wants` where the
> subject is a document or a system. The verb *ask*, in its third-person
> present form, is not in the list.
>
> The example below substitutes `tells` so that this text passes the linter:
>
> > Every ingredient the recipe tells the cook about, in the order the recipe
> > tells it.
>
> Put the third-person form of *ask* in place of `tells` and nothing fires,
> though the fault is the same: a recipe makes no request. On an earlier run,
> `tells` was flagged in that position in a real document, so the gap is in
> the word list rather than in the judgement.
>
> Fix: add the third-person form of *ask* to the list, under the same subject
> test the neighbouring verbs use.

https://github.com/jimbarritt/software-english/issues/29

## Reading

The premise does not hold against the current `main`. `asks` is already in
`anthropomorphism-fixed-list`'s `word_list`, in `rules/core-rules.toml`, added
by commit `0935b1a9f1814de9598230207d7377e7595ab94d` (2026-10-23,
"anthropomorphism-fixed-list: add motion and communication verbs, gate on a
human referent (SPEC §5.1)", `closes #20`), under the same `not-human-subject`
check `tells`, `says` and `answers` use.

Verified directly, against the real pinned data (swe plugin, v0.0.33):

- `Every ingredient the recipe asks the cook about, in the order the recipe
  asks it.` fires `[anthropomorphism] "asks"` twice.
- `The recipe does not ask the cook to preheat.` fires `"ask"` (do-support
  base form, software-english#26).
- `The user asks the recipe.` fires nothing (human referent).

`swe/tests/anthropomorphism_gate_test.sh` in `claude-plugins` already asserts
this case: `fires: the worker asks the database`. A full run of that suite,
against the real `software-english` checkout, passes 59/59, 0 failed.

One related gap, outside this issue's scope: a plural non-human subject with
the bare verb (`The recipes ask the cook…`) fires nothing, because
`word_list` holds no base-form `ask`, `tell`, `answer` or `say` (it does hold
base/plural forms for the motion verbs: `arrive`, `come`, `enter`, `leave`,
`move`, and for `disagree`). The issue asks only for the third-person present
form, which already fires, so this plan does not change it. Mentioned to Jim
as an observation on the issue, not filed as a new issue.

## Decision

No code or rule-data change. This run:

1. Confirms the fix with the test suite (done: 59 passed, 0 failed).
2. Comments on the issue stating what was checked, which commit already
   shipped the fix, and which test already covers it.
3. Closes the issue, `state_reason: completed`.
4. Removes `agent:working`.
5. Records the mission as a verified-duplicate / already-fixed resolution:
   no commit, no release, no version bump.

No open question in the issue to answer with `tsk decision add`. No task list
beyond the verification already run.
