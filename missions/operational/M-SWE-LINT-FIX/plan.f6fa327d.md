# Plan: claude-plugins#35 — "A lint run that also applies the fixes"

## The ask (verbatim, from the issue)

> The lint skill is a check and not an edit, by design: it fixes nothing
> unless asked. A request for a lint is usually a request to correct the
> faults. A question after every run is friction.
>
> Ask: an opt-in flag, or a sibling skill such as `/swe:lint-fix`. It runs
> the fix steps and applies the edits. It then re-runs the whole check on
> the edited content and reports what is left.

## Reading of it

`/swe:lint-file` is check-only by design (`swe/skills/lint-file/SKILL.md`
Step 6: "this command is a check, not an edit"). The issue asks for a
second entry point that both checks and fixes, in one invocation, then
reports what remains uncorrected. The issue itself prefers either an
opt-in flag on the existing skill, or a new sibling skill, and leans
towards the sibling-skill wording (`/swe:lint-fix`).

A flag is rejected: skills take no typed flags, a flag would force a
fix/no-fix branch into every step of `lint-file`'s prose, and
`lint-file`'s own "this command is a check, not an edit" sentence would
stop being true. It would also require `Edit` in `lint-file`'s
`allowed-tools`, turning a read-only check into one that can edit.

Decision: add `/swe:lint-fix` as a new sibling skill, `Edit` added to its
own `allowed-tools` only. `lint-file` stays check-only and unedited apart
from one added sentence pointing to the new skill.

`software_english_lint.py` needs no code change: it already supports a
`--recorded-by` flag (default `lint-file`), so `lint-fix` passes
`--recorded-by lint-fix` and its ledger rows are distinguishable at no
script-side cost. The nonce mechanism already supports "fix, then
re-check, then record": a nonce is bound to the file's exact git blob, an
edit invalidates it, and a second `--force-inference` run on the edited
file mints a fresh nonce to record against.

## The plan

### A. New skill file

`/home/user/claude-plugins/swe/skills/lint-fix/SKILL.md` (new directory
and file; the directory name must equal the frontmatter `name`, per
`skill_frontmatter_test.sh`).

Frontmatter:
```
name: lint-fix
description: Run a full swe check on a named file, fix each finding in
  the file, check the edited file again, and report what remains
argument-hint: <file-path>
allowed-tools: Bash, Read, Edit
disable-model-invocation: false
```

Structure, six steps, numbered to match `lint-file`'s own step numbers
(so cross-references between the two documents stay correct):

- Intro: states what the command does and that it edits without asking
  first (a run of the command is the request). States it does one fix
  pass and one second check, not a loop to a forced-clean result.
- A short section before Step 1 that tells Claude to read
  `lint-file/SKILL.md` in full for shared prose (what the output file
  contains, the `swe-lint-units`/`swe-lint-nonce` lines, the three
  judging passes, the finding format) — but to run the *commands* given
  in `lint-fix` itself, not `lint-file`'s, since
  `${CLAUDE_PLUGIN_ROOT}` only substitutes in the skill text actually
  loaded for this run.
