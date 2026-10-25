# software-english #10 and #11: PR Description document type

Both issues ask for the same feature. The claim rule picked #10
(oldest by creation date); #11's spec is the one actually
implemented, since it is far more concrete.

## #10 ask, verbatim

> A pull request description should be a recognised document type,
> with its own guidance, rather than prose that happens to pass the
> general lint.
>
> The purpose of the type is to make it as clear as possible to a
> human reader what is going on in the change: what the gap was,
> what the change does, and what a reader cannot recover from the
> diff.
>
> ## Motivating case
>
> A PR description needed roughly six correction passes. The
> deterministic tier reported CLEAN throughout, while sentences
> remained meaningless to a reader. One survivor of several passes:
>
> > It reports four counts, and a reason where the sync itself
> > stopped.
>
> Two faults in one sentence, neither of which any rule covers:
> "where" standing in for a conditional, and a list of four things
> the sentence never names. The clean lint result stood in for the
> judgement of whether the sentences meant anything, and each
> flagged line was patched in isolation rather than the whole
> document being read once as a reader would read it.
>
> ## Direction
>
> Add `PR Description` to the document-type set, so the linter
> recognises one and applies type-specific rules. The guidance
> should state at least:
>
> - The description is written for a reader who has not seen the
>   diff.
> - It says what cannot be recovered from the diff: why this shape,
>   what was rejected, what could not be verified. Not a narrative
>   of how the change was arrived at.
> - The whole document is read end to end before it is presented,
>   not just the lines a previous pass flagged.
> - A clean deterministic-tier result is necessary, not sufficient.
>
> The exact format can be refined later. Something basic in place
> first is worth more than waiting for the right shape.

## #11 ask, verbatim

> ## The gap
>
> `document-type-template` assigns a document its target type from
> Appendix F: RFC, ADR, Design, API Design, Specification, Technical
> Manual, and the rest. A pull request description is not among
> them, so the rule assigns it nothing, and every rule conditioned on
> document type stays silent on it.
>
> That matters more for this type than for most. A PR description is
> written under time pressure, read by someone deciding whether to
> approve a change, and its two load-bearing sections are a problem
> statement and a record of what was verified. Both have a failure
> mode the general sentence-level rules do not reliably catch.
>
> ## Observed
>
> Writing a PR description with the linter in the loop, the
> deterministic tier passed an opening problem statement of this
> shape:
>
> > The record written to the downstream system held no evidence.
>
> Nothing in it names an artefact. The thing missing was a file
> attached to a record, and the sentence says "evidence" instead.
> `no-mechanism-for-outcome` covers the fault in principle, but it is
> inference-tier, and nothing in the type assignment raises the bar
> for the one sentence in the document that most needs to be
> concrete.
>
> ## Asks
>
> **1. Name the type.** Add PR description to Appendix F with a
> canonical structure, and a `templates/pull-request.md` alongside
> the existing templates. Decision state separates it from its
> neighbours: an ADR records one decision taken, a Design document
> holds several with some still open, and a PR description states a
> change already made and the evidence that it works.
>
> **2. A problem statement names the artefact.** Conditioned on the
> type, inference-tier. A problem statement that uses an abstract
> stand-in ("evidence", "context", "visibility", "coverage",
> "insight") where a file, a field, a record or a request is meant,
> is a fault. Rewrite:
>
> > Before: the report gave the operator no visibility.
> > After: the report listed no failed orders.
>
> Judging whether a noun stands in for a concrete artefact needs a
> model, so this cannot be a banned-word entry: each of those nouns
> is correct where the thing named really is abstract.
>
> **3. A verification line pairs a command with its result.**
> Conditioned on the type, inference-tier. A command listed with no
> outcome reads as evidence and is not:
>
> > Before: `make test`
> > After: `make test`: passed, 212 tests
>
> A section listing what was not run is correct content under this
> type and must not fire.
>
> ## Not asked for
>
> No change to the sentence-level rules themselves. Both proposed
> rules are conditioned on the type and fire nowhere else.

## Reading

Two issues, same gap, different detail levels. #10 names the
motivating failure (a PR description passing the deterministic tier
clean while a sentence stated nothing: an unnamed count, and
"where" standing in for a condition) and a loose direction. #11
names a second, distinct failure in the same document shape (an
abstract noun standing in for a missing artefact) and gives a
concrete, implementable design: name the type in Appendix F, add two
type-conditioned inference-tier rules.

Decided to work both together rather than pick one: implementing
#11's design satisfies #10's direction in full, and #10's own
"unnamed count" example is a variant of the same underlying fault as
#11's "abstract stand-in", so one rule covers both rather than two.

## Plan

An Opus Plan subagent read both issues in full, the existing
Appendix F rollout pattern (`templates/design.md`,
`no-planning-content-in-reference`, `no-work-breakdown-or-tracker-pointer`,
`no-mechanism-for-outcome`), confirmed the five candidate stand-in
nouns are not already banned words, and designed the full change:
one new document type, one template, two new rules, and the
cross-reference edits to existing type-conditioned rules. It flagged
eleven judgement calls (D1 to D11) rather than deciding them
silently; the two load-bearing ones taken without asking, since this
is an unattended run:

- **D3 (taken):** the new rule `no-abstract-stand-in-for-artefact`
  covers the change statement and an unnamed-count shape, not only
  the problem statement #11 names, so #10's own "It reports four
  counts" example is covered rather than left as a gap for a later
  issue.
- **D5 (taken):** `no-check-without-result` covers a manual-step
  check and a ticked checkbox, not only a command, since a
  verification line that names no check at all ("Tested locally.")
  is the same fault in spirit.

