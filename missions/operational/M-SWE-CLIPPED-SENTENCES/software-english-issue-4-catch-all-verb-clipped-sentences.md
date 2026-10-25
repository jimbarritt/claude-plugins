# software-english#4: catch-all verb + clipped sentence run

## The ask (verbatim)

> ## Verdict
>
> `false-negative`, no named rule (logged via `/swe:feedback`, 2026-09-25).
>
> ## The text that passed
>
> > That design defines two events on two topics. Its Processing section states them. Their contract is below. It states the payload of each, the topic and message key of each, and the AVRO schema of each. It also states where each is registered.
>
> Both tiers reported nothing. A reader recognised it immediately as machine-written prose.
>
> ## Why it is a fault
>
> Three faults compound, and no single sentence breaks a rule:
>
> 1. **A repeated catch-all verb.** "States" appears four times across five sentences, standing in for "defines", "specifies", "gives" and "records". The repetition is not emphasis; it is one weak verb covering four different relations.
> 2. **An unvaried run of short sentences.** Every sentence is short and roughly the same length, so the rhythm is staccato rather than varied.
> 3. **A shifting pronoun chain.** "Its… Their… It… It" changes referent between consecutive short sentences, which is jarring to read.
>
> The passage as a whole is the fault, which is why a sentence-level tier misses it.
>
> ## Important interaction with the existing rules
>
> The 20-word sentence limit pushes writing toward exactly this shape. A writer splitting one thought to stay under the limit produces four clipped sentences and a pronoun chain to stitch them together. Any new rule needs to name the compensating requirement explicitly: vary sentence length, and do not split one thought into four clipped sentences.
>
> Without that, the two rules pull against each other and the limit wins, because it is deterministic.
>
> ## Proposed fix direction
>
> Two inference-tier rules:
>
> - A verb repeated across a paragraph where the repetitions carry different meanings. Name the distinct relations and use a distinct verb for each.
> - An unvaried run of short sentences, paired with the compensating guidance above.
>
> ## The reporter's rewrite
>
> > The design defines two events, on separate Kafka topics. In this document we elaborate the design fully. The full AVRO schema definition can be found in Appendix A.

Opened by `jimbarritt-pleo` (trusted collaborator), 2026-09-25.

## Reading

The issue names three compounding faults but proposes only two rules,
folding the pronoun-chain observation into the "unvaried short
sentences" rule as a required test rather than a third rule. An Opus
Plan subagent's read of the real rule catalogue and SPEC confirmed no
existing rule is close enough to extend (checked `no-undeclared-state-verb`,
`no-unanchored-reference`, §3.1, §3.2 — none cover verb repetition,
sentence-length variance, or pronoun-referent shift).

Two factual problems in the issue's own example, found only by actually
counting, not assumed from the issue's prose: "states" occurs three
times, not four; and the sentence lengths are 8/5/4/19/7 words, not
uniformly short (the 4th sentence is 19 words). A rule testing length
variance alone would miss the issue's own example and fire on the
reporter's rewrite (lengths 9/8/11, more uniform) instead. What
actually separates the fault from the rewrite is the pronoun chain
splitting one fact into clipped pieces, confirmed by judging both
texts against each rule's draft description directly, not just
reasoning about them.