- **Step 1: Read the argument** — same shape as `lint-file`.
- **Step 2: Run the first check** — fetch rule data, run the
  deterministic tier + inference rules (identical command lines to
  `lint-file`'s Step 2/3, copied verbatim so a test can diff them),
  read the output file, judge via `lint-file`'s three passes. Collect
  every finding into a list. If the list is empty, skip Steps 3–4 and
  go straight to Step 5 recording `clean`.
- **Step 3: Fix the findings** — edit the file with `Edit`, errors
  before warnings, one attempt per finding, never inside a fenced code
  block/inline code span/blockquote line, never inventing a fact the
  file doesn't state (e.g. a contradiction-between-sections call is the
  author's to make — note it as not-fixed with a reason instead). Keep
  every fact, value, name, command, path, number and link target
  unchanged; only reword/reorder. Record a list of edits made (line,
  rule id, change) for Step 6.
- **Step 4: Run the second check** — if Step 3 made no edit, skip (Step
  2's result stands). Otherwise re-run Step 2's exact command on the
  now-edited file (fresh nonce; do not reuse Step 2's — it no longer
  matches the blob), re-judge fresh via all three passes, full content,
  no fixing in this step.
- **Step 5: Record the verdict** — same mechanics as `lint-file`'s Step
  5 (`clean`/`failed`/partial/`ignored`, same exit-code handling), but
  `--recorded-by lint-fix`, and using the last check's nonce/unit total
  (Step 4's if it ran, else Step 2's). On exit 4, re-run Step 4 (not
  Step 3) and retry.
- **Step 6: Report** — three lists in order: (1) edits made in Step 3,
  or "nothing to fix" if none; (2) findings Step 3 did not fix, with
  reasons; (3) every finding remaining after the last check — "what is
  left", matching the issue's own wording. Note that edits are
  uncommitted working-tree changes (`git diff <file>` shows them).

No loop: one fix pass, one re-check, then record and report — per the
issue's explicit "reports what is left", which allows findings to
remain. This also bounds the work (no unbounded edit/check cycling) and
stops the skill from forcing a false `clean`.

### B. Edit to the existing skill

`/home/user/claude-plugins/swe/skills/lint-file/SKILL.md`, Step 6, last
sentence. Replace:

> Do not fix anything unless asked: this command is a check, not an edit.

with:

> Do not fix anything unless asked: this command is a check, not an
> edit. `/swe:lint-fix <file-path>` runs the same check, fixes the
> findings, and checks the edited file again.

Keep `lint_file_pass3_test.sh`'s existing assertions intact (it checks
for "all three passes" and the absence of "both passes"/"two passes"
phrasing) — the added sentence must not introduce either phrase.

### C. Other doc updates

- `swe/README.md`: name `/swe:lint-fix` next to `/swe:lint-file` in the
  intro; add a `## Check and fix one file on demand` section (after the
  existing "Check one file on demand" section) describing the command,
  its edit scope/exclusions, that it checks the edited file again,
  records the verdict, and does one fix pass only; update the "re-run
  `/swe:lint-file` after any change" line to mention both commands.
- `swe/docs/agent-guide.md`: list `/swe:lint-fix` alongside
  `/swe:lint-file` near lines 29/88; update the "Recording a verdict"
  passage to note both skills' Step 5 record, and that `lint-fix` rows
  show `recorded_by: "lint-fix"`; reword the "Known limits" bullet "No
  auto-rewrite mechanism exists" to describe that the script itself has
  no rewrite mode, a blocking hook causes edits in response, and
  `/swe:lint-fix` performs those edits with the model in-session (not
  the script), and that SPEC §9 fact-preservation checking is not
  built, so `lint-fix` relies on its own instruction to preserve facts.
- `swe/skills/install-commit-hook/SKILL.md`: optionally note a `clean`
  verdict can also come from `/swe:lint-fix`.
- `software_english_lint.py`: optional docstring-only mentions of
  `/swe:lint-fix`; no functional change.
- `CLAUDE.md`: no change (it holds repo conventions, not a skill list).

### D. Version bump

`swe/.claude-plugin/plugin.json`: `0.26.6` → `0.27.0` (minor: a new
skill is a feature, matching prior minor bumps for new user-facing
capability, e.g. Pass 3 and the `ignored` verdict).

### E. Tests

New `/home/user/claude-plugins/swe/tests/lint_fix_skill_test.sh`,
modelled on `lint_file_pass3_test.sh` / `lint_file_scratch_output_test.sh`
(same `assert` helper, same pass/fail footer). Structural checks only —
a SKILL.md is a prompt, not executable, so no test can check fix
quality:
- `skills/lint-fix/SKILL.md` exists; frontmatter `name: lint-fix`;
  `allowed-tools` contains `Edit`.
- `lint-file/SKILL.md`'s `allowed-tools` does NOT contain `Edit`.
- Step headings 1–6 exist in order; Step 3 mentions "Fix", Step 4
  mentions "second check", Step 5 mentions "Record".
- Text references `skills/lint-file/SKILL.md`.
- Step 2's fetch/run command lines are byte-identical to `lint-file`'s
  equivalent lines (diff-based assertion so the copies can't drift);
  scratch-output rules from #29 hold (`mktemp`, `XXXXXX`, `> "$out"`,
  `2>&1`, `swe-lint output:`, no `mktemp -t swe-lint`).
- Step 5 contains `--recorded-by lint-fix` and both
  `--record-lint-result clean`/`failed`.
- No-loop wording present ("does not repeat the fix pass", "Do not fix
  any finding from this step", "Do not run Step 3 again").
- Step 3 states the edit exclusions ("fenced code block",
  "blockquote", "Keep every fact").
- `lint-file/SKILL.md` Step 6 names `/swe:lint-fix`.

Optionally add `swe/skills/lint-fix/SKILL.md` to the real-file sweep
lists in `register_candidates_test.sh` and
`define_and_count_candidates_test.sh`, matching `lint-file`'s own
inclusion.

Run every `swe/tests/*.sh`, plus `scripts/check-unshipped.sh`, before
the commit. Lint the new/changed prose files
(`swe/skills/lint-fix/SKILL.md`, `lint-file/SKILL.md`, `README.md`,
`agent-guide.md`) with the lint-file procedure (manually, via the
script directly, since no plugin is loaded in this session) before
committing.

### F. Order of work

1. Write `swe/skills/lint-fix/SKILL.md`.
2. Edit `lint-file/SKILL.md` Step 6.
3. Add `lint_fix_skill_test.sh` (+ optional sweep-list additions).
4. Update `README.md` and `agent-guide.md` (+ optional
   `install-commit-hook/SKILL.md` and script docstring mentions).
5. Bump `plugin.json` to `0.27.0`.
6. Run all `swe/tests/*.sh`, `scripts/check-unshipped.sh`; lint every
   touched prose file.
7. Commit on `main` with `closes #35`; push; run
   `release-plugin.yml -f plugin=swe`.
8. Close the loop on the issue; record the ledger report.