One plan limit, named by the plan itself: the network proxy refused
`google.github.io`, `kernel.org`, and `docs.github.com`, so the three
cited canonical sources (Google's CL-description guide, the Linux
kernel's "Submitting patches", GitHub's closing-keyword docs) were
not fetched and checked against the drafted paraphrase; confirmed
again directly in this session (same three hosts unreachable).
Proceeded on the paraphrase as drafted, since all three are
well-established, stable public documents and the paraphrase states
only well-known, uncontroversial facts about each (that a changelist
description states the problem and the approach; that the kernel
asks for a self-contained commit log; that GitHub recognises a
closing keyword in PR text). Flagged here in case a future reader
wants to verify the exact wording against the live pages.

## What shipped

- **`spec/SPEC.md`:** Contents list entries for §7.15/§7.16; §7.8's
  type list; §7.14's "every document type" line and a third
  exception for a PR-description closing-keyword line; new §7.15 "No
  abstract stand-in for an artefact" and §7.16 "No check without its
  result"; Appendix F table row and narrative paragraph; the
  "convergent convention" sentence widened to include PR
  Description.
- **`rules/core-rules.toml`:** `document-type-template` and
  `no-work-breakdown-or-tracker-pointer` descriptions updated to name
  the type; two new rule entries, `no-abstract-stand-in-for-artefact`
  and `no-check-without-result`, both inference-based,
  `model-judgement`, `warning`, `applies_to_document_type =
  "pr-description"` (documentation only, consistent with the one
  existing use on `no-planning-content-in-reference`; no code reads
  this key).
- **`templates/pull-request.md`:** new local reference, following
  `templates/design.md`'s pattern (Canonical sources, What a PR
  description is, Structural conventions, two Software-English-own
  addition sections, Other rules that apply, How this differs from
  the neighbouring types, Verify against the source).
- **`COLOPHON.md`:** new section recording why the two rules are
  conditional, why they sit after §7.14 rather than beside §7.9 (the
  same renumbering reason §7.14 itself gives), and the convergent-
  convention sourcing decision; `no-work-breakdown-or-tracker-pointer`
  summary line updated to name PR Description.
- **`README.md`:** "Fourteen" -> "Fifteen" types; PR Description
  added to the type list.

One self-check catch during drafting, found only by running the real
linter, not by reading the prose back: "really" (a banned word) used
three times across `templates/pull-request.md`, `spec/SPEC.md`, and
`rules/core-rules.toml` ("the thing named really is abstract"),
fixed to "is itself abstract". A second catch, also real linter
output: "stands in for"/"standing in for" in the new §7.15 prose and
its TOML description tripped the deterministic `abstract-location`
rule for real (an abstract-subject "noun"/"that" followed by the
location verb "stands" within its 4-word lookback), the exact fault
that rule targets, not a false positive; reworded to "used in place
of" in both places, and "stand-in" (a different COLOPHON.md
sentence, a compound-noun use that still matched the word list) to
"substitute".

Verified directly against the real linter throughout. `--diff
--added-only` against the whole `software-english` working tree (4
changed/added markdown files) reports 0 errors on every newly added
line. Per-file before/after error counts, run with the edited
`rules/core-rules.toml` and `vocabulary/*.tsv` copied into
`claude-plugins/swe/data/` (the local-fixture technique prior
sessions used, since `swe` is not installed as a skill in this
session): `SPEC.md` 19 -> 19 (one new error introduced by "really"
and caught in the same pass, then the "stands in" catch, both fixed
before this count), `COLOPHON.md` 1 -> 1, `README.md` 2 -> 2 (its two
pre-existing errors are the `templates/`-count sentence's "hold",
untouched). `templates/pull-request.md` is new, so no baseline:
0 errors on first write (apart from the one "really" catch), 318
vocabulary-membership warnings (never blocking, the seed-vocabulary
set). `python3 -c "import tomllib; tomllib.load(...)"` confirms the
edited TOML still parses; manual grep of every new sentence across
all four touched files for the fixed banned-word list and for em
dashes, confirming none beyond the one real catch above. All six
`claude-plugins` test suites pass (142 assertions, unchanged), run
twice: once against a local-fixture copy of the edited files, and
again against the real fetched `v0.0.19` tag after release, to
confirm the released data itself works end to end, not only the
working copy.

Shipped on `software-english`'s `main` at
[`76d9954`](https://github.com/jimbarritt/software-english/commit/76d9954),
released as
[`v0.0.19`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.19),
which closed both issues automatically (`Closes #10`, `Closes #11`
trailers). `claude-plugins` pin bumped and `swe` version bumped
(`0.17.9` -> `0.17.10`) on `main` at
[`3ed3ab4`](https://github.com/jimbarritt/claude-plugins/commit/3ed3ab4),
released as
[`swe-v0.17.10`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.17.10).
`scripts/check-unshipped.sh` confirms `swe` is released, after a
local `git fetch --tags` (the check reads local tags only; a fresh
clone has none until fetched).

Single pass, no escalation. `agent:working` label removed from #10
on close.

## Open, not filed

#10's own example sentence uses "where" standing in for a
conditional ("a reason where the sync itself stopped"). No existing
or new rule covers this; it is a sentence-level fault that would
apply to every document type, and both issues' "not asked for" lines
rule out a sentence-level change here. Shown only as a worked example
in `templates/pull-request.md`'s "read the whole description" section,
not covered by a rule. A candidate for a future issue, not filed
separately (one-issue-per-run).