The reporter's rewrite also was not used as the worked fix example: it
drops facts (payload, message key, topic, registration) that §3.1
requires kept, and adds facts not in the original ("Kafka", "Appendix
A"). A fact-preserving rewrite was written instead for both rules'
descriptions and SPEC.md's worked examples.

## Plan (from an Opus Plan subagent, model opus)

Two new inference-tier rules in `rules/core-rules.toml`, both
`check = "model-judgement"` (the only check type the linter's
inference block loads prose descriptions for):

- `no-clipped-sentence-run` (after `sentence-length`): a run of three
  or more consecutive short sentences in one paragraph, splitting one
  fact into clipped pieces joined by a shifting pronoun chain. Judge
  in two steps: find the run, then check it for a split fact (a
  sentence stating no complete fact alone, or a pronoun/possessive
  subject whose referent differs from the one before it).
- `no-catch-all-verb` (after `no-undeclared-state-verb`): one content
  verb used more than once in a paragraph to name different relations.
  Judge in two steps: find each repeated content verb, then state the
  relation each occurrence names; report only when two occurrences
  name different relations.

Matching `spec/SPEC.md` additions: new §3.6 (after §3.5) and §5.9
(after §5.8), following the existing worked-example/"these are not
this fault"/reasoning-paragraph pattern each inference-tier section
already uses. Cross-references added to §3.1 (the rule also applies in
reverse) and §3.2 (the limit is a ceiling, not a target). Contents
list also gained the missing §3.5 entry, which predated this change
and was never added.

No `vocabulary/` change: this is a structural/relational fault, not a
word-choice one — confirmed by checking for an existing conflicting
entry and finding none.

Pre-existing inconsistency found but left alone (out of scope for this
issue, not introduced by it): §3.2's heading says "(Deterministic)"
while its TOML `tier` is `inference-based`.

## Work

Both rules added to `rules/core-rules.toml` (23 rules total, TOML
parses). SPEC.md updated: Contents (added 3.5, 3.6, 5.9), §3.1, §3.2,
new §3.6, new §5.9.

One self-check catch during implementation, not anticipated in the
plan: the first draft of the §3.6 cross-reference text in §3.1 used
"holds" ("the rule also holds the other way") as a truth-metaphor —
exactly the possession-metaphor shape `software-english`#2/#13 already
banned for every subject, regardless of sense. Caught only by actually
diffing the deterministic lint output before/after the edit against
the real linter, not by reading the prose back. Reworded to "applies
in reverse". A second instance ("adds no word that carries no fault")
in both SPEC.md and the matching TOML description was caught the same
way and reworded to "states no fact".

Verified directly against the real linter (`software_english_lint.py`,
synced from both a local checkout and the actual released `v0.0.14`
tag):

- Both new rules load into the `--force-inference` advisory block.
- The deterministic tier is unchanged line-for-line on the full edited
  `SPEC.md`, diffed by content (not line number, since the edit shifts
  line numbers) against the pre-edit file: identical 24 pre-existing
  findings, no new ones.
- Manually judging both the issue's fault text and the fact-preserving
  fix text against each rule's printed description (standing in for
  the subagent a hook would dispatch) confirms: `no-clipped-sentence-run`
  fires on the fault text (sentences 1-3 are a 3-sentence run under ten
  words each, sentence 3 states no fact alone, pronoun referents shift
  Its→Their→It) and stays silent on the fix text (lengths 14/18/9,
  only one of three under ten words, so the run pre-filter does not
  match); `no-catch-all-verb` fires on the fault text ("states" ×3,
  three distinct relations) and stays silent on the fix text (defines/
  specifies/records, each used once).

All six `claude-plugins` test suites pass (142 assertions, unchanged —
no code change, prose/rules only). `scripts/check-unshipped.sh` run
before and after.

## Shipped

`software-english` `main` at
[`8aa442a`](https://github.com/jimbarritt/software-english/commit/8aa442a),
released as
[`v0.0.14`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.14),
closing the issue automatically (`closes #4`). Because the change
touched `rules/core-rules.toml`, `claude-plugins` pin bumped to that
tag and `swe` version `0.17.4` -> `0.17.5` on `main` at
[`02dafb5`](https://github.com/jimbarritt/claude-plugins/commit/02dafb5),
released as
[`swe-v0.17.5`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.17.5).

Single pass, no escalation.

## Note: unrelated prior work found already shipped

Before starting, `claude-plugins` `main` was found one commit behind
`origin/main`: a prior session (session `session_01C2ketEForzZtWkomf2pwhG`)
had already pushed and released
[`63ebe0c`](https://github.com/jimbarritt/claude-plugins/commit/63ebe0c)
("swe: reword 'hold' out of the plugin's own docs", `swe-v0.17.4`),
rewording 19 uses of `hold`/`holds`/`holding` in the plugin's own docs
that `software-english`#2/#13's ban (recorded above in "Recently done")
had made non-compliant. Fully shipped and released already; this run
only needed to pull it in before bumping the pin again on top of it.
