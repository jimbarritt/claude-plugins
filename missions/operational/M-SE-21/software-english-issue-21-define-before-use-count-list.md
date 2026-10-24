# software-english#21: three mechanical candidates missed in one opening sentence

[Issue #21](https://github.com/jimbarritt/software-english/issues/21), opened
by `jimbarritt-pleo`.

## The ask, verbatim

> Rules: define-before-use (SPEC §7.4), no-abstract-stand-in-for-artefact (SPEC §7.15)
> Verdict: false negative
>
> A document's opening sentence had the shape:
>
>   "The router sends an order in one of two modes: on the primary queue, with a
>   priority flag, or on a queue of its own."
>
> It was recorded clean. It has three faults that a lookup can find.
>
> 1. Undefined coined term. "mode" is not a term of the domain, has no
>    definition clause anywhere in the document, and occurs more than ten times
>    across several related documents, including in headings. The documents
>    already define both modes as "option 1" and "option 2".
>    Candidate: a noun that occurs three or more times in a document, is never
>    followed by a definition clause, and is not in the approved vocabulary,
>    flagged at its first occurrence, headings included.
>
> 2. Count that does not match its own list. "one of two" is followed by a
>    colon list of three items in the same sentence.
>    Check: a number word followed by a colon list or an and/or list in the
>    same sentence, where the item count differs. This is an error, not a
>    warning.
>
> 3. Structural stand-in. "mode" stands in for the difference between two
>    payloads. no-abstract-stand-in-for-artefact lists shape, form and flavour;
>    add placement, arrangement, positioning and layout.
>
> A fourth gap has no rule: the paragraph opened on the mechanism, not on the
> outcome a reader of the document needs, and the document never stated its
> subject. Consider a rule that requires the first paragraph of a Reference
> document to state its subject in terms a reader outside the team uses.

## Our reading

The issue bundles three concrete, independently actionable asks plus one
speculative "consider" note that is not a firm ask. `define-before-use`
(SPEC §7.4) turned out to have no catalogue entry at all — the real root
cause of fault 1, not a detector gap. The count/list check's own worked
example is itself ambiguous between a 2-item and a 3-item reading, which
rules out the issue's literal "fully deterministic blocking error" proposal;
corpus-testing a naive deterministic version produced 7 false positives out
of 15 matches. The word-list addition needed a collision check against the
existing catalogue and vocabulary before accepting it verbatim.

## The plan (from an Opus Plan subagent, which read SPEC §7.4/§7.15/§2, the
real `core-rules.toml`, `vocabulary/`, the #18/#19 located-candidate
precedent in `software_english_lint.py`, and their task files/tests, and
corpus-tested every proposed detector against both repos' 33 real `.md`
files before proposing it)

### Part A — `software-english`

- **A1.** Expand SPEC §7.4 "Define before use": what counts as a
  definition, headings in scope, the issue's own fault/fix, a "Test" line,
  "Not this fault" exceptions (a domain term, a vocabulary word, a literal
  token, quoted material), "Distinct from" §7.13/§7.15/§7.19, and the
  inference-tier justification sentence.
- **A2.** New catalogue entry `define-before-use` (inference-based,
  `model-judgement`, `warning`), placed directly before
  `no-unanchored-reference`.
- **A3.** New SPEC §7.20 "No count that differs from its list"
  (Inference-based), appended after §7.19 (no renumbering, per the #17
  precedent): both readings of the issue's own example as the Fault, a
  fact-preserving Fix, a Test, "Not this fault" exceptions (a quantity, an
  explanatory colon, a part of a larger set matching its part, quoted
  material/literal tokens), "Distinct from" §7.6 (a mismatch vs. vacuous
  match) and §7.19, and the severity/tier justification: error severity
  because a mismatch states a wrong fact; inference-based because splitting
  the list on a comma that may be a separator or a modifier-setoff needs
  judgement, not a regular grammar.
- **A4.** New catalogue entry `no-count-list-mismatch` (inference-based,
  `model-judgement`, **error** — the first inference-based rule at error
  severity; SPEC §2 already separates tier from severity, so no §2 edit
  needed). Reciprocal clauses added to §7.6/`vacuous-classification-property`
  and §7.19/`no-unstated-presupposition`.
- **A5.** SPEC §7.15 + its TOML description: word list gains `placement`,
  `arrangement`, `positioning`, `layout` (not `mode` itself — it has
  correct uses as file mode/strict mode/CLI mode and is used only as the
  worked example instead); new Fault/Fix pair from the issue; literal-sense
  exception widened to cover `layout`'s own correct uses already in this
  repo (§8.3, COLOPHON.md:189, CONTRIBUTING.md's "Repository layout"
  heading) so the rule's own text does not trip on them.
- **A6.** COLOPHON.md: one new section recording why the deterministic
  count/list design was rejected (comma ambiguity, corpus numbers) and why
  severity is error.
