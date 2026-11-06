# Report: claude-plugins#23 — lint-file document-level pass

## Outcome

Shipped. Commit
[3a6aa7d](https://github.com/jimbarritt/claude-plugins/commit/3a6aa7d448e37dda660aa5666053d25c22512e91)
on `main`, closing claude-plugins#23. Released as `swe-v0.24.0` via
`release-plugin.yml` run
[40709261998](https://github.com/jimbarritt/claude-plugins/actions/runs/40709261998)
(success). `scripts/check-unshipped.sh` confirms `swe` 0.24.0 matches
tag `swe-v0.24.0`.

Filed a non-blocking follow-up,
[software-english#22](https://github.com/jimbarritt/software-english/issues/22),
proposing upstream catalogue entries for the three skill-local rule
ids this change introduces.

## What changed

- `swe/skills/lint-file/SKILL.md`: added `### Pass 3: the whole
  document` to Step 4, after Pass 2 and before Step 5. It reads the
  file once more, end to end, after Passes 1 and 2, and reports five
  checks at `warning` severity (never affecting the Step 5 error
  count or the Step 6 verdict):
  - `[no-contradiction-between-sections]` (new, skill-local)
  - `[summary-before-detail]`, SPEC §7.1 (new, skill-local)
  - `[no-mechanical-repetition]`, SPEC §8.2, extended across sections
    (catalogued)
  - contents list: `[no-mechanical-repetition]` for scale,
    `[no-unanchored-reference]` (SPEC §7.5) for an entry or bold
    group label matching no heading (both catalogued)
  - `[no-precedent-before-subject]` (new, skill-local)

  Also updated the surrounding text: Step 4's opening ("two passes" →
  "three passes"), Pass 2's closing line, Step 5's error-count and
  units-judged notes, and Step 6's verdict line, so none still claims
  only two passes exist.
- `swe/docs/agent-guide.md`: updated the "two passes" description of
  `/swe:lint-file`'s judgement to three, and updated the limitations
  list — split the stale claim that heading faults have no catalogue
  rule (§7.17/§7.18 now exist) from the genuinely new limitation (the
  three skill-local Pass 3 ids, and that prose-fits-a-table, issue
  item 6, is left out).
- `swe/README.md`: added one sentence to "Check one file on demand"
  describing the whole-document pass and what it reports.
- `swe/tests/lint_file_pass3_test.sh`: new structural regression test
  (14 assertions): the `### Pass 3` heading sits between `### Pass 2`
  and `## Step 5`, all five rule ids are named, `warning` severity is
  stated, and no "both passes"/"two passes" text remains. All
  `swe/tests/*.sh` pass (12 files).
- `swe/.claude-plugin/plugin.json`: version `0.23.1` → `0.24.0` (minor
  bump — a new user-visible check).

Item 6 from the issue (prose that would fit a table) is left out
entirely, per the issue's own note.

## Decisions taken (unattended run; full detail in `plan.md`)

- D1: rule-id assignment above; departs from the issue's note on one
  point — a contents entry with no matching heading is
  `no-unanchored-reference` (a reference with no referent), not
  `no-mechanical-repetition`, because it is not a repetition fault.
- D2: `summary-before-detail` scoped to Design/API Design documents,
  300+ lines (SPEC §8.2's own threshold, borrowed for lack of a
  stated one).
- D3: Pass 3 skipped for a non-Markdown file or one with fewer than
  two headings; runs regardless of Pass 1/2 findings.
- D4: anchoring — each finding at the later/offending unit's line,
  naming the other location by line and heading; a contradiction
  yields two findings (the earlier sentence, the stale marker).
- D5: all Pass 3 findings are `warning`, even under a catalogued rule
  id, and never join the error count.

## Validation

- `scripts/check-unshipped.sh`: exit 0, confirms release.
- All 12 `swe/tests/*.sh` suites pass, including the new
  `lint_file_pass3_test.sh`.
- Self-lint: ran `/swe:lint-file` on the changed `SKILL.md` and
  `README.md`. Fixed four deterministic `no-em-dash` findings and two
  `anthropomorphism` findings (`asks`, `decides`) introduced by the
  first draft of the new prose. Re-ran to confirm a clean deterministic
  tier; reviewed the new text by hand against the inference-pending
  rules most likely to apply (catch-all-verb, vacuous-classification,
  framing-device, no-unanchored-reference, no-count-list-mismatch) and
  found nothing further. Did not re-judge the whole pre-existing
  SKILL.md body, which this change does not touch, against the full
  inference tier — out of proportion for an unattended run.
- Manual validation (not committed; built in the session scratchpad):
  constructed a 305-line sample Design document
  (`sample_fault.md`) carrying one instance of each of the five
  faults (the issue's own queue/consumer contradiction example, no
  Summary, one argument restated across three sections, three
  mismatched bold contents labels, and a Router-events section that
  opens with a different service's events), and a 290-line clean
  control document (`sample_control.md`) with none of them. Followed
  the edited SKILL.md's Pass 3 instructions by hand (as the acting
  model, since the installed `/swe:lint-file` only runs the released
  0.23.1 text) against both:
  - all five checks fired correctly on the fault document, at the
    expected lines;
  - the control document produced no Pass 3 finding;
  - the contents-list *scale* sub-check (as against the *unmatched
    entry* sub-check, which fired cleanly) was genuinely ambiguous on
    the fault document, because most of its listed subsections are
    also cross-referenced by number elsewhere in the body. This is
    exactly the kind of judgement call Pass 3's own text defers to the
    model; it is not a defect in the instructions.

No automated test can check the model judgement Pass 3 asks for — see
open question Q5 in `plan.md`. The regression test checks SKILL.md's
structure only; this manual pass is the behavioural check.

## Open questions left unresolved (non-blocking; defaults applied)

See `plan.md`'s Q1–Q5 and the ledger's recorded decisions. None
blocked shipping.
