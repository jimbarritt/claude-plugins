# software-english#17: a definite reference that presupposes an unstated fact

[Issue #17](https://github.com/jimbarritt/software-english/issues/17), opened
by `jimbarritt-pleo` (a trusted collaborator).

## The ask, verbatim

> A definite noun phrase presupposes a fact the document has never stated.
> Two markers identify it: a cardinal inside the phrase, where no earlier
> sentence establishes that count; and a participial modifier naming a
> completed act (`surveyed`, `rejected`, `agreed`, `measured`), where no
> earlier sentence records that act being performed.
>
> Example: "The four surveyed carriers all reject a weekend dispatch slot."
> A reader cannot resolve which four, or who surveyed them, or when.
>
> `no-unanchored-reference` (SPEC §7.5) is the nearest sibling but doesn't
> reach it: that rule anchors on abstract singulars with no antecedent noun
> ("the design", "the plan"), while here the referent is a concrete plural
> and what's missing is a prior assertion, not a prior noun.
>
> Proposed: a new standalone rule, inference-based (it cannot be
> deterministic, since "the four tables" is correct once the document has
> listed four tables).

A second issue, #18 ("possession and entitlement require an animate
possessor"), was filed six minutes later by the same author. Out of scope
for this run (one issue per run) — left for a future run to claim.

## Reading

`no-unanchored-reference` only catches an abstract singular standing with no
antecedent noun. The gap here is different in kind: the noun is concrete and
nameable (a reader knows what a "carrier" is), but the sentence presupposes
an unstated act or count. No existing rule in the catalogue (checked
`no-unanchored-reference` §7.5, `no-abstract-stand-in-for-artefact` §7.15,
`vacuous-classification-property` §7.6, `no-process-narration` §7.7,
`define-before-use` §7.4) names this.

## Plan

An Opus Plan subagent read `COLOPHON.md`, `spec/SPEC.md`, and
`rules/core-rules.toml` in full before proposing anything. It also read the
linter source to confirm the deterministic tier is hardcoded per rule id
(no generic pattern dispatcher), so a new inference-based rule needs no
`claude-plugins` code change.

Proposed and implemented as planned, with two implementation-time wording
fixes (below):

- New rule `no-unstated-presupposition`, `tier = "inference-based"`,
  `check = "model-judgement"`, `severity = "warning"`, unscoped (fires on
  every document type, like its sibling §7.5 — neither rule is
  document-type-conditioned). Appended to `rules/core-rules.toml` after
  `no-question-or-argument-heading` (§7.18), before `[exemptions]`.
- New SPEC.md §7.19 "No unstated presupposition (Inference-based)", appended
  after §7.18 and before "## 8. Register rules" — the same placement
  precedent §7.14's own COLOPHON entry gives: a rule inserted beside §7.5
  would renumber every rule the catalogue and the Contents list cite by
  number. Contents list updated to match.
- Two "Distinct from" cross-references added, both directions, so the two
  rules don't double-fire on the same phrase:
  - §7.19's own description/SPEC text names §7.5 (abstract singular, no
    antecedent noun, vs. a concrete/plural noun with an unstated fact),
    §7.15 (abstract head noun naming none of the counted items vs. a
    concrete head noun), §7.6 (a count signpost vs. an unsupported count),
    and §7.7 (process narration vs. stating the fact itself).
  - §7.5 itself gained a reciprocal paragraph, and its own TOML description
    gained a matching clause — the plan's one judgement call taken rather
    than left one-sided: §7.5's own "and similar" wording could otherwise
    let the judging model claim `the agreed plan` under §7.5 too.
