# software-english#12: two inference-tier rules for heading-specific faults

[Issue #12](https://github.com/jimbarritt/software-english/issues/12)
("Two inference-tier rules for heading-specific faults"), opened by
jimbarritt-pleo on 2026-10-12. Claimed by the self-maintaining-repo
Routine on 2026-10-20.

## The ask, verbatim

> ## The gap
>
> Two faults appear in headings and have no entry in the catalogue. Both are
> visible only in a heading: as a sentence in body prose, neither shape occurs.
>
> ## Ask
>
> **1. A heading that withholds its content.** A heading names what the section
> states. A heading that defers it, so the reader must read the section to
> learn what it says, is a fault:
>
> > Before: What this means for everything else
> > After: Retries are capped at three attempts
>
> **2. A heading carrying an argument or a rhetorical question.** A heading
> states a claim, not a case for one and not a question the section then
> answers:
>
> > Before: Why would anyone run it twice?
> > After: A second run reuses the cached result
>
> ## Note
>
> The existing rules already cover the other heading faults observed (metaphor
> under `no-metaphor-or-analogy`, a heading defined by an absence under
> `no-contrastive-framing`). Those fire correctly on a sentence and are simply
> not applied to headings; that part is a procedural gap raised separately
> against the plugin repository.

The "procedural gap" note points at `claude-plugins#17`
("headings-as-prose"), already closed, which is why this issue only
asks for two new rule entries and makes no ask of `claude-plugins`.

## Reading

Confirmed directly from the issue text: "Both need judgement to
recognise, so both are inference-tier" — `tier = "inference-based"`,
`check = "model-judgement"`, `severity = "warning"`, matching every
other model-judgement rule.

Checked `claude-plugins/swe/scripts/software_english_lint.py`: an
inference-based rule needs no linter code. The script never judges
model-judgement rules itself; it only prints each one's `description`
inside the `===INFERENCE_ADVISED===` block for a subagent (or
`/swe:lint-file`'s own Step 4) to judge directly. Confirmed against the
real script with `--force-inference`, not just reasoned about: both
new rule ids and their full descriptions appear in that block.

§7.5 (`no-unanchored-reference`) is the closest existing precedent for
a rule scoped to headings ("The fault can appear in a heading or in
body prose"). §8's intro limits that section to rhythm, emphasis and
formatting across sentences, which is a different axis from what a
single heading names, so both new rules belong in §7 (Document rules),
not §8, beside §7.5. No existing "heading rules" subsection exists;
these take the next two free section numbers at the end of §7 (§7.17,
§7.18), the same place §7.14 was added, so a rule slotted next to §7.5
does not renumber anything the catalogue or the Contents list cite by
number.

Read every heading in `spec/`, `docs/`, `templates/`, `README.md`, and
`COLOPHON.md` (176 headings) against both draft rules by hand before
committing, specifically for the topic-label and indirect-question
styles the repo already uses heavily (`What a tutorial is`, `How this
differs from a how-to guide`, `Verdict`, `Recommendation`). Read
literally, the issue's own wording ("A heading names what the section
states" / "not a question the section then answers") would flag every
one of those. Scoped both rules narrower than the issue's literal
wording to avoid that: see Judgement calls, below.

No `claude-plugins` code change needed; the issue's own note places
that gap in the already-closed `#17`. `README.md` and
`docs/claude-md-ruleset.md` were checked for a rule count or index
that would need updating; neither lists or counts the catalogue's
rules.

## Plan

Dispatched an Opus `Plan` subagent with the issue text, `spec/SPEC.md`
§7 in full (especially §7.5, §7.14-§7.16 as the nearest house-style
models), §8 (`no-cadence-device`, `no-mechanical-repetition`, the most
recently added rules), `rules/core-rules.toml`'s neighbouring entries,
`COLOPHON.md`, and `vocabulary/banned.tsv` (which already bans several
formulaic heading phrases, e.g. "at a glance", "the big picture"). It
recommended:

1. Two new rule ids, `no-withholding-heading` (§7.17) and
   `no-question-or-argument-heading` (§7.18), both
   `tier = "inference-based"`, `check = "model-judgement"`,
   `severity = "warning"`, unconditional on document type (like §7.14,
   since nothing in the issue restricts either to one type and no
   document type makes a question or withholding heading correct).
2. Full drafted SPEC.md prose for both sections, in the house
   Fault/Fix style, each stating explicitly that its scope is headings
   only, at every level, the document title included; each
   distinguishing itself from `no-unanchored-reference` (§7.5),
   `no-metaphor-or-analogy` (§5.5), `no-contrastive-framing` (§5.7),
   and (for §7.18) `no-cadence-device` (§8.1), with an explicit
   precedence rule for a heading that two of these would otherwise
   both match.
3. Four exceptions each, narrower than the issue's literal wording: a
   heading that names a subject, or a subject and a property (`Retry
   policy`, `What a session-store entry contains`) passes both rules,
   since a heading need not be a full sentence; a conventional section
   name (`Summary`, `Verdict`, `Recommendation`, every name a document
   type's template lists) is exempt from §7.17; a task heading in the
   imperative or infinitive (`How to try it`) is exempt from both; a
   literal token or verbatim quotation is exempt from both.
4. Matching `[[rules]]` TOML entries, same prose density as the
   neighbouring entries.
5. A `COLOPHON.md` design-note section recording why both rules sit in
   §7 and not §8, why they sit at the end rather than beside §7.5, and
   why neither needs a deterministic companion.
6. No change to `README.md`, `docs/agent-guide.md`,
   `docs/claude-md-ruleset.md` (lists deterministic faults only),
   `templates/*`, or `vocabulary/*`; no change to
   `no-metaphor-or-analogy` or `no-contrastive-framing` themselves
   (the issue's own note places that gap elsewhere, already closed as
   `claude-plugins#17`).

Full literal drafted text (both SPEC.md sections, both TOML
descriptions, the COLOPHON.md section) came from the Opus subagent;
applied with one wording fix found during verification (below).

## Judgement calls

1. **Scope narrowed below the issue's literal wording.** Read
   literally, "A heading names what the section states" and "not a
   question the section then answers" would flag the repo's own
   `What a tutorial is`, `How this differs from a how-to guide`,
   `Verdict`, and similar topic-label and indirect-question headings
   used throughout `spec/`, `docs/`, and `templates/`. Both new rules
   are written to pass a heading that names a subject, or a subject
   and a property, and to pass an indirect question in statement word
   order with no question mark that names its referent. Confirmed by
   hand against all 176 existing headings in the repo: zero expected
   findings. This is the main call worth restating if Jim wants a
   second opinion.
2. **Conventional section names are exempt from §7.17 only.** `Summary`,
   `Context`, `Decision`, `Consequences`, `Recommendation`, `Verdict`,
   and any template-listed section name pass unconditionally. The line
   between a conventional name and a phrase written for one section
   (`What we found`) is itself a judgement call, same as every other
   model-judgement rule in the catalogue.
3. **Both rules apply to every document type**, unconditional like
   §7.14, since the issue restricts neither and no document type (no
   FAQ type exists) makes a question heading correct.
4. **Precedence stated explicitly** for a heading two rules would
   otherwise both match: §7.18 over §7.17 for a question that also
   withholds; both new rules over §7.5 when a heading's fix both
   states the content and names the referent (stating the claim is a
   strict superset of naming the referent); metaphor (§5.5) and
   contrastive framing (§5.7) are always reported as separate findings
   on the same heading, since fixing one does not fix the other.
5. **Severity is warning**, matching every other model-judgement rule.
   A trailing `?` is deterministically findable, but excluding a code
   span, a quoted error message, and a literal token from that signal
   still needs judgement, and the issue itself asks for the inference
   tier.

## Outcome

Applied the plan as drafted, with one wording fix found during
verification, not anticipated going in: the COLOPHON.md draft's "Both
sit at the end of §7 ... for the reason §7.14 sits there" tripped the
real deterministic linter's own `abstract-location` rule (an abstract
subject, "these rules"/"both", given the physical-position verb
"sits"). Reworded to "Both are new entries at the end of §7 ... for
the same reason §7.14 is there", re-ran the linter, clean.

- `spec/SPEC.md`: added Contents entries for §7.17 and §7.18; added
  both sections in full after §7.16, before `## 8. Register rules`.
- `rules/core-rules.toml`: appended both `[[rules]]` entries after
  `no-mechanical-repetition`, before `[exemptions]`.
- `COLOPHON.md`: appended the "Headings: two document rules, judged on
  the heading alone" design-note section after the existing Register
  section.

Verified against the real linter, not just reasoned about:

- `python3 -I` with `tomllib`: the catalogue still parses, 30 rule ids
  total, both new ids present and unique.
- `git diff -U0` on the three changed files, grepped for `—`: zero em
  dashes on any added line.
- `software_english_lint.py --diff --added-only --quiet-vocab` on the
  three changed files (`--added-only`, not `--diff` alone — `--diff`
  without `--added-only` lints the whole current file, not the diff,
  confirmed by the first run surfacing 20+ pre-existing, unrelated
  findings far from the inserted text; `--added-only` correctly
  narrowed to the one real finding, the "sits" wording above). Clean
  after the fix.
- `software_english_lint.py --force-inference spec/SPEC.md`: both new
  rule ids and their full descriptions appear in the
  `===INFERENCE_ADVISED===` block, each carrying the complete prose
  reaching a judging model word for word; the inference-rule count
  rose from 20 to 22.
- Manual model-judgement pass (there is no deterministic path for an
  inference-based rule to run against): listed all 176 headings across
  `spec/`, `docs/`, `templates/`, `README.md`, `COLOPHON.md` and judged
  each against both new descriptions as written. Zero false positives,
  including the specific borderline styles the repo already uses
  heavily (`What a ... is`, `How this differs from ...`, `Verdict`,
  `Recommendation`, `Where it does not apply`, `What to do`). Also
  judged the issue's own four worked examples (both "Before"/"After"
  pairs) plus `What we found`, `The surprising part`, `Does the cache
  survive a restart?`, and `The case for capping retries`: each fault
  example reports exactly once, under the intended rule and no other,
  per the stated precedence rules; each fix example reports nothing
  under either new rule.

All six `claude-plugins` test suites pass (142 assertions, unchanged).
`claude-plugins`'s own `git status` stayed clean throughout (no code
change needed there, per Reading above). `scripts/check-unshipped.sh`
clean on `claude-plugins` before any release step (nothing pending
there yet).

Committed on `software-english`'s `main`, message ends `closes #12`.
Released: `release.yml` run with `version: 0.0.20` (newest prior tag
v0.0.19). Because the change touches `rules/core-rules.toml` (a file
`swe` fetches): bumped `claude-plugins/swe/software-english.json`'s
`tag` to `v0.0.20` and `swe`'s own `plugin.json` version, committed and
pushed on `claude-plugins` `main`, ran `release-plugin.yml` with
`plugin: swe`.

(Commit hashes, release run links, and tag links recorded once the
ship/release steps complete; this file is written ahead of that step
per `MAINTAINER-RUN.md` step 4, and updated again at step 9.)

Single pass, no escalation, so far.
