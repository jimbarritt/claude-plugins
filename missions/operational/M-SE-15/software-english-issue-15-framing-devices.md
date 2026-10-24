# software-english#15: framing devices in a declarative (cleft, rhetorical question, naming-as-justification)

[Issue #15](https://github.com/jimbarritt/software-english/issues/15)
("New rule: framing devices in a declarative (cleft, rhetorical
question, naming-as-justification)"), opened by jimbarritt-pleo on
2026-10-20, labelled `auto-fix-candidate`. Claimed by the
self-maintaining-repo Routine on 2026-10-20.

## The ask, verbatim

> Verdict: false-negative. No existing rule fires on any of the three
> shapes below. They co-occur, and a passage carrying all three passes
> both tiers clean.
>
> ## The shapes
>
> > The gateway asks one question of all four: can this order ship on
> > this date, and what reference does the carrier call need. A dispatch
> > slot is named for that question rather than for the structure it was
> > imported from, and the import is what reconciles the four structures
> > down to it.
>
> **1. Cleft padding.** `the import is what reconciles` for `the import
> reconciles`. The cleft adds a copula and a relative pronoun and states
> nothing the plain clause does not. Mechanical signatures:
>
> - `X is what Y`
> - `it is X that Y`
> - `what X does is Y`
> - `X is the thing that Y`
>
> A deterministic check may be feasible here: the pattern is a copula
> followed by `what`/`that`/`the thing that` with a finite clause after
> it. The main false positive to avoid is a genuine identity statement
> (`the primary key is what the index is built on` is the same fault;
> `the status is what the caller reads` likewise), so every match in this
> form is a candidate.
>
> **2. Rhetorical-question framing.** An interrogative embedded as the
> subject or object of a declarative: `asks one question`, `answers two
> questions`, `named for that question`. The rule being stated is
> available directly. Fix: `The gateway needs two facts: whether the
> order may ship on the date, and the reference the carrier call takes.`
>
> **3. Naming-as-justification.** `A dispatch slot is named for that
> question rather than for the structure it was imported from` argues
> about the choice of a name instead of stating what the type is. Fix:
> `A dispatch slot is a date range, a status and a carrier reference.`
>
> `no-contrastive-framing` did not fire on the `X rather than Y`
> construction here, which may be a separate gap in that rule.
>
> ## Proposed fix direction
>
> One new rule covering the three, or a deterministic cleft rule plus an
> inference rule for the other two. The cleft is the most tractable:
> the signature is mechanical, and the fix is always the same, which is
> to drop the copula and the relative pronoun.

## Reading

Checked whether a deterministic cleft check is actually feasible inside
this run's scope, since the issue offers it as an option. Read
`claude-plugins/swe/scripts/software_english_lint.py` directly:
`check_line()`'s deterministic tier is hardcoded per rule id
(`no-continuous-tense`, `no-em-dash`, `anthropomorphism-fixed-list`,
`abstract-location` each have bespoke Python), with no generic
pattern-based dispatcher. A new deterministic cleft check would need new
Python in `claude-plugins`, a different repository. By contrast, the
inference-based (`check == "model-judgement"`) path is fully generic:
it collects every such rule's `description` and feeds it to the judging
pass, so a new inference-based rule in `core-rules.toml` needs no code
change anywhere. This run's briefing (MAINTAINER-RUN.md step 5) scopes
work to the issue's own repository. Decision: one new rule, entirely
inference-based, no `claude-plugins` code change, to stay inside
`software-english` for the fix itself (the `swe` pin bump in step 7 is a
separate, mechanical step the briefing already accounts for when a
change touches `rules/core-rules.toml`).

## Plan

Dispatched an Opus `Plan` subagent with the issue text, the full
`rules/core-rules.toml`, and SPEC.md's §5 neighbours (§5.1, §5.5, §5.7,
§5.9) as house style. It recommended:

1. `id = "no-framing-device"` (echoes the issue's own term and
   `no-cadence-device`'s naming), `tier = "inference-based"`,
   `check = "model-judgement"`, `severity = "warning"`, no
   `applies_to_document_type` (fires on every type, like §5.9).
2. One `description` covering all three shapes, each with its own
   mechanical signatures, Fault/Fix pairs, a two-step judging
   procedure, explicit "Not this fault" exclusions, and "Distinct
   from" sentences against `no-question-or-argument-heading` (headings
   vs body prose), `no-contrastive-framing` (the `X rather than Y`
   overlap, resolved in this rule's favour only where the contrast
   argues for a name), `no-catch-all-verb`, `anthropomorphism-paraphrase`
   and `no-metaphor-or-analogy` (the `asks`/`answers` overlap),
   `no-abstract-stand-in-for-artefact` (`question`/`answer` as a
   stand-in noun), and `no-entailed-restatement`.
