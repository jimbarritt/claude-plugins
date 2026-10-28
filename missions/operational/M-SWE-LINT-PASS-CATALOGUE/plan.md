# Plan: M-SWE-LINT-PASS-CATALOGUE (software-english#22)

## The ask (verbatim)

**Title:** Catalogue entries for three skill-local lint-file Pass 3 rules

**Body:**

Follow-up to claude-plugins#23, shipped as `swe-v0.24.0`.

`/swe:lint-file`'s new Pass 3 (the whole-document pass) uses three rule
ids that are not in this repository's catalogue, defined only in the
skill text at `swe/skills/lint-file/SKILL.md` (in `jimbarritt/claude-plugins`):

- `no-contradiction-between-sections` — a later section (a decision
  record, a discussion point, an amendment) contradicts an earlier one,
  or a status marker states a decision is agreed but not yet applied to
  the body. No SPEC section currently covers this.
- `summary-before-detail` — SPEC §7.1 ("Summary before detail") already
  exists but has no catalogue rule id in `rules/core-rules.toml`.
- `no-precedent-before-subject` — a section describes another component
  or precedent at length before its own subject's facts. No SPEC section
  currently covers this.

Proposal: add catalogue entries (and, where needed, SPEC sections) for
these three, so lint-file can switch from its own skill-local ids to the
shared catalogue. Not blocking: lint-file ships and works today with its
own ids.

## Reading

Scope is `software-english` only: add the catalogue entries and the two
missing SPEC sections. Switching `claude-plugins`' SKILL.md over to the
new ids, releasing a new software-english tag, and bumping the `swe`
plugin's pin are all out of scope for this issue — the issue's own text
is forward-looking ("so lint-file can switch") and says lint-file "ships
and works today with its own ids". That follow-up needs its own
claude-plugins issue and mission.

## Findings from the repo

- No test suite, Makefile, `scripts/`, or CI validation exists in
  `software-english`. The only CI is a manual release workflow. "Done"
  means: the TOML parses, ids are unique, SPEC Contents links match the
  new headings, every `§N` cross-reference exists, and the new prose
  obeys Software English itself (checked by inspection and, if available,
  by running `software_english_lint.py` against the touched files).
- `claude-plugins/swe/software-english.json` pins the tag the `swe`
  plugin fetches (`v0.0.27` at time of writing). A `software-english`
  commit has no effect on lint-file until a release is cut and the pin
  bumped — explicitly out of scope here (issue #22 is software-english
  only).
- Prior rule-adding commits (e.g. the §7.17–§7.20 additions) touch
  `rules/core-rules.toml`, `spec/SPEC.md`, and `COLOPHON.md` together,
  and append new §7 rules at the end of §7 rather than beside a sibling,
  to avoid renumbering sections the catalogue and Contents cite by
  number.
- Appendix A of SPEC.md needs no change: it is a pointer to
  `rules/core-rules.toml`, not a per-rule listing.

## Decisions

