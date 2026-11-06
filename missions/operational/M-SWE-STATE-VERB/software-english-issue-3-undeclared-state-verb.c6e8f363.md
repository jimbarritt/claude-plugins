# software-english#3: an invented state verb passes while the document declares an explicit status set

[Issue #3](https://github.com/jimbarritt/software-english/issues/3), filed by
`jimbarritt-pleo`.

## The ask, verbatim

> ## Verdict
>
> `false-negative`, candidate rules `anthropomorphism-paraphrase`,
> `no-metaphor-or-analogy`, `define-before-use` (logged via
> `/swe:feedback`, 2026-09-25).
>
> ## The text that passed
>
> The design of the two events `erp-sync` publishes when a journal
> entry sync settles: one per item, one per sync.
>
> The same word appears again in the plainer sentence "when a sync
> settles".
>
> ## Why it is a fault
>
> "Settles" is not a domain term in the codebase the document
> describes. The sync status set is `pending`, `in_progress`,
> `failed`, `completed` and `completed_with_errors`. Nothing named
> settle exists in the design or in the schema.
>
> The word is invented, narrative and metaphorical, and it stands in
> for two distinct mechanisms at once: one journal entry finishing its
> export, and the whole sync job finishing. A reader cannot recover
> which, and neither is called settling anywhere in the system.
>
> The inference tier ran over the file with `--force-inference` and
> reported nothing. Three rules had a claim on it and all three
> missed.
>
> ## Proposed fix direction
>
> A checkable heuristic for the inference tier: a verb describing a
> state change of a domain entity, where the document also defines an
> explicit status set for that entity, and the verb is not one of
> those status values.
>
> The status set is usually declared in the same document, often as
> an enum or a type, which gives the rule its evidence without needing
> the codebase.

## Reading

The three candidate rules named in the issue each miss this fault for
a distinct, real reason, so the fix is a new rule, not a widened
existing one:

- `anthropomorphism-paraphrase`: the verb gives the system no human
  trait, feeling, or intent. "Settles" is not anthropomorphic.
- `no-metaphor-or-analogy`: the verb is not on the fixed metaphor list
  and is not a comparison to something else in the way the rule's
  existing examples are. It is closer to a wrong synonym than a
  metaphor.
- `define-before-use` (SPEC §7.4, no `rules/core-rules.toml` entry):
  the term is not undefined. It substitutes for status values the
  document already declares explicitly, which is the fault itself —
  defining "settle" would only add a second name for states that
  already have one.

## Plan

Dispatched an Opus `Plan` subagent with the issue text and the real
spec/rules files to read. It confirmed the gap and returned a ready
plan: a new §5.8 in `spec/SPEC.md`, placed at the end of §5 (semantic
rules) rather than §7, because the fault is about what a word means
and the fix swaps one word for another, the same placement logic as
§5.1 and §5.5 next to it; and a matching `no-undeclared-state-verb`
entry in `rules/core-rules.toml`, `inference-based` / `model-judgement`
/ `warning`, consistent with every other rule in that tier.

Rejected id `status-set-mismatch`: reads as a schema-consistency check
between two external artefacts, not a fault in the prose's own choice
of verb.

## Implementation

- `spec/SPEC.md`: new §5.8 "No undeclared state verb", added to the
  Contents list and after §5.7. States the rule, uses the issue's own
  motivating example (`settles` against the declared
  `pending`/`in_progress`/`failed`/`completed`/`completed_with_errors`
  set) as the fault/fix pair, lists three exclusions (a verb form of a
  declared value, an entity with no declared status set, a verb naming
  an action not a state change), and explains why this needs the
  inference tier (the status set must be read from the document,
  comprehension not lookup) and how it differs from each of the three
  ruled-out rules.
- `rules/core-rules.toml`: new `no-undeclared-state-verb` entry,
  inserted after `no-contrastive-framing` and before
  `no-out-of-scope-comparand`, keeping the §5 entries together in spec
  order. Description written in the same density as its neighbours,
  cites SPEC §5.8, states the two-step judgement procedure (find every
  declared status set and its entity, then check each state-change
  verb against it), and cross-references why each of the three
  candidate rules misses it.
- No change needed to Appendix A (lists deterministic check types
  only), Appendix F, `templates/`, `docs/`, or `vocabulary/`: checked
  each per the plan and found no rule-authoring convention file, no
  fixture/test directory in this repo, and no template that should
  mention declared status sets.
- No code change needed in `claude-plugins/swe`: the lint script
  (`swe/scripts/software_english_lint.py`) loads `rules/core-rules.toml`
  at run time and selects `model-judgement` rules generically
  (`r.get("check") == "model-judgement"`); it never hardcodes inference
  rule ids. Only the pin bump below was needed.

## Validation

- `python3 -I` parsed the edited `rules/core-rules.toml` directly
  (stdlib `tomllib`, no installed packages) and confirmed
  `no-undeclared-state-verb` appears among the `model-judgement` rules.
- Ran `swe/scripts/software_english_lint.py --text --force-inference`
  against the issue's own flagged sentence plus its status set, using
  a scratch copy of the edited rules/vocabulary files at the path the
  script expects (`swe/data/`, gitignored, removed after testing, no
  `claude-plugins` files touched). The new rule's description appears
  in the `INFERENCE_ADVISED` block, naming the same sentence shape and
  heuristic the issue asked for.
- Ran the real linter against the full edited `spec/SPEC.md`
  (deterministic tier, `--quiet-vocab`): three pre-existing findings
  outside the new section (a long table row, "are doing" inside an
  existing quoted fault example, one other long table row), nothing
  new inside §5.8 itself.
- Checked the new `rules/core-rules.toml` description against
  `vocabulary/banned.tsv` by hand: no banned word or em dash in the
  new entry's text.
- All six `claude-plugins/swe` test suites pass (unchanged) after the
  version bump.
- `scripts/check-unshipped.sh` run before and after the `swe` version
  bump: correctly reported the pending release before, clean after
  (tags refetched first — local tags lagged the just-run release).

## Outcome

Shipped on `software-english`'s `main` at
[`b21056b`](https://github.com/jimbarritt/software-english/commit/b21056b85314442551e125d39226c275e4c25656),
released as
[`v0.0.13`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.13),
closing #3 (`closes #3` trailer, auto-closed). `claude-plugins` pin
bumped and `swe` version bumped (`0.17.2` -> `0.17.3`) on `main` at
[`704f0a0`](https://github.com/jimbarritt/claude-plugins/commit/704f0a033bca44ac7033c3bfae5da70d28aae787),
released as
[`swe-v0.17.3`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.17.3).
`agent:working` removed on close. Single pass, no escalation needed.