3. Per the issue's own stated reading (not the planning brief's initial
   misreading of it): an identity statement does **not** exempt the
   cleft shape. `the primary key is what the index is built on` and
   `the status is what the caller reads` are both kept as faults, with
   fixes. The real cleft exclusions are genuine non-clefts: a `what`/
   `which` clause that is a content verb's object, not a copula's
   complement; and `X is the N that Y` where N is a real classifying
   noun.
4. New SPEC.md §5.10, same depth as §5.7/§5.9: statement, the issue's
   own fault passage as the blockquote example, a fix blockquote, a
   subsection per shape, a "not this fault" list, and a "distinct from"
   list naming which of the seven neighbouring rules takes the finding
   on an overlap.
5. Insert the `core-rules.toml` block immediately after
   `no-catch-all-verb` (keeps the §5.7/§5.8/§5.9/§5.10 run of ids
   together, matching how §5.9 itself was added straight after §5.8);
   insert the SPEC.md section and its Contents bullet straight after
   §5.9, before `## 6. Vocabulary rules`.
6. No `claude-plugins` change, no `vocabulary/*.tsv` change (no
   signature has a correct-use-free literal form), no test suite in
   `software-english` to update.

Full literal drafted text (the TOML `description` string and the
SPEC.md §5.10 block) came from the Opus subagent, applied as drafted
with the identity-statement correction from step 3 above.

## Outcome

Applied the plan as drafted, with the one correction from the Reading
section (deterministic split rejected; stays entirely inference-based)
and the one correction from the Plan section (identity statements are
faults, per the issue, not exemptions).

- `rules/core-rules.toml`: new `[[rules]]` block, `id =
  "no-framing-device"`, inserted after `no-catch-all-verb`.
- `spec/SPEC.md`: new §5.10 section after §5.9, before `## 6.
  Vocabulary rules`; matching Contents bullet after the §5.9 entry.

Verified against the real linter, not just reasoned about: vendored the
edited `rules/core-rules.toml` and `vocabulary/*.tsv` into
`claude-plugins/swe/data/` (gitignored; `swe` is not installed as a
skill in this session), set `.fetched-tag` so
`fetch-software-english-data.sh` would not overwrite it, then ran
`software_english_lint.py --diff --added-only --force-inference` on
both changed files. Zero `[error]`-severity findings (the deterministic,
blocking tier). The `[warning]`-only `vocabulary-membership` noise is
expected and inherent (the vocabulary is a seed set; this rule never
blocks) and matches every other SPEC section's own lint profile.
Manually judged the new prose in both files against every rule the
printed `INFERENCE_ADVISED` block listed: no plausible finding, including
the close calls (a "Three shapes..." lead-in is not a count-signpost
fault, since the items do not come directly after it and the sentence
states a fact beyond the count; "wraps the fact in a frame" and "a
sentence argues for..." follow the same established, already-shipped
convention as §5.7's "answers an objection" and §7.18's "argues a case",
not a fresh metaphor or anthropomorphism). `python3 -I` with `tomllib`
confirmed the file still parses and all 31 rule ids stay unique.
Restored `swe/data/` to empty afterwards.

All seven `claude-plugins` test suites pass, unchanged.
`scripts/check-unshipped.sh` reported `swe` up to date both before this
change (no `claude-plugins` edit yet) and after the plugin release
below.

Committed on `software-english`'s `main`:
[`1de92e5`](https://github.com/jimbarritt/software-english/commit/1de92e5),
message ends `closes #15`. Pushed. Released: `release.yml` run
[39456378128](https://github.com/jimbarritt/software-english/actions/runs/39456378128)
with `version: 0.0.22` (newest prior tag v0.0.21), success, tag
[v0.0.22](https://github.com/jimbarritt/software-english/releases/tag/v0.0.22).

Because the change touches `rules/core-rules.toml` (a file `swe`
fetches): bumped `claude-plugins/swe/software-english.json`'s `tag` to
`v0.0.22` and `swe`'s own `plugin.json` version `0.18.1` -> `0.18.2`,
commit
[`53ea98b`](https://github.com/jimbarritt/claude-plugins/commit/53ea98b)
on `claude-plugins` `main`, pushed, ran `release-plugin.yml` with
`plugin: swe` — run
[39456554913](https://github.com/jimbarritt/claude-plugins/actions/runs/39456554913),
success, tag
[swe-v0.18.2](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.18.2).
Confirmed with `scripts/check-unshipped.sh` after: clean, matches.

Commented on #15 with the two commits, both release tags, and the
identity-statement reading; removed `agent:working`, kept
`auto-fix-candidate`. Issue auto-closed by the `closes #15` commit
before the comment landed (`closed_by: jimbarritt`, `state_reason:
completed`). No other open issue, on either tracker, is resolved by
this change.

The issue's own closing remark, that `no-contrastive-framing` may
separately miss the general `X rather than Y` contrast, is left
unfixed: flagged there as a possible separate gap, not this issue's
ask. §5.10 covers that contrast only where it argues for a name.

Single pass, no escalation.