- Explicit non-triggers stated: a phrase pointing to where the fact is
  stated (`the four carriers listed in §3`); a cardinal whose items the same
  sentence names; a cardinal that's part of a name or literal token
  (`two-phase commit`, `the 404 response`); a quantity, not a referent count
  (`the 30-second timeout`); a participle naming a state/kind rather than a
  completed act (`the closed connection`), or a declared status value
  (§5.8); an act a document type itself records (`the changed files` in a
  PR Description — the plan's own addition, not in the issue); quoted
  material or a literal token.
- Fault/Fix wording: kept the issue's own Fault sentence verbatim ("The four
  surveyed carriers all reject a weekend dispatch slot."). Changed the Fix
  from the issue's passive draft to active voice with a dated actor ("The
  dispatch team surveyed four carriers in March 2026: A, B, C, and D. None
  accepts a weekend dispatch slot.") — matches §4.2's "name the actor" rule,
  states the "who" and "when" the fault sentence withholds, and avoids
  opening with a number word before a colon-led list (the §7.6 count-signpost
  shape).
- No COLOPHON entry: recent single-rule additions (#14 abstract-stand-in,
  #15 framing-devices) didn't get one either; this one rule is a plain
  sibling addition, not a new rule family.

## Self-check catches (found only by running the real linter)

Two instances of "is missing" — in "the fact the phrase depends on is
missing" (×2, in the new §7.19 prose) — tripped the deterministic
`no-continuous-tense` rule: `is` + `-ing` word reads mechanically as
continuous tense even though "missing" is adjectival here, not a verb.
Reworded both to "A reader can tell what kind of thing the noun names, but
not the fact the phrase depends on" and "the document never states the fact
it depends on".

## Verification

- `tomllib` parse: 32 rules, all ids unique (31 before, +1).
- `software_english_lint.py --diff --added-only --quiet-vocab`: 0 errors on
  every added line in `spec/SPEC.md`, both before and after the
  `no-continuous-tense` fix (2 errors → 0).
- Both changed TOML descriptions (`no-unstated-presupposition`,
  `no-unanchored-reference`) piped through `--text`: 0 `[error]` lines, only
  pre-existing-pattern `sentence-length` warnings (every dense TOML
  description in this catalogue warns the same way).
- `--force-inference spec/SPEC.md`: the new rule prints in the
  `INFERENCE_ADVISED` block (24 pending rules, up from 23); deterministic
  tier unchanged at 20 pre-existing errors.
- Manual judgement pass: the issue's own Fault sentence fires under §7.19
  (concrete plural, unstated count + act) and not under §7.5 (which needs an
  abstract singular); the Fix sentence fires under neither; `the four
  tables` after a document that lists four tables doesn't fire; none of the
  stated non-trigger examples fire.
- All seven `claude-plugins/swe` test suites pass (176 assertions,
  unchanged), run with `SWE_SRC=/home/user/software-english` against this
  local checkout.
- No `claude-plugins` code or data change — `swe/data/` was populated
  locally only to run the linter for verification, then emptied again
  before shipping.

## Judgement calls made without a supervisor (unattended run)

1. Rule id `no-unstated-presupposition` over the plainer
   `no-reference-to-unstated-fact` (shorter, matches the "no-<adjective>-
   <noun>" shape of its sibling `no-unanchored-reference`).
2. Added the reciprocal §7.5 cross-reference (both the TOML description and
   the SPEC prose), rather than leaving the overlap one-sided as some past
   issues did.
3. Changed the issue's own Fix sentence from passive to active voice with an
   added actor and date.
4. Added a "document type itself records" non-trigger (`the changed files`
   in a PR Description) — the plan's own addition, not asked for by the
   issue.
5. Scoped it to fire on headings too, mirroring §7.5's own heading scope,
   since the issue's own example could equally appear as a heading.
6. Skipped a COLOPHON.md entry, on the "single sibling rule, not a new rule
   family" reading of recent precedent.

None of these looked likely to need the maintainer's input; if Jim disagrees
with any, it's a one-line SPEC/TOML wording change, not a design reversal.

## Outcome

Shipped on `software-english`'s `main` at
[`3b4bb30`](https://github.com/jimbarritt/software-english/commit/3b4bb30db69301dbc2b9dbc15d46e5516b619320),
released as
[v0.0.23](https://github.com/jimbarritt/software-english/releases/tag/v0.0.23),
which closed the issue automatically. `claude-plugins` pin bumped and `swe`
version bumped (`0.18.2` -> `0.18.3`) on `main` at
[`f4d8268`](https://github.com/jimbarritt/claude-plugins/commit/f4d8268ef4ff3165718a92a5cefa617b562d7cdd),
released as
[swe-v0.18.3](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.18.3).
`agent:working` label removed. Single pass, no escalation.