- **Numbering.** §7.1 keeps its number and is expanded in place. New
  §7.21 "No contradiction between sections" and §7.22 "No precedent
  before its subject" are appended after §7.20, before `## 8. Register
  rules` (not inserted beside a sibling, per the COLOPHON convention).
- **Tier/check.** All three: `tier = "inference-based"`,
  `check = "model-judgement"`. None is deterministic: a parser can find
  a candidate (a status marker's wording, the text before the first
  heading, a section's paragraphs), but judging contradiction, whether a
  summary states the main fact, or which subject a paragraph describes
  all need a model, per SPEC §2's test for the deterministic tier.
- **Severity.** All three `warning`. For `no-contradiction-between-sections`
  specifically (the close call, since two contradicting statements
  include a false fact, the reason §7.20 is `error`): kept at `warning`
  because the fault spans sections rather than sitting inside one
  sentence a count can check, the false-positive risk (scoped rules,
  named exceptions, recorded history all read as contradictions until
  judged) is high, and lint-file's Pass 3 already promises it "adds only
  warnings".
- **§7.1 generalised.** The SPEC/catalogue rule states the general case
  (every document type, any length, with a defined summary position and
  two faults: no summary, and a summary that names only the subject).
  lint-file's own "Design/API Design, 300+ lines" trigger stays as the
  tool's narrower Pass 3 heuristic, unchanged by this mission, the same
  pattern Pass 3 already uses for §8.2 and §7.5.
- **Cross-references** are added only where real semantic overlap was
  confirmed by reading the full existing entries (§7.20, §8.2, §7.7,
  §7.9, §7.10, §7.1, §5.5, §3.3) — see the drafted prose below for each
  rule's "Other rules have a nearby claim" / "Distinct from" section.
- **TOML placement.** Append all three entries after `no-count-list-mismatch`
  and before `[exemptions]`, in SPEC order (§7.1, §7.21, §7.22), with no
  new schema keys.

## Out of scope (recorded, to go in the issue-closing comment)

- Changing `claude-plugins/swe/skills/lint-file/SKILL.md` to use the new
  catalogue ids instead of its own (SKILL.md lines 160–204). Needs its
  own claude-plugins issue/mission.
- Cutting a new software-english release tag and bumping
  `swe/software-english.json`'s pin.
- Whether the three rules' `check = "model-judgement"` causes them to
  also print in Pass 1/Pass 2's "inference pending" lists once the pin
  bumps (a possible future `scope = "document"` schema key). Follow-up's
  concern.
- Optional deterministic candidate detectors for these three rules.
- Stale rule counts ("36 rules", "30 inference rules") in the intro
  slide deck — needs a deck rebuild, unrelated to this change.
- Appendix A's pre-existing inaccuracy about which tiers get catalogue
  entries.

## Drafted text

### SPEC.md Contents (after the §7.20 entry)

```
  - [7.21 No contradiction between sections](#721-no-contradiction-between-sections-inference-based)
  - [7.22 No precedent before its subject](#722-no-precedent-before-its-subject-inference-based)
```

### SPEC.md §7.1 (replace the body; keep the heading)

> A document opens with a summary before any detail (borrowed from
> Rust's documentation convention). The summary is one sentence or one
> short paragraph. It states the document's main fact: the decision, the
> description of its subject, or the result. A reader who stops after
> the summary still has that fact.
>
> The summary is the first paragraph before the first section heading,
> or the first paragraph of a first section headed Summary, Abstract,
> Overview, or Introduction. A title, a status line, a metadata block,
> or a contents list before it is front matter, not detail.
>
> Two faults. The first is no summary: the document opens with detail.
>
> Fault: a Design document whose first section, `Context and scope`,
> describes the current order pipeline for three paragraphs. The design
> itself first appears in the fourth section.
>
> Fix: add a paragraph before the first section heading that states the
> decision: "The order router sends each order to one of three regional
> queues, chosen by the delivery postcode."
>
> The second is a summary that names only the subject: an opening
> paragraph that states what the document covers, and no fact about it.
>
> Fault: "This document describes the retry policy for the order
> consumer."
>
> Fix: state the policy: "The order consumer retries each failed message
> three times with exponential backoff, then writes it to the
> dead-letter topic."
>
> Test: read the summary alone. If a reader cannot state the document's
> main fact from it, the document has this fault. Report it at line 1.
>
> Not this fault: a document whose type template (§7.8, Appendix F) puts
> another section first, where the title or a required opening section
> states the main fact (an ADR whose title names the decision, an RFC
> whose Abstract states it); a Lab Notebook or Portfolio Journal entry,
> whose template fixes the order of each entry's parts; a document of one
> paragraph, which is its own summary.
>
> §7.6 and §8.2 each exempt the summary this rule requires. §7.7: an
> opening paragraph that narrates how the decision was reached is not a
> summary — report under §7.7, and report this rule at line 1 where no
> summary states the main fact. §7.22 asks for the same order inside one
> section.
>
> A parser can find the text before the first heading, or a heading
> named Summary. Whether that text states the document's main fact needs
> judgement, so this stays inference-based.

### SPEC.md new §7.21 "No contradiction between sections (Inference-based)"

Full fault/fix/not-this-fault/cross-reference text as drafted (status
marker example §3/§9 Q-4; not-this-fault list covers named exceptions,
open questions, Alternatives-considered sections, changelog entries,
Lab Notebook corrections; distinguishes from §7.20, §8.2, §7.7, §7.9;
closes with the severity-justification paragraph on why this stays
`warning` unlike §7.20).

### SPEC.md new §7.22 "No precedent before its subject (Inference-based)"

Full fault/fix/not-this-fault/cross-reference text as drafted (order
consumer / billing service example; not-this-fault list covers one
paragraph of context, Prior-art/Alternatives-considered headings,
Context-and-scope/ADR-Context sections, descriptions after the subject's
own facts; distinguishes from §7.10, §7.1, §5.5, §7.7, §3.3).

### `rules/core-rules.toml`: three new `[[rules]]` entries

`summary-before-detail`, `no-contradiction-between-sections`,
`no-precedent-before-subject` — each `tier = "inference-based"`,
`check = "model-judgement"`, `severity = "warning"`, with a full
house-style `description` string (fault/fix examples, judge-in-two-steps,
not-this-fault list, cross-references by SPEC section, tier
justification). Full text as drafted by the planning subagent.

### `COLOPHON.md`: new closing section

"Whole-document rules: three entries from a whole-file pass" — explains
why §7.1 kept its number, why §7.21/§7.22 are appended rather than
inserted beside a sibling, and why §7.21 stays `warning` unlike §7.20.

## Implementation steps

1. Expand SPEC §7.1 in `spec/SPEC.md` (keep heading, replace body).
2. Add SPEC §7.21 "No contradiction between sections" after §7.20, before `## 8. Register rules`.
3. Add SPEC §7.22 "No precedent before its subject" directly after §7.21.
4. Update the SPEC Contents list with both new entries.
5. Append the three `[[rules]]` entries to `rules/core-rules.toml`, after `no-count-list-mismatch`, before `[exemptions]`.
6. Append the COLOPHON.md section.
7. Verify the TOML parses, ids are unique, and the three new ids have the expected tier/check/severity (`tomllib` check).
8. Check SPEC consistency: both new headings exist, both Contents anchors match, every cited `§N` exists.
9. Check the new prose against Software English itself (no em dash; scan for banned words / anthropomorphism / abstract-location verbs on non-human subjects in the added lines; run `software_english_lint.py` on the touched files if practical).
10. Commit with `Closes #22`, covering the severity reasoning and the out-of-scope claude-plugins follow-up in the body.
11. Comment on the issue naming the commit, and naming the recommended claude-plugins follow-up issue (SKILL.md switch, tag release + pin bump, per-unit printing question, stale deck counts).

## Critical files

- `/home/user/software-english/spec/SPEC.md`
- `/home/user/software-english/rules/core-rules.toml`
- `/home/user/software-english/COLOPHON.md`
- `/home/user/claude-plugins/swe/skills/lint-file/SKILL.md` (reference only — not changed by this mission)
- `/home/user/claude-plugins/swe/scripts/software_english_lint.py` (reference only)
