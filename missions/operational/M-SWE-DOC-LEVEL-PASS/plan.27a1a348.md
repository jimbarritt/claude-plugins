# Plan: claude-plugins#23 — lint-file document-level pass

## The ask, verbatim

> ## Problem
>
> `/swe:lint-file` judges a file one prose unit at a time: each heading,
> paragraph, list item and table against each inference rule. On a long
> Design document (about 1,400 lines) the check reported about 50
> sentence-level warnings. The faults that made the document hard to read
> were at document level, and no rule reported them:
>
> - A decision record near the end of the document contradicted the body
>   sections it changed. Each record had a status marker of the form
>   "agreed, not yet reflected in the sections below", and the sections it
>   referred to were above it.
> - The document had no Summary section.
> - One argument was restated in three or four sections in different
>   words, for example the reason a type excludes a category of records.
> - A contents list of about 60 entries, down to the fourth heading level,
>   with bold group labels that matched no heading in the document.
> - A section about a component's events described a different
>   component's events first, at length, before it stated the subject's
>   own events.
> - A per-vendor comparison was spread across several paragraphs of prose
>   and fitted one table.
>
> Each fault spans several units, so a check that reads one unit at a time
> does not detect it.
>
> ## Proposal
>
> Add a Pass 3 to lint-file Step 4 that reads the whole document once,
> after Passes 1 and 2, and reports document-level findings at warning
> severity:
>
> 1. **Contradiction between sections.** A later section (a decision
>    record, a discussion point, an amendment) states a rule that an
>    earlier section contradicts, or a status marker states that a
>    decision is not yet applied to the body.
> 2. **Missing summary.** A Design document over a set length with no
>    Summary section (SPEC §7.1).
> 3. **Restated argument.** One argument or consequence stated in more
>    than one section (extends no-mechanical-repetition, SPEC §8.2, past
>    the bounds of one list or paragraph).
> 4. **Contents-list scale.** Covered in part by no-mechanical-repetition
>    today. Pass 3 would also report a contents entry that matches no
>    heading.
> 5. **Section order.** A section that describes a precedent from another
>    component before the subject's own facts.
>
> Example of item 1, with neutral subjects:
>
> > §3: "Every queue has at least one consumer, so the router never checks
> > for an empty queue."
> >
> > §9, decision Q-4: "Status: agreed, not yet reflected above. A queue
> > can have zero consumers; the router checks before it sends."
>
> Pass 3 would report §3 as contradicted by Q-4, and Q-4's status marker
> as stale.
>
> ## Notes
>
> - Item 4 and part of item 3 overlap with no-mechanical-repetition.
>   Pass 3 could report under that rule id where it applies.
> - Item 6 (prose that fits a table) can be hard to judge, and could be
>   left out of a first version.

Issue: https://github.com/jimbarritt/claude-plugins/issues/23

## Reading

`/swe:lint-file` is a skill, not a script: `swe/skills/lint-file/SKILL.md`
drives the model through Step 4's judgement. Step 4 currently runs two
per-unit passes (body, then headings). The script
`swe/scripts/software_english_lint.py` never judges anything — it only
prints the rules and the unit worklist — so this is a text-only change to
the skill instructions, scoped to `claude-plugins`. It needs no change to
the `software-english` SPEC repo to ship, because:

- Items 3 and 4 (scale half) are already covered by the catalogued rule
  `no-mechanical-repetition` (SPEC §8.2).
- Item 4's "entry matches no heading" is `no-unanchored-reference`
  (SPEC §7.5), not repetition — a reference with no referent.
