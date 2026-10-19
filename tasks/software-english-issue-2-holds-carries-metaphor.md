# software-english#2: "holds" prescribed as the fix for "carries", but is the same metaphor

[Issue #2](https://github.com/jimbarritt/software-english/issues/2), filed by
`jimbarritt-pleo`.

## The ask, verbatim

> ## Verdict
>
> `false-positive` on `banned-word` (logged via `/swe:feedback`, 2026-09-21).
>
> ## The finding
>
> ```
> [banned-word] carries -> holds, contains, or includes
> ```
>
> Flagged sentence: `` `_items` holds the items inline. ``
>
> ## The problem
>
> The finding itself is right to fire on "carries". Its prescribed
> replacement is not. "Holds" and "carries" are the same physical
> metaphor: both describe a data structure as a container acting on its
> contents. Swapping one for the other removes the flagged token and
> keeps the fault, and the vocabulary table therefore steers writing
> toward the metaphor rather than away from it.
>
> The effect compounds, because the suggestion is taken: a writer
> following the linter ends up with "holds" throughout, and no rule
> fires on the result.
>
> ## Proposed fix direction
>
> - Ban "holds" alongside "carries".
> - Drop "holds" from the suggested replacements for "carries".
> - Leave the acceptable set as "has", "contains", "includes" and "is a".
>
> For the flagged sentence, "includes" reads best: `` `_items` includes
> the items inline. ``
>
> The reporter notes this needs refining upstream in the spec, not only
> in the vocabulary table.

A near-identical, more detailed ask is open as
[issue #13](https://github.com/jimbarritt/software-english/issues/13)
(same reporter, 2026-10-16), which additionally asks to add
`hold`/`holds`/`holding` to `banned.tsv` in their own right and to rewrite
three vocabulary-file definitions that use "hold" (`qualities.tsv`
`empty`/`fresh`, `structure.tsv` `cache`, `operations.tsv` `contain`).
Not claimed this run (one issue per run); the same blocker below applies
to it too.

## What was tried

Read the issue, then read the actual rule and spec text this fix would
touch before writing anything, per the repo's own pattern of verifying
against the real files rather than reasoning from the issue text alone.

Found a direct conflict between the issue's premise and the existing,
deliberate spec design:

- `spec/SPEC.md` §5.5 ("No metaphor or analogy") gives its own worked
  example of the *correct*, literal way to state a fact instead of a
  metaphor:

  > State the mechanism instead:
  > The retry queue holds a failed request for a later attempt.
  > The cache holds a copy of data for a later request.

  `git log -S "The retry queue holds a failed request"` shows this
  example was written by Jim in `d406426` ("Many feedbacks from initial
  trials"), the repo's own early design pass — well before issue #2 was
  filed, and not touched by any later automated change.

- `vocabulary/operations.tsv`'s header row classifies `hold` as a
  concrete domain operation, in the same list as `read, write, create,
  delete, return, reject, run, call, send, receive` (SPEC.md line 358).

- `tasks/software-english-issue-1-container-and-form-metaphor.md`, the
  task file for the issue worked immediately before this one in the same
  run cycle (also touching `no-metaphor-or-analogy`), states explicitly:
  "`hold` itself is approved vocabulary (SPEC §6, Operations) and is
  used correctly throughout, including in this rule's own existing fix
  text ('The retry queue holds a failed request')" — and lists #2/#13 as
  "the unrelated hold/carry banned-word pairing, not touched here"
  rather than resolving them in passing, despite having the same
  evidence in hand.

So implementing issue #2 as asked (ban `holds`, or go further per #13
and ban `hold`/`holds`/`holding` outright) means rewriting a worked
example Jim wrote himself to define what "correct" looks like under this
rule, and reclassifying `hold` against its current, deliberate treatment
in `vocabulary/operations.tsv`. The issue's own flagged sentence,
`` `_items` holds the items inline ``, is the same shape as the spec's
own canonical "correct" example (a structure, holding its contents) —
if the canonical example stands, the flagged sentence is not a fault at
all, and the deterministic-tier suggestion it complains about was
already correct.

This is not a question of refining wording or testing one candidate
phrase against the linter (the usual unattended judgement call this
Routine makes): it is a direct contradiction between a trusted
collaborator's bug report and Jim's own original design decision,
embedded in the rule's own teaching example. Two readings of what
"correct" looks like here lead to materially different work — rewrite
the canonical example and reclassify `hold`, or close both issues as not
a fault — so this is the Ground rules' escalation case, not a call to
make alone.

## What is blocked

Whether `hold`/`holds` is the kind of anthropomorphic container metaphor
`carry`/`carries` is (issue #2's and #13's premise), or the approved,
literal domain verb the spec's own `no-metaphor-or-analogy` example and
`vocabulary/operations.tsv` already treat it as (the existing design).

## The one question

Is `hold`/`holds` a metaphor to ban alongside `carry`/`carries` (which
means rewriting §5.5's own worked example and `vocabulary/operations.tsv`'s
classification of `hold`), or is the existing treatment of `hold` as
approved, literal vocabulary correct, and #2 and #13 should close as not
a fault?

## Outcome

Escalated, no code change. `agent:working` swapped for `supervisor` on
issue #2. Issue #13 left untouched (same blocker, not separately
claimed this run).
