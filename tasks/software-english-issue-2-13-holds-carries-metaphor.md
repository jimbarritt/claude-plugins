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

## Jim's decision

Given directly in the session that raised the escalation (not via a
GitHub comment, so this run resumed in the same session rather than
waiting for the next firing): "Holds is banned. It was somehow
incorrectly used as an alternative to carries, neither is acceptable
when dealing with inanimate subject like systems or abstract concepts.
A baby can hold a rattle. A human can hold a thought but an object
cannot hold anything — they do not have hands." Read as settling both
#2 and #13: `hold`/`holds`/`holding`/`held` is banned, flatly, the same
way `carry`/`carries` already is (no subject gate — this repo's prose
is about systems and abstract concepts, so a literal human-hands sense
essentially never occurs in it, the same reasoning that already
justifies `carry`/`carries`'s flat ban).

## Implementation

Plan from an Opus Plan subagent's read of the real files (`vocabulary/
banned.tsv`, `qualities.tsv`, `structure.tsv`, `operations.tsv`,
`rules/core-rules.toml`'s `no-metaphor-or-analogy` description,
`spec/SPEC.md` §5.5), reconciling #2's and #13's slightly different
proposed replacement wording and checking every candidate against the
real linter before proposing it (`take`/`set`, proposed in #13, were
dropped: `take` is not approved vocabulary, and `set` already means
"assign a value").

- `vocabulary/banned.tsv`: new "Possession metaphor" comment-group bans
  `hold`/`holds`/`holding`/`held` alongside `carry`/`carries`, and
  drops `hold`/`holds` from `carry`/`carries`' own replacement text
  (`have, contain, or include` / `has, contains, or includes`).
- `no-metaphor-or-analogy` (`rules/core-rules.toml` and `spec/SPEC.md`
  §5.5, kept in substance-sync): the rule's own worked "correct"
  example used `holds` as the literal verb proving a container-and-form
  noun was the actual fault, not the verb — now uses `contain`/`have`/
  `save` instead. A new fixed-list paragraph in SPEC.md documents the
  possession-verb entries, matching the existing transport-metaphor and
  motion-idiom paragraphs' pattern. No `core-rules.toml` version bump
  (precedent: three prior wording-only description changes didn't bump
  it either).
- `vocabulary/qualities.tsv` (`empty`, `full`, `stale`, `fresh`),
  `structure.tsv` (`cache`), `operations.tsv` (`contain`, `be`): seven
  definitions that used `hold`/`holds`/`holding` to define another
  word, rewritten to use `contain`/`have`. Issue #13 named four of
  these explicitly; the other three (`full`, `stale`, `be`) are the
  same files, same pattern, fixed for consistency rather than leaving
  half a file self-contradicting the new ban.
- SPEC.md Appendix F's Operations row dropped `hold` from its example
  list (it was never actually an `operations.tsv` entry).

Left alone deliberately, not an oversight: ten uses of `holds`/
`holding` in SPEC.md's own general descriptive prose elsewhere (not a
vocabulary definition, not a rule's worked example), and every use in
`README.md`, `templates/`, `COLOPHON.md`, and the one ADR. This repo's
prose has never been held to a zero-finding bar against itself
(SPEC.md already carried ~14 unrelated pre-existing findings before
this change). Rewriting these ten is a one-word fix each (documented in
the plan, in case a future issue asks for a self-consistency sweep),
but is out of scope for #2/#13's own ask.

One adjacent consequence, also not fixed here: `claude-plugins/swe`'s
own docs (`SKILL.md`s, `README.md`, `docs/agent-guide.md`,
`docs/output-taxonomy.md`) have roughly 22 uses of `hold`/`holds`/
`holding` that now trip `banned-word` once linted under the new pin.
Not touched this run, since this run's own diff didn't touch those
files; flagged on the issue and here in case it becomes its own task.

## Validation

Built the same fixture pattern `swe/tests/motion_idiom_test.sh` uses
(a temp copy of `swe/scripts` with `data/` populated from the local
`software-english` checkout) and ran the real linter directly, not
just reasoned about it:

- The issue's own flagged sentence, `` `_items` holds the items inline
  ``, now fires `[banned-word] "holds" -> has, contains, or includes`.
  `` `_items` includes the items inline `` stays clean. `held`/
  `holding`/plain `hold` sentences fire too; `threshold`, `placeholder`
  and `household` stay clean (word-boundary match, not a substring
  match).
- Every new/rewritten vocabulary-file line and every new/rewritten
  SPEC.md line is itself clean against the real linter (one exception
  caught and fixed before committing: the first draft of the new
  SPEC.md possession-verb paragraph ran to 25 words in one sentence,
  over the 20-word sentence-length limit — split into two sentences).
- Diffed `spec/SPEC.md`'s full finding count before/after, line by
  line: 14 baseline findings (confirmed pre-existing, unrelated to this
  change) to 24 after, exactly the ten deliberately-left-alone
  `hold`/`holds` lines — no unexpected new finding anywhere else in the
  file.
- All six `claude-plugins/swe` test suites pass (142 assertions,
  unchanged), run both before the software-english release (against a
  local-checkout fixture) and after (against a real fetch of the new
  `v0.0.12` tag, confirming the deployed plugin data actually carries
  the fix).
- `scripts/check-unshipped.sh` clean before and after the `swe` version
  bump.

## Outcome

Shipped on `software-english`'s `main` at
[`321718e`](https://github.com/jimbarritt/software-english/commit/321718e),
released as
[`v0.0.12`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.12),
closing #2 and #13 together (`Fixes #2` / `Fixes #13` trailers, both
auto-closed). `claude-plugins` pin bumped and `swe` version bumped
(`0.17.1` -> `0.17.2`) on `main` at
[`b4af78a`](https://github.com/jimbarritt/claude-plugins/commit/b4af78a),
released as
[`swe-v0.17.2`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.17.2).
`agent:working` removed from both issues on close. Single pass once
Jim's decision came back — no second escalation round needed.
