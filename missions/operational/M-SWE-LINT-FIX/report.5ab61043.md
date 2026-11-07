# Report: claude-plugins#35 — "A lint run that also applies the fixes"

## Outcome

Shipped. `/swe:lint-fix` is a new sibling skill of `/swe:lint-file`.

- Commit: [`af114c2`](https://github.com/jimbarritt/claude-plugins/commit/af114c227deaf5b5c126da3efdf9705a04b7f622)
  on `main` — "Add /swe:lint-fix: check a file, fix its findings,
  re-check, report what remains" (`closes #35`).
- Release: `swe-v0.27.0`, via `release-plugin.yml` run
  [#67](https://github.com/jimbarritt/claude-plugins/actions/runs/42351107099)
  (success).
- Issue closed, `agent:working` label removed, comment posted naming
  the commit and release tag.

## What changed

- **New `swe/skills/lint-fix/SKILL.md`** (`allowed-tools: Bash, Read,
  Edit`). Six steps: read the argument; run the first check (fetch
  rule data, deterministic tier + inference worklist, judge via
  `lint-file`'s three passes); fix the findings (errors before
  warnings, one attempt each, never inside a fenced code block, an
  inline code span, or a blockquote, never where the fix needs an
  unstated fact — noted as not-fixed with a reason instead, facts
  preserved); run the second check (fresh nonce, no re-fixing); record
  the verdict (`--recorded-by lint-fix`, same clean/failed/partial/
  ignored mechanics as `lint-file`); report three lists (edits made,
  findings not fixed, what remains). One fix pass and one re-check
  only — no loop to a forced-clean result, matching the issue's own
  "reports what is left".
- **`swe/skills/lint-file/SKILL.md`**: one sentence added to Step 6
  pointing to `/swe:lint-fix`; stays check-only (no `Edit` in its
  `allowed-tools`).
- **`swe/README.md`**: intro names both commands; new "Check and fix
  one file on demand" section; the re-run note after the commit-check
  section now names both commands. Also fixed a pre-existing
  `banned-word` ("not just") deterministic finding in the config table,
  found while linting the file for this change.
- **`swe/docs/agent-guide.md`**: both commands named near the top;
  "Recording a verdict" extended to both skills' Step 5 and the
  `--recorded-by` flag; "Known limits"' "No auto-rewrite mechanism"
  bullet reworded to describe `/swe:lint-fix` making the edit with the
  model, in-session, and that SPEC §9 fact-preservation checking still
  isn't built (`lint-fix` keeps facts via its own instruction, not a
  built check).
- **`swe/skills/install-commit-hook/SKILL.md`**: two mentions of
  `/swe:lint-file` extended to name `/swe:lint-fix` too.
- **`swe/scripts/software_english_lint.py`**: two docstring-only
  mentions of `/swe:lint-fix` added next to the existing
  `/swe:lint-file` mentions (`--force-inference`, `--record-lint-result`).
  No functional change; `--recorded-by` already existed, unused by any
  prior caller other than `lint-file`'s default.
- **New test `swe/tests/lint_fix_skill_test.sh`**: structural checks
  only (a SKILL.md is a prompt, not executable) — frontmatter, `Edit`
  in `lint-fix`'s `allowed-tools` and its absence from `lint-file`'s,
  the six-step structure, byte-identical fetch/run command lines
  between the two skills (so they cannot silently drift), the
  no-loop wording, the edit exclusions, and `--recorded-by lint-fix`.
- **`swe/tests/register_candidates_test.sh`** and
  **`define_and_count_candidates_test.sh`**: `lint-fix/SKILL.md` added
  to the real-file sweep lists alongside `lint-file/SKILL.md`.
- **`swe/.claude-plugin/plugin.json`**: version `0.26.6` → `0.27.0`
  (minor: new user-facing skill, matching prior minor bumps for new
  capability).

## Verification

- All `swe/tests/*.sh` pass (every suite, 0 failures) both before and
  after the final edits.
- `scripts/check-unshipped.sh` confirmed the pending bump before
  release, and confirmed `0.27.0` matches tag `swe-v0.27.0` after the
  release workflow ran.
- Every touched prose file was run through the full `lint-file`
  procedure (fetch rule data, deterministic tier, `--force-inference`
  worklist, three-pass inference judgement) and recorded `clean`:
  `swe/skills/lint-fix/SKILL.md` (46/46 units), `swe/skills/lint-file/SKILL.md`
  (46/46), `swe/skills/install-commit-hook/SKILL.md` (35/35),
  `swe/README.md` (60/60, after fixing the pre-existing "not just"
  finding). `swe/docs/agent-guide.md` is listed in `.swe-ignore` and
  needs no ledger row. `software_english_lint.py`'s docstring-only
  change was not linted: `.py` is outside `commit-check.paths`'
  default (`["*.md"]`), and the file carries many pre-existing,
  unrelated findings.

## Along the way

- The Plan subagent's research confirmed `--recorded-by` already
  existed in the lint script with no other caller, so no script change
  was needed for `lint-fix` to get its own distinguishable ledger rows.
- Decided against an opt-in flag on `/swe:lint-file` (recorded as a
  mission decision): a flag would force a fix/no-fix branch into every
  step of `lint-file`'s prose and break its "this command is a check,
  not an edit" guarantee, and would need `Edit` added to a skill meant
  to stay read-only.
- Found and fixed a pre-existing deterministic lint fault in
  `README.md` (unrelated to this issue, in a config table) while
  running the required full-file lint pass on it.
