# Report: claude-plugins#27

## Outcome

Fixed and released. Commit `d56ce5a0116b321f43c7760dc848aa0e4672b80d`
on `main`, `closes #27`. Released as `swe-v0.24.5` via
`release-plugin.yml` run 40753963678 (success). All three workflows
triggered by the push (`release-plugin.yml`, `swe-python-syntax.yml`,
`check-unshipped.yml`) completed successfully on this commit.
`scripts/check-unshipped.sh` confirms `0.24.5 is released and matches
swe-v0.24.5. Up to date.`

## What changed

`swe/scripts/software_english_lint.py`:

- Added `READABLE_SPAN` regex and `readable_line(line)`: renders
  `[text](target)` as `text (link: target)` (brackets gone, the model
  reads a resolved reference), keeps an inline code span verbatim with
  its backticks, blanks an HTML tag to one space, leaves bare URLs
  alone. Not same-length; used only by the new `readable=True` path.
- Added `readable=False` to `prose_lines()`: yields `readable_line()`
  output in place of `strip_noise()`'s blanked output, with identical
  skip logic (fences, indented blocks, blockquotes, skip markers), so
  line numbers match the existing blanked stream exactly.
- Added an optional `text_lines` parameter to `prose_units()`: block
  structure and line ranges still come from `register_blocks()` on the
  original blanked `numbered_lines`, unchanged; only each unit's own
  text is sourced from `text_lines` when given. A list item re-derives
  its text with `BULLET.match()` against the readable line, since
  `register_blocks()` had already stripped the bullet marker from the
  blanked text it stores.
- In `main()`, built a fourth `unit_lines` stream
  (`prose_lines(text, exemptions, readable=True)`) alongside the
  existing `numbered_lines`/`only_lines`/`code_lines`, made
  `candidate_input` a 4-tuple, and passed `unit_lines` into the
  `prose_units()` call that builds the `--force-inference` worklist.
  `lint_text()`, `strip_noise()`'s default blanking, `code_lines`, and
  `split_sentences()` are untouched.

`swe/skills/lint-file/SKILL.md` and `swe/docs/agent-guide.md`: noted
that a unit's `<text>` renders a link as `text (link: target)` and
keeps a code span verbatim.

`swe/tests/unit_worklist_test.sh`: added a fixture (`links.md`)
covering all three shapes from the issue plus two extra cases: an
in-document link, a code span as the sentence object, a list of code
spans as the subject (the #25 shape), a link inside a code span
(stays verbatim, not rewritten), and a heading with its own code span.
Added a deterministic-tier regression assertion: an unknown word
inside a code span ("orders") still produces no vocabulary-membership
finding when `--quiet-vocab` is dropped, proving `strip_noise()`'s own
blanking (used by `check_line()`) is unaffected.

`swe/.claude-plugin/plugin.json`: version `0.24.4` -> `0.24.5`.

## Verification

- All 14 suites under `swe/tests/` pass (`unit_worklist_test.sh`: 56
  passed, 0 failed, up from 48 before the new fixtures;
  `register_candidates_test.sh` — the regression guard for claude-
  plugins#25's cadence mirror — 46 passed, 0 failed, unchanged).
- Manually built a throwaway fixture repo and ran the modified script
  directly against the three worklist shapes plus two extras, before
  writing the test assertions, to confirm the exact rendered strings.
- `python3 -W error -c "ast.parse(...)"` on the edited file: no syntax
  warnings.
- Ran `/swe:lint-file`'s deterministic-tier check (Step 3 only, via
  the installed `swe@0.23.1` plugin copy — a separate, released copy
  from the one edited in this repo) against both touched prose files
  in isolation for the added sentences: initially found one
  `banned-word` error ("really") in the `agent-guide.md` addition,
  rewrote it, re-checked: both additions are error-free (only
  `sentence-length` warnings, 21-24 words against a 20-word
  guideline, same as pre-existing prose in both files).
- `scripts/check-unshipped.sh`: clean, nothing pending.

## Out of scope

`find_definite_first_mentions` (the `no-unanchored-reference`
candidate locator printed under `[inference-unit]`'s own rule-advisory
lines, separate from the worklist units this fix changes) still reads
the blanked `numbered_lines`, so a *candidate*'s own detail text can
still show a blanked link or code span. The issue's reported false
positives came from the model judging units, which this fix covers;
the candidate locator's cosmetic detail text was not reported as a
problem and is left alone. A follow-up issue can be raised separately
if that is also wanted.

## Links

- Issue: https://github.com/jimbarritt/claude-plugins/issues/27 (closed)
- Commit: https://github.com/jimbarritt/claude-plugins/commit/d56ce5a0116b321f43c7760dc848aa0e4672b80d
- Release run: https://github.com/jimbarritt/claude-plugins/actions/runs/40753963678
- Tag: swe-v0.24.5