- **A7.** Verification: `tomllib` 35 unique ids (up from 33);
  `--diff --added-only` zero errors on every added line; `--force-inference`
  shows both new rules, `no-count-list-mismatch`'s line ending
  "(severity on violation: error)".

Release: `software-english` `v0.0.27` (`release.yml`, input `0.0.27`, not
`v0.0.27` — the #20 catch).

### Part B — `claude-plugins` (`swe/scripts/software_english_lint.py`)

Same located-candidate pattern as #18/#19: deterministic Python finds a
*site*, never decides the fault, never enters `findings`, never affects
`error_total`/`--count`/exit code, capped per rule per source, printed only
inside `===INFERENCE_ADVISED===`.

- **B1.** Constants: `DEFINE_MIN_OCCURRENCES = 3`, a noun-gate set reusing
  existing determiner/cardinal sets minus `both`, `COUNT_WORDS` (number
  words `two`..`twelve` only — no numerals, no `one`, no `both`, all three
  corpus-measured false-positive sources), `COUNT_COLON_LIST` regex.
- **B2.** `term_is_defined(forms, text)`: bold span, `means`/`refers
  to`/`is defined as`/`stands for`/`denotes`, `called`/`named`/`termed`/
  `known as`, `a/an X is a/an/the/any/one`, a parenthetical gloss, a
  glossary bullet/table row.
- **B3.** `find_undefined_terms(...)`: one forward pass, heading words
  counted title-case-safe, lemma-grouped (keyed on first-seen surface form,
  not shortest candidate — the shortest-candidate key was tried and
  rejected: it mapped "modes" to "mod" and split it from "mode"), gated on
  count≥3, heading occurrence, noun-gate, and `not term_is_defined`. Sorted
  by first line so an opening-sentence term is always inside the 20-cap.
  Tuning: literal 3+/not-vocabulary alone gives 1231 candidates across both
  repos' 33 files; adding the noun-gate and definition-clause exclusion
  gives 609; also requiring a heading occurrence gives 135 (~4/file). Fires
  on the issue's own "mode" example; does not fire on "router" (no heading
  occurrence) or on vocabulary words.
- **B4.** `count_list_items(tail)`: comma-split outside parens/quotes, then
  and/or-split the lone remaining part when there's exactly one (one
  conjunction → 2, none → 1, more than one → `None`/ambiguous, no report).
- **B5.** `find_count_list_mismatches(blocks)`: over `split_sentences()`
  results from paragraph blocks and top-level list items (headings/tables
  excluded); reports only when the counted items (≥2) differ from the
  stated number. The issue's own and/or-list-with-no-colon variant and a
  count followed by a *separate* bullet block are explicitly **not** built
  in v1 — recorded as known limits, left to the judging model which reads
  the whole file anyway.
- **B6.** Wiring into `find_register_candidates()` (extended lexicon tuple
  with `vocabulary` and single-word banned phrases) and `main()`
  (`register_rule_ids` gains both ids). The code is safe against an older
  `swe` pin: detectors run only for rule ids present in `rule_ids`, so an
  unpinned/old catalogue emits nothing for them.
- **B7.** Docs: module docstring, `agent-guide.md` (detector list + Known
  limits section: no cross-document term counts, heading-occurrence gate,
  no POS tagging so a domain noun can still candidate, colon-only/two-to-
  twelve-only count detector, code-comment sources still get candidates),
  `lint-file/SKILL.md` example section. Hooks' advisory text is generic, no
  change needed (confirmed by grep before concluding this).