- Items 1, 2 and 5 have no catalogue rule id. SPEC §7.1 ("Summary before
  detail") exists for item 2 but is uncatalogued; items 1 and 5 have no
  SPEC section at all. These three get skill-local rule ids, documented in
  SKILL.md as lint-file's own, not from the fetched catalogue. Proposing
  them upstream in `software-english` is optional follow-up, not a
  blocker.

All Pass 3 findings are `warning` severity and never change the Step 5
error count or the Step 6 verdict, matching the issue's proposal and
keeping the false-positive risk of a cross-document judgement off the
pass/fail gate.

## Decisions taken (unattended run — each has a default, none blocks)

- **D1. Rule ids.** Item 3 → `no-mechanical-repetition`. Item 4 scale →
  `no-mechanical-repetition`. Item 4 unmatched entry → `no-unanchored-reference`
  (departs from the issue's note, which suggested repetition; the
  anchored-reference rule fits the fault better). Item 1 → new
  `no-contradiction-between-sections`. Item 2 → new `summary-before-detail`
  (named after SPEC §7.1). Item 5 → new `no-precedent-before-subject`.
- **D2. Missing-summary scope.** Design and API Design documents only
  (per the issue's wording), at 300 lines or more (SPEC §8.2's own
  threshold, the only length threshold in the SPEC). Satisfied by a
  Summary heading, or an opening paragraph before the first section
  heading stating what the document decides or describes.
- **D3. When Pass 3 runs.** Markdown files with at least two section
  headings; skipped otherwise, the same way Pass 2 is skipped. Runs
  regardless of whether Passes 1–2 found violations.
- **D4. Anchoring.** Each finding sits at the line of the later/offending
  unit and names the other location by line and heading text. A
  contradiction yields two findings: one at the earlier, contradicted
  sentence, one at the stale status marker (when present).
- **D5. Severity.** Always `warning`, even for findings under a
  catalogued rule id — cross-document judgement carries higher
  false-positive risk, so it never joins the error count.

## Open questions (none blocking; defaults above apply)

- Q1: does `summary-before-detail` apply to every document type over the
  threshold (SPEC §7.1's own wording) or only Design/API Design (the
  issue's wording)? Default: Design/API Design only.
- Q2: is 300 lines the right missing-summary threshold? Default: yes,
  borrowed from §8.2.
- Q3: contents-entry-with-no-heading under `no-unanchored-reference` or
  `no-mechanical-repetition`? Default: `no-unanchored-reference`.
- Q4: should the three skill-local ids be catalogued upstream in
  `software-english`? Out of scope for this task; optional follow-up
  issue only.
- Q5: no automated test can check model judgement; the regression test
  checks SKILL.md structure only, behaviour rests on a manual check.

## Plan (ordered; one task per step)

1. Draft the `### Pass 3: the whole document` subsection in
   `swe/skills/lint-file/SKILL.md`, between the existing Pass 2 and
   `## Step 5`: opening statement, skip conditions (D3), the five checks
   with rule ids (D1), anchors (D4), severity (D5), and a closing note
   that Pass 3 never changes the error count or the units-judged figure.
   Leave out item 6 (table-shaped prose) entirely, per the issue's own
   note.
2. Update the surrounding references in the same file: Step 4's opening
   ("two passes" → "three passes"), Pass 2's "both passes" line, Step 5's
   error-count sentence, Step 6's "both passes" → "all three passes".
   Done when `grep -n "both passes\|two passes" swe/skills/lint-file/SKILL.md`
   returns nothing.
3. Update `swe/docs/agent-guide.md`: the "two passes" description near
   line 272, and the limitations list near line 669 (add: the three
   skill-local ids are not in the `software-english` catalogue; item 6 is
   not checked).
4. Update `swe/README.md`'s "Check one file on demand" section: one
   sentence noting the whole-document pass and what it reports, after the
   existing per-unit-pass description.
5. Add a structural regression test, `swe/tests/lint_file_pass3_test.sh`
   (style of `swe/tests/skill_frontmatter_test.sh`): asserts the
   `### Pass 3` heading sits between `### Pass 2` and `## Step 5`, names
   all five rule ids, names `warning` severity, and that Step 6 no longer
   says "both passes". Run all `swe/tests/*.sh`; all must pass.
6. Manual validation: build a >300-line sample Design document in the
   scratchpad (outside the repo) with one instance of each of the five
   faults, plus a clean control document. Load the edited working tree
   (`claude --plugin-dir /home/user/claude-plugins/swe`, since the
   installed `swe:lint-file` is the released version) and confirm each
   fault is reported once, under the expected id and line, and the
   control document gets no Pass 3 finding. Do not commit the fixtures.
7. Self-lint: run `/swe:lint-file` on the changed prose
   (`SKILL.md`, `README.md`) and fix any finding. `agent-guide.md` is
   exempt via `.swe-ignore`.
8. Ship: bump `version` in `swe/.claude-plugin/plugin.json` (minor bump —
   new user-visible check), commit to `main` with `closes #23`, push, run
   `release-plugin.yml` for `swe`, then `scripts/check-unshipped.sh`.
9. Optional, non-blocking follow-up: file a `software-english` issue
   proposing upstream catalogue entries for SPEC §7.1, contradiction
   between sections, and precedent-before-subject order.

## Critical files

- `swe/skills/lint-file/SKILL.md`
- `swe/docs/agent-guide.md`
- `swe/README.md`
- `swe/.claude-plugin/plugin.json`
- `swe/tests/skill_frontmatter_test.sh` (pattern for the new test)
- `scripts/check-unshipped.sh`
- Reference only (software-english, not changed): `rules/core-rules.toml`,
  `spec/SPEC.md` §7.1, §8.2.
