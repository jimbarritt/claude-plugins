# software-english#1: no-metaphor-or-analogy misses the container-and-form family

[Issue #1](https://github.com/jimbarritt/software-english/issues/1), filed by
`jimbarritt-pleo`.

## The ask, verbatim

> Verdict: false-negative, reported via `/swe:feedback`.
>
> ## The text that passed
>
> > The schema holds no version field. Receipts have no field either, so a
> > version fixed now would name a shape the schema does not hold.
>
> Two metaphors here. A version does not `name a shape`, and a schema does
> not `hold` a shape. Both are the container-and-form family (`shape`,
> `surface`, `layer`, `space`) applied to a schema, a type or an API.
>
> ## Why it is worth a rule change
>
> The sentence passed the inference tier three times on the same file,
> including a separate agent judging it fresh with the full rule catalogue
> in context. This is a sensitivity gap in the rule description, not one
> model run.
>
> ## Proposed direction
>
> `no-metaphor-or-analogy` is prompt-driven judgement with no word list, and
> its description carries one example (`the retry queue is the system
> safety net`), which is a vivid, self-announcing metaphor. A dead metaphor
> applied to a technical noun does not resemble it. Adding two or three
> worked examples of the container-and-form family to the rule description
> should raise the hit rate without adding a word list, since `shape` has
> legitimate uses the tier still needs to judge.
>
> Note: `auto-fix-candidate` applies to this issue, but the reporting
> account holds read access only and could not create or apply the label.

## Reading

Documentation/example-quality fix only. The rule's own prompt text lives in
two places that must stay in substance-sync:

- `rules/core-rules.toml` — `no-metaphor-or-analogy` rule's `description`
  field (the inference-tier model prompt).
- `spec/SPEC.md` §5.5 — the human-readable spec prose for the same rule.

No change to `vocabulary/banned.tsv`: `shape`, `layer` and `space` each have
legitimate literal technical uses in this repo's own templates and ADRs
("the error shape as a `type`", "two layers", "disk space"), so they cannot
be flat-banned without false-positiving on the repo's own prose. `surface`
(noun, "the API surface") is already on the fixed list via the existing
`surface`/`surfaces` banned.tsv entry, so it needs no new inference example,
only a one-clause note that it's already caught.

`hold` itself is approved vocabulary (SPEC §6, Operations) and is used
correctly throughout, including in this rule's own existing fix text ("The
retry queue holds a failed request"). The fault in the issue's sentence is
the form noun `shape` standing in for the fields a schema defines, not the
verb `hold` — the new text must say so explicitly, or the tier risks
flagging approved `hold` uses.

## Plan (from an Opus Plan subagent's read of the real files)

**`rules/core-rules.toml`**, insert into the `no-metaphor-or-analogy`
description, after the existing "...so only judgement can tell the two
apart." sentence and before the closing "A metaphor or an analogy not on
the fixed list needs judgement to recognise, so this stays inference-based.":

> Also watch for a container-and-form noun (shape, layer, space) applied to
> a schema, a type, an API, or a contract in place of the fields, values, or
> operations it defines: 'a version fixed now would name a shape the schema
> does not hold' (would refer to fields the schema does not contain), 'the
> contract is a thin layer over the table' (the contract has the same
> fields as the table), 'the type leaves no space for a null' (the type
> does not accept a null). The noun 'surface' ('the API surface') is on the
> fixed list and is caught by banned-word. Each of these nouns also has a
> literal use: 'the schema holds a version field' (a schema holding a field
> is literal; the fault is the form noun, not the verb hold), 'the error
> shape as a type' where the type then lists the fields, 'the network
> layer', 'disk space', so only judgement can tell the two apart.

**`spec/SPEC.md`** §5.5, new paragraph after the existing "Inference-based
tier: ..." paragraph (ends "...`the service runs behind the proxy`."),
before `### 5.6`:

> The inference-based tier also includes a container-and-form noun
> (`shape`, `layer`, `space`) applied to a schema, a type, an API, or a
> contract in place of the fields, values, or operations it defines: `a
> version fixed now would name a shape the schema does not hold` (would
> refer to fields the schema does not contain), `the contract is a thin
> layer over the table` (has the same fields as the table), `the type
> leaves no space for a null` (does not accept a null). The noun `surface`
> (`the API surface`) is on the fixed list with the verb, so banned-word
> catches it. These nouns are not on a fixed list, because each also has a
> literal use: `the schema holds a version field`, `the error shape as a
> type` where the type lists the fields, `the network layer`, `disk space`.
> A schema that holds a field is literal; the fault is the form noun
> standing in for the fields, not the verb `hold`.

All examples stay in backticks/single quotes so they are exempt from the
repo's own vocabulary check (SPEC §6.2/6.3) when linted against itself.

**Decisions made without a supervisor to ask** (unattended run, one issue
open per Ground rules, no other route to a decision):

- No blockquote fault/fix pair added to SPEC.md for this sub-case — the
  existing motion-verb sub-case in the same tier paragraph only uses inline
  parenthetical fixes, not a blockquote, so the new sub-case matches that
  precedent rather than the section's headline blockquote style.
- `layer` example chosen as "thin layer over the table" (figurative), not
  "the domain layer" (a real, legitimate architecture term) — keeps the
  literal/figurative split clean.
- Fix text for the issue's own motivating sentence: "would refer to fields
  the schema does not contain" — drops both flagged words (`name`, `shape`)
  and uses approved vocabulary (`contain`, `field`).
- No test file changes: `software-english` has no test harness, and
  `claude-plugins/swe/tests` has no per-rule-description assertions.
- No `core-rules.toml` `version` field bump — precedent commits `7b18340`
  and `8078f05` did not bump it for a wording-only rule-description change.

**Follow-up, not part of this fix:** the `claude-plugins` `swe` plugin
fetches this spec at a pinned tag, so the fix reaches it only once this
issue's own release step (release.yml) cuts a new `software-english` tag,
and — because this change touches `rules/core-rules.toml` — a `swe` pin
bump and release, per `MAINTAINER-RUN.md` step 7.

## Outcome

Pending — recorded before starting Step 5 (Work).
