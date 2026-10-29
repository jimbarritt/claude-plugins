# Plan: software-english#25 — navigational meta-remark false negative

## The ask (verbatim)

Title: False negative: navigational meta-remark that announces the next section and states no fact

```
## Verdict

False negative, no current rule fired. Found by reading a procedural
guide, with current rule data, on both tiers.

## Shape

A sentence that announces where the document turns to a subject, and
states no fact about the subject:

- "This is where the signing certificate comes in."
- "Here is where the retry limit matters."
- "That is what the next section is for."

The SPEC covers remarks about the writing itself ("the short version",
"as noted above"). These sentences are the same fault in a navigational
form: they refer to the document's own sequence, not to the system.

## Proposed fix

- Extend `no-framing-device` (or the SPEC's meta-remark guidance, if
  that is a better home) with a fourth shape: a navigational
  announcement, signatures "this is where X comes in", "here is where X
  matters", "that is what <section> is for".
- **Fix:** delete the sentence, or replace it with the fact the next
  section starts with ("The service signs each request with the
  certificate from step 2.").
- **Not this fault:** a cross-reference that names where a fact is
  stated ("§4 lists the retry limits"); a heading.
- Consider adding "comes in" (sense: becomes relevant) to `banned.tsv`.
```

URL: https://github.com/jimbarritt/software-english/issues/25

## Our reading

The issue proposes two possible homes: extend `no-framing-device`
(§5.10), or the SPEC's existing meta-remark guidance (§5.3, "a remark
about the writing itself"). Checking the actual code and spec:

- `no-framing-device` has no `trigger_phrases` consumed by the linter
  (the linter only ever prints the rule's `description` to the judging
  model). Its own fault definition is "a frame that wraps a fact", with
  a fix that is always the plain clause. A navigational announcement
  wraps no fact: rewriting "that is what the next section is for" to
  its plain clause ("the next section is for that") still states
  nothing about the system. Putting this fault under §5.10 would give
  that rule a fix that does not fit its own definition.