- **B8.** New `swe/tests/define_and_count_candidates_test.sh`, same harness
  shape as `definite_phrase_candidates_test.sh`: true positives/negatives
  for both detectors (bold-defined, "means", "a mode is a", parenthetical,
  glossary bullet, <3 occurrences, no-heading, vocabulary word, fence/
  blockquote-only, `both`-excluded, numeral-excluded, ambiguous-excluded,
  colon-in-fence-excluded), cap/invariant checks mirrored from #19, a
  real-file zero-candidate sweep for the count rule. All ten existing
  suites re-run against both the local checkout and the fetched `v0.0.27`
  pin; any assertion counting candidates across *all* rule ids gets
  narrowed to its own rule ids first (the #19 precedent), only if a fixture
  actually newly qualifies under the new gates — the plan's own check found
  none of `definite_phrase_candidates_test.sh`'s fixtures do.

`swe/software-english.json` pin → `v0.0.27`; `swe`'s own
`.claude-plugin/plugin.json` version `0.21.0` → `0.22.0` (minor: new
detector output, matching #18/#19's own minor bumps).

The `claude-plugins` commit does **not** say `closes #21` (that would close
a same-numbered `claude-plugins` issue if one exists) — it says "Part of
jimbarritt/software-english#21" instead; the `software-english` commit says
`closes #21`.

### Fourth gap — no-go, recorded not built

The "first paragraph of a Reference document must state its subject"
suggestion is explicitly speculative in the issue's own wording ("Consider
a rule..."), names no fault/fix pair or check, and most of what it would
cover already exists uncaught for an unrelated reason: §7.13
`no-mechanism-for-outcome` and §7.1 "Summary before detail" already state
this, but — like §7.4 before this fix — have no catalogue entry, so the
inference tier never asks the model about them. The same gap likely exists
for other SPEC inference sections (§7.2, §7.3, §3.1, §3.3) — worth a
dedicated follow-up issue, "every SPEC inference rule gets a catalogue
entry", rather than building one more one-off entry here. Not built this
run; recorded as a side note on the issue and here.

## Decisions made without escalating (no genuine two-materially-different-
readings fork found)

1. **Count/list check: inference-based at error, not deterministic**, a
   correction to the issue's own literal "fully deterministic" proposal —
   its own worked example is genuinely ambiguous between two valid
   readings, and a naive deterministic version produced 7/15 false
   positives on the real corpus (explanatory colons, quantities, section
   numerals, items containing "or"/"and"). Matches the software-english#15
   precedent (rejected a deterministic cleft check for the same reason:
   needs judgement) and claude-plugins#19 (declined an optional blocking
   check that would break an invariant). The "error, not warning" half of
   the ask is kept in full via severity, independent of tier.
2. **Python changes in a `software-english`-opened issue are in scope**,
   per the software-english#20 precedent (a fix spanning both repos) and
   MAINTAINER-RUN step 7's existing pin/release handling for exactly this
   case.
3. **Heading-occurrence gate on the undefined-term detector** — a
   corpus-tuned precision gate (609 → 135 candidates), not in the issue's
   literal wording, needed because the literal version alone floods every
   file; same kind of tuning as #18's `COMMON_VERBS` addition.
4. **`mode` is not added to the §7.15 word list** — it has correct uses
   (file mode, strict mode, CLI mode) the rule must not flag; used only as
   the worked example instead. The other three words plus `layout` are
   added, `layout`'s own real correct uses in this repo guarded by a
   widened literal-sense exception.
5. **§7.4/§7.15 precedence when both match one phrase**: report under
   §7.15 only (naming the artefact removes the undefined term), matching
   the existing §7.13 symptom-vs-fault pattern.
6. **`define-before-use` severity: warning**, like every other judgement
   rule — the issue asks for nothing stronger there, only for the count
   rule.
7. **New section numbered §7.20, appended at the end of §7** rather than
   inserted beside §7.6, avoiding a renumbering of every later section (the
   #17 precedent).

## Cross-document part of claim 1

The issue states the term recurs "across several related documents". The
linter has no cross-source state (each file in a multi-file/`--diff` call
is an independent `sources` entry) — recorded as a known limitation, not
built; the single-document version of the detector still catches the
issue's own example, since "mode" also recurs and heads within that one
document.

## Status

Shipped, both halves, single pass, no escalation.

- `software-english` `main`:
  [`4bc643b`](https://github.com/jimbarritt/software-english/commit/4bc643bef7f90f29e7f809ca7ee1ec6f320ac3c3),
  released
  [v0.0.27](https://github.com/jimbarritt/software-english/releases/tag/v0.0.27),
  closed issue #21 automatically via `closes #21`.
- `claude-plugins` `main`:
  [`75cfc23`](https://github.com/jimbarritt/claude-plugins/commit/75cfc239a287e69227b5e48bc2c9978985b0288c)
  (pin bump + Python detectors + tests + docs, `swe` `0.21.0` -> `0.22.0`),
  released
  [swe-v0.22.0](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.22.0).
  Commit says "Part of jimbarritt/software-english#21", not `closes`, since
  that would risk closing a same-numbered `claude-plugins` issue.
- Closing comment posted on software-english#21 naming both commits and
  tags, and the actual disposition of all four claims (1 and 2 corrected,
  not implemented literally; 3 as asked; 4 explicitly deferred).
- One self-check catch during drafting (not anticipated in the plan): new
  prose citing the rule id `no-abstract-stand-in-for-artefact` tripped
  `abstract-location` via hyphen-tokenisation of "stand-in" into the bare
  word "stand" — the same shape issue #14 already recorded. Reworded
  "stands in for" to "substitutes for" everywhere avoidable; the one
  residual hit from citing the rule id by name itself is accepted as the
  established, unavoidable self-citation cost (same reasoning as #18's
  `no-metaphor-or-analogy` self-citation).
- All ten `claude-plugins/swe` test suites pass, verified twice: once
  against the local `software-english` checkout (`SWE_SRC=`), once against
  the real fetched `v0.0.27` tag after release.
- `claude-plugins`#16 stays `agent:hold`, excluded from the pool as before.
