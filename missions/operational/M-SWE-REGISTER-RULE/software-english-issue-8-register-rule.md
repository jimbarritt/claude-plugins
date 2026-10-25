# software-english#8: register rules (LLM-register tics)

[Issue #8](https://github.com/jimbarritt/software-english/issues/8)
("No rule covers LLM register"), opened by jimbarritt-pleo on
2026-09-29. Claimed by the self-maintaining-repo Routine on 2026-10-20.

## The ask, verbatim

> Text can pass both tiers clean and still read unmistakably as
> machine-generated. The spec has no rule covering register, and a
> reader identified it immediately on a document the linter reported
> clean. Five tics observed in that document:
>
> - A short verbless fragment used as a beat after a long sentence.
> - Matched sentence pairs written for cadence, where the second
>   restates the first in parallel shape.
> - A bolded lead-in on every bullet, across three consecutive lists.
> - The same measurement restated three times in different words.
> - A twenty-entry contents list on a 250-line document.
>
> The first two are the strongest signals and the hardest to unsee
> once named.
>
> Direction: a register section in the spec, with an inference-tier
> rule. Two of the five have deterministic-tier candidates: a
> verbless-fragment check, and a repeated-structure check that counts
> identical bullet or sentence shapes in a run.

## Reading

No existing SPEC.md section covers rhythm/formatting across sentences
or across a whole document; §3-§7 are sentence, grammar, semantic,
vocabulary, and document-content rules respectively, none of which fit
a cross-sentence cadence fault or a whole-document formatting fault.

The two "deterministic-tier candidate" checks named in the issue
(verbless-fragment detection, repeated-bullet/sentence-shape counting)
would need a new `check` value in `software_english_lint.py`
(`claude-plugins/swe/scripts/`), which lives in the other repository
and has no part-of-speech tagger available (stdlib only, per
`COLOPHON.md`). Neither candidate meets SPEC §2's deterministic-tier
test ("a lookup or a regular grammar can decide it without
interpreting meaning") on its own: a verbless sentence or a repeated
shape is structurally findable, but deciding whether the flagged text
adds a fact needs judgement either way. Scoped this issue to spec text
plus `inference-based`/`model-judgement` catalogue entries only, and
filed the code-level detector idea as a separate `claude-plugins`
follow-up issue rather than doing it inline here.

## Plan

Dispatched an Opus `Plan` subagent with the issue text, the full
`rules/core-rules.toml`, and SPEC.md §3 / §5.5 / §5.6 / the Contents
block as style reference. It recommended:

1. A new top-level `## 8. Register rules` section in `spec/SPEC.md`,
   after §7.14 and before Appendices (no renumbering needed, since
   appendices are lettered).
2. Two subsections, both inference-based, both `warning` severity:
   - **§8.1 No cadence device**: the two strongest tics (verbless
     fragment as a beat; a matched sentence pair restating itself in
     parallel shape). Shared test: delete the flagged sentence/pair
     member and check whether a reader loses a fact.
   - **§8.2 No mechanical repetition**: the other three tics (bold
     lead-in repeated on every bullet across a run of lists; one
     measurement restated several times in different words; a
     contents list out of scale with the document). Shared test:
     repetition is correct only where the reader actually needs the
     form or the fact again.
3. Two matching `[[rules]]` entries in `rules/core-rules.toml`
   (`no-cadence-device`, `no-mechanical-repetition`), `tier =
   "inference-based"`, `check = "model-judgement"`, `severity =
   "warning"`, each description mirroring the SPEC prose at the same
   depth as existing entries (e.g. `no-clipped-sentence-run`,
   `no-metaphor-or-analogy`).
4. A short `COLOPHON.md` addition explaining why both new rules are
   inference-based only (no deterministic candidate meets §2's bar
   with a stdlib-only linter).
5. A follow-up `claude-plugins` issue proposing structural detectors
   (located-candidate signals, not new blocking rules) for the two
   strongest tics, to feed the existing model-judgement pass rather
   than add a new deterministic rule.

Full plan detail (verbatim drafted SPEC.md/TOML/COLOPHON.md text) came
from the Opus subagent; the text above is this session's own summary
of it.

## Outcome

Applied the plan as drafted, no deviation on scope or section
placement.

- `spec/SPEC.md`: added the three Contents lines and the `## 8.
  Register rules` block (§8, §8.1, §8.2) before `## Appendices`.
- `rules/core-rules.toml`: added `no-cadence-device` and
  `no-mechanical-repetition`, both inference-based/warning, inserted
  after `no-mechanism-for-outcome` and before `[exemptions]`.
- `COLOPHON.md`: added a "Register: a new section, inference-based
  only" section at the end, matching the existing per-rule-decision
  style.

Verified by copying the edited `rules/core-rules.toml` into
`claude-plugins/swe/data/` (gitignored, normally fetched from the
pinned release tag) and running
`software_english_lint.py --count spec/SPEC.md COLOPHON.md` directly,
since the `swe` plugin is not installed as a skill in this session.
Deterministic tier: baseline (pre-edit, same two files) was 20
errors; after the edit, 21, all but one line-shift-identical to the
pre-existing baseline set (banned words "holds"/"the reader"/"carry"/
"load-bearing", one `no-continuous-tense` hit, all outside the new
text). The one genuinely new error was a "holds" banned-word hit in
my own new `COLOPHON.md` prose; fixed it to "contains" and reran —
back to 20, matching baseline exactly, so the new text adds zero new
deterministic findings. Restored `swe/data/` to the pinned
`v0.0.16` tag afterwards so the sandbox copy did not linger.

Inference tier: read the new §8.1/§8.2 text back against its own
rules by hand (the irony of shipping a register fault inside the rule
that bans it) — no verbless-fragment beat, no bold lead-in repeated
across the new bullet lists, no measurement restated three ways.

Also ran, per Step 5, the `claude-plugins` suite even though this
issue is `software-english`-only and no file there changed: all six
`swe/tests/*_test.sh` scripts passed (91+18+8+3+18+4, 0 failed), and
`scripts/check-unshipped.sh` exited 0 (clean; `swe` had no tag history
visible until `git fetch --tags` pulled it, then matched its newest
tag exactly).

Committed on `software-english` `main`:
[`9df843b`](https://github.com/jimbarritt/software-english/commit/9df843b3cb8c31bd971294578f048eb715fa82fd),
message ends `closes #8`. Pushed. Released: `release.yml` run
[39385832805](https://github.com/jimbarritt/software-english/actions/runs/39385832805)
with `version: 0.0.17` (newest prior tag v0.0.16), success, tag
[v0.0.17](https://github.com/jimbarritt/software-english/releases/tag/v0.0.17).

Because the change touches `rules/core-rules.toml` (a file `swe`
fetches): bumped `claude-plugins/swe/software-english.json`'s `tag` to
`v0.0.17` and `swe`'s own `plugin.json` version `0.17.7` → `0.17.8`,
commit
[`7147c5a`](https://github.com/jimbarritt/claude-plugins/commit/7147c5a4648eb8d7962095d3813bffa2f6c3323a)
on `claude-plugins` `main`, pushed, ran `release-plugin.yml` with
`plugin: swe` — run
[39385934978](https://github.com/jimbarritt/claude-plugins/actions/runs/39385934978),
success, tag
[swe-v0.17.8](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.17.8).
Confirmed with `scripts/check-unshipped.sh` before (flagged version
ahead of tag, as expected pre-release) and after (clean, matches).

Filed a follow-up issue against `claude-plugins`,
[#18](https://github.com/jimbarritt/claude-plugins/issues/18),
proposing structural detectors (located-candidate signals only, not a
new deterministic rule) for the verbless-fragment and
repeated-bullet/sentence-shape tics, to reduce missed findings and
model cost on long documents.

Commented on #8 with the commit and release links; removed
`agent:working`, kept `auto-fix-candidate`. Issue auto-closed by the
`closes #8` commit before the comment landed (`closed_by: jimbarritt`,
`state_reason: completed`). No other open issue, on either tracker, is
resolved by this change.

Single pass, no escalation.
