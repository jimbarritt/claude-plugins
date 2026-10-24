# software-english#14: `no-abstract-stand-in-for-artefact` cannot fire outside a PR Description

[Issue #14](https://github.com/jimbarritt/software-english/issues/14), opened
by `jimbarritt-pleo` (a trusted collaborator). Closed by the commit below.
Also closed [#16](https://github.com/jimbarritt/software-english/issues/16)
as a side effect (see "Also resolved" below).

## The ask, verbatim

> `no-abstract-stand-in-for-artefact` carries `applies_to_document_type =
> "pr-description"`, so it never runs on a reference or design document. The
> same fault the rule describes occurs there, and passes both tiers clean.
>
> ### The shape that was missed
>
> A sentence that uses a figurative structural noun in place of a named data
> structure: "The adapter maps all four shapes to this record." "Shapes"
> stands for four vendor payload structures, and "this record" stands for the
> schema they are converted to. A reader cannot check the sentence against
> either. Rewritten with both named: "The adapter converts all four vendor
> payload structures to this schema."
>
> ### Proposed fix direction
>
> Drop `applies_to_document_type` from this rule, so it runs on every
> document type. Naming the artefact is correct everywhere, not only under
> review. Two details need widening with it: the artefact list (the rule
> lists file/field/record/request/response/message; a reference document
> also names a type, a field, a record or a schema), and the stand-in noun
> list (evidence/context/visibility/coverage/insight are review-vocabulary; a
> reference document reaches for structural metaphors: shape, form, flavour,
> surface). The current Summary/Problem/Change scope clause has no
> counterpart outside a PR Description, so it becomes a scope for that type
> only, with the whole document in scope elsewhere.

## Reading and plan

Plan from an Opus Plan subagent, which read the real rule entry, the sibling
`no-check-without-result` entry, `document-type-template`'s own summary
sentence, SPEC §7.15/§7.16/Appendix F, the four document-type templates, and
`COLOPHON.md`'s existing changelog-style entries, before proposing anything.

Key decisions the plan made, applied as proposed:

- **Conditional scope, not a unified rule of thumb.** The rule now fires on
  every document type; only its *scope* stays conditional (problem/change
  statement on a PR Description, whole document elsewhere) — the issue's own
  literal proposal, confirmed against all four templates (none but PR
  Description has anything like a problem/change-statement pair).
- **Widened artefact list**: added `type`, `schema` (from the issue), plus
  `table` (Reference), `endpoint` and `topic` (from `templates/api-design.md`).
- **Widened stand-in list, split by type**: PR Description keeps
  `evidence`/`context`/`visibility`/`coverage`/`insight`; Reference/Design
  gets `shape`/`form`/`flavour`. **Not** added: `surface`, which the issue's
  own list included — it is already on `vocabulary/banned.tsv`, so adding it
  here would double-report. One sentence in the new description says so
  instead.
- **New precedence clause against `no-metaphor-or-analogy` (§5.5)**: §5.5
  already covers `shape`/`layer`/`space` standing in for a *named* schema's
  fields. Without a precedence rule, "the adapter maps all four shapes to
  this record" (no artefact named at all) and §5.5's own example ("a version
  fixed now would name a shape the schema does not have", schema named)
  would risk a double report. Rule: if the sentence names the artefact and a
  form noun stands in for its fields, report under §5.5 only; if the
  sentence names no artefact at all, report under §7.15 only.
- **New literal-sense exception for `form`** (`an HTML form`), to guard
  against false positives from the widened list.
- **`no-check-without-result` gets no change.** Confirmed "essential" in
  #16's own essential/incidental terms: its fault needs a
  Verification/Not-verified section pair that only a PR Description has.

One correction made to the issue's own framing, in the closing comment
rather than silently absorbed: the claim "every document-type-scoped rule
names `pr-description`" was already false in v0.0.20 —
`no-planning-content-in-reference` is scoped to `reference`. Doesn't change
the fix; worth correcting so the (then-still-open) #16 audit started from
the right facts.

## Files changed

- `rules/core-rules.toml`: `no-abstract-stand-in-for-artefact`'s
  `applies_to_document_type` key removed and its `description` rewritten;
  `document-type-template`'s own description sentence naming "two rules"
  updated to name one (`no-check-without-result`) plus §7.15's new
  unconditional-with-conditional-scope status.
- `spec/SPEC.md`: §7.15 rewritten to match (new worked example using the
  issue's own fault/fix sentence, widened lists, fourth exception, §5.5
  precedence paragraph); Appendix F's PR Description paragraph updated.
- `templates/pull-request.md`: the "two rules... no other type" framing
  corrected to name only §7.16 as PR-Description-only; the commit-message
  exemption paragraph no longer names §7.15.
- `COLOPHON.md`: the PR Description section retitled ("...a type with one
  conditioned rule") and rewritten to state the new split and the §5.5
  precedence rule.

## Self-check catches (found only by running the real linter)

Two, both in the newly-drafted prose, neither anticipated by the plan:

- `COLOPHON.md`: "the sentence decides which rule reports it" tripped
  `anthropomorphism-fixed-list` (`sentence` is a structure noun, `decides`
  is on the fixed anthropomorphism list) — correctly caught, not a false
  positive. Reworded to state the two cases directly with no verb of
  deciding.
- `spec/SPEC.md`: "document, the common stand-ins are structural nouns"
  tripped `abstract-location` — a genuine false positive from hyphen
  tokenisation (`stand-ins` splits to the bare word `stand`, a listed
  location verb) landing within 4 words of `document`, a structure noun, on
  the same physical line after the paragraph was rewrapped. Reworded the
  second "stand-ins" to "substitutes" rather than restructuring the
  paragraph.

Both confirmed fixed by re-running `--diff --added-only`: 0 errors, 188
warnings (ordinary `vocabulary-membership` noise, same as every other prose
file in this repo).

## Verification

- `python3 -c "import tomllib; ..."`: catalogue parses, 30 unique rule ids,
  `no-abstract-stand-in-for-artefact` has no `applies_to_document_type` key,
  `no-check-without-result` still has `applies_to_document_type =
  "pr-description"`.
- `--diff --added-only` across all four changed files: 0 errors (188
  pre-existing-shaped `vocabulary-membership` warnings, same noise level as
  the rest of this repo's prose).
- `--force-inference` against a scratch Design-typed source containing the
  issue's own fault sentence: `no-abstract-stand-in-for-artefact` appears in
  the inference block (confirming the rule reaches the judging model
  regardless of document type — the `applies_to_document_type` TOML key was
  never read programmatically by `software_english_lint.py`; the gating is
  entirely in the rule's own prose, which is what this fix actually changes).
- Manual judgement pass against the rewritten description: the issue's own
  fault sentence reads as a §7.15 finding (no artefact named for either
  "shapes" or "this record"); its fix sentence does not; §5.5's own worked
  example ("a version fixed now would name a shape the schema does not
  have") reads as a §5.5 finding only, since the schema is named; "Line
  coverage of the parser rose from 71% to 84%." and "an HTML form" read as
  not-this-fault, per the stated exceptions.
- All six `claude-plugins/swe` test suites pass (176 assertions, unchanged),
  run against this fix fetched locally (`SWE_SRC`) both before and after the
  release, and again against the real fetched `v0.0.21` tag post-release.
- `scripts/check-unshipped.sh` clean before and after the `swe` pin bump.

## Outcome

Single pass, no escalation. Shipped on `software-english`'s `main` at
[`86fa220`](https://github.com/jimbarritt/software-english/commit/86fa220),
released as
[`v0.0.21`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.21),
which closed #14 automatically. Because the change touched
`rules/core-rules.toml`: `claude-plugins/swe/software-english.json`'s pin
bumped to that tag and `swe`'s own version bumped (`0.18.0` -> `0.18.1`) on
`main` at
[`c5204ae`](https://github.com/jimbarritt/claude-plugins/commit/c5204ae),
released as
[`swe-v0.18.1`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.18.1).

## Also resolved: software-english#16

[#16](https://github.com/jimbarritt/software-english/issues/16) asked for an
audit of every `pr-description`-scoped rule, deciding essential (stays
scoped) vs. incidental (loses the scope) for each. There were exactly two
such entries in v0.0.20: `no-abstract-stand-in-for-artefact` (incidental,
fixed above) and `no-check-without-result` (essential, confirmed unchanged
above). With both decided, nothing was left to audit, so #16 was closed with
a comment pointing back to this commit rather than treated as a second
piece of work. The issue's own "alternative" (a new `reference` document
type, to avoid narrowing the scoped rules one at a time) was not pursued:
once both entries were checked individually, the audit path was already the
smaller, sufficient change.