- §5.3 already names this fault family ("a remark about the writing
  itself") but today has no catalogue entry (no rule id) for it — only
  fixed phrases in `vocabulary/banned.tsv`. The precedent for closing
  exactly this kind of gap is `M-SWE-READER-REACTION-RULE`
  (software-english#24), which catalogued §5.3's *second* fault
  (reader-reaction prediction) the same way: a new inference-based rule
  id, with the SPEC prose rewritten to introduce it, trigger phrases
  that are not already in banned.tsv, and cross-references to keep it
  from double-firing against neighbouring rules.
- Two of the issue's three example sentences already fire today, with
  the *wrong* fix: "comes in" matches the anthropomorphism fixed list
  (`comes`) and "matters" matches a banned.tsv entry whose fix is "state
  the consequence" — neither fix is "delete the sentence / state the
  next part's fact". Adding "comes in"/"come in" to banned.tsv (as the
  issue suggests) corrects the first case directly, since banned-word
  claims a span before the anthropomorphism list does.

**Decision: home is (b) — a new inference-based rule,
`no-remark-about-the-writing`, under §5.3**, catalouging the SPEC's
existing third fault (remark about the writing), with the navigational
announcement as one named form, mirroring how #24 catalogued the second
fault. Not a fourth shape of §5.10, for the reason above.

## Plan

### 1. `spec/SPEC.md` §5.3 — replace the closing "no catalogue entry" paragraph

Replace the paragraph "The editorial judgement and the remark about the
writing have no catalogue entry of their own..." with new prose that:
introduces the navigational-announcement form with the issue's three
examples, states the fix (delete, or state the next part's first fact),
gives a delete-and-check test, lists "not this fault" cases (a
cross-reference that names where a fact is stated; a fact with a link to
its source; a go-to-step-N instruction in a How-to/Tutorial; a heading,
deferred to §7.17; quoted material), names the deterministic-tier fixed
list (banned.tsv's meta-commentary/text-shape entries, now including
"comes in"/"come in"), names the new inference-tier rule id
`no-remark-about-the-writing`, and closes with a "nearby claim"
cross-reference list (§5.10 cleft overlap; §7.17 headings-only split;
§7.1 summary-before-detail; §7.6 count signposting; §8.3 distributive
tail) — then keeps one closing sentence: "The editorial judgement has no
catalogue entry of its own. Its common fixed phrases are in
vocabulary/banned.tsv."

### 2. `spec/SPEC.md` §5.10 — one new cross-reference bullet

Add a bullet to the existing "Other rules have a nearby claim" list:
a cleft whose plain clause still states no fact about the system is a
§5.3 `no-remark-about-the-writing` finding, not a §5.10 finding, since
the fix there deletes the sentence rather than keeping a plain clause.

### 3. `rules/core-rules.toml`

- Add a new `[[rules]]` block, id `no-remark-about-the-writing`,
  tier inference-based, check model-judgement, severity warning,
  `trigger_phrases` covering the navigational signatures ("this is
  where", "here is where", "that is where", "this is what", "that is
  what", "comes in", "come in", "the next section is for"), and a full
  `description` (the text the linter hands the judging model) covering:
  the fault, the three example sentences, the fix, the test, the "not
  this fault" list, the fixed-list/inference-tier split, and "Distinct
  from ..." sentences for `no-framing-device`,
  `no-reader-reaction-prediction`, `no-withholding-heading`,
  `summary-before-detail`, and `no-distributive-tail`.
- Extend the `no-framing-device` description with one "Distinct from
  no-remark-about-the-writing" sentence.
- Extend the `no-reader-reaction-prediction` description with one
  "Distinct from no-remark-about-the-writing" sentence.
- Extend the `anthropomorphism-fixed-list` description noting that
  "comes in"/"come in" are now banned-word entries, so banned-word
  claims that span first and this rule does not also report "comes"/
  "come" inside it (matches existing `check_line` precedence behaviour).

### 4. `vocabulary/banned.tsv`

Add two lines under the `# Meta-commentary on the writing` heading:
`comes in	CUT, or state the fact` and `come in	CUT, or state the fact`.
Not adding "this is where"/"here is where" (each has a literal, correct
use — e.g. naming a real location) or "matters" (already banned) or
"came in" (mostly narrative past tense). No existing hit for either
phrase in either repository today.

### 5. Other files

- `COLOPHON.md`: append a short section in the same style as the #24
  entry, explaining the fault, why it is a §5.3 catalogue entry and not
  a §5.10 shape, and the banned.tsv addition.
- Intro deck (`docs/public/presentations/intro/intro-to-software-english.md`
  and its built `html`): bump the stated rule counts ("34 inference" →
  "35 inference", "40 rules" → "41 rules"). Rebuild the PDF with
  `./build.sh` if the toolchain (node/npx/Playwright/Chromium) is
  available in this session; otherwise update the md/html by hand and
  note the PDF is stale in the report.
- Appendix A and `docs/claude-md-ruleset.md`: no change (neither lists
  individual rules).
- `claude-plugins`: no code change needed — the linter reads
  `core-rules.toml`/`banned.tsv` directly, so the new rule reaches the
  model through its description with no duplicate catalogue entry
  elsewhere. A `swe` release is still needed afterward (this change
  touches both `rules/core-rules.toml` and `vocabulary/`), handled at
  the Release step, not part of this plan.

### Verification before shipping

- Parse `rules/core-rules.toml` with Python's `tomllib` and confirm it
  still parses, with one more `[[rules]]` entry than before.
- Run the linter (via claude-plugins' `swe` scripts, pointed at a local
  copy of the edited data, or by hand-checking the matched phrases) on
  the issue's three example sentences and confirm banned-word now
  claims "comes in" and "matters" ahead of the anthropomorphism list.
- Lint the changed SPEC.md and COLOPHON.md prose with `/swe:lint-file`.
