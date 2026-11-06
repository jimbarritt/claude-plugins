# Report: claude-plugins#29

## Outcome

Fixed and released. Commit `12f182c` on `main` (closes #29), released as
`swe-v0.24.12`.

## What changed

- `swe/skills/lint-file/SKILL.md`: Step 3's command now redirects its
  output to a per-run file created by a portable `mktemp` template
  (`mktemp "${TMPDIR:-/tmp}/swe-lint.XXXXXX"`) and prints that file's
  path after `swe-lint output:`. Added a paragraph requiring the file
  stay outside the repository, use no fixed name, be read in full with
  `Read`, and not be deleted afterwards. Reworded the surrounding
  passages ("prints" -> "writes"/"contains" where they described the
  command's output, now a file's content) and tied the existing
  "do not filter or truncate" instruction to the reason the redirect
  exists. Also softened Step 5's "output was truncated" wording for
  consistency.
- `swe/tests/lint_file_scratch_output_test.sh` (new): structural
  regression test asserting Step 3 uses `mktemp` with an `XXXXXX`
  template, redirects to `"$out"`, joins stderr with `2>&1`, prints
  the output path, never reintroduces the non-portable `mktemp -t
  swe-lint` form, and states the no-fixed-name / not-inside-the-repo
  rules; plus a smoke test that the portable `mktemp` template
  actually creates a file outside `$PWD`.
- `swe/.claude-plugin/plugin.json`: version 0.24.11 -> 0.24.12.

## What was found along the way

- The issue's own example command, `mktemp -t swe-lint`, is BSD/macOS-only
  and fails on GNU coreutils with "too few X's in template". Verified by
  running it in this (Linux) environment. Used the portable
  `mktemp "${TMPDIR:-/tmp}/swe-lint.XXXXXX"` form instead, and the new
  test guards against the non-portable form reappearing.
- Shell variables do not persist between separate Bash tool calls in an
  agent harness, so the command prints the output file's path in the
  same call that creates it, rather than relying on `$out` surviving to
  a later call.
- The linter's own exit code is non-zero when it finds errors, so the
  command joins steps with `;`, not `&&`, so the `echo` of the path
  still runs after a non-clean lint.
- `holds` triggered the deterministic tier's own `banned-word` rule
  (`M-SWE-HOLDS-CARRIES`) in the first draft of the new prose; changed
  to `contains`.
- Confirmed by running `scripts/check-unshipped.sh` before and after the
  version bump (and after a `git fetch --tags`, since local tags had
  lagged) that it correctly flagged the pending release before
  `release-plugin.yml` ran, and stopped flagging it after.
- Issue #30 (filed by the same reporter, same day) is a separate,
  unrelated bug in the commit-or-pr-text hook; not touched by this
  change.

## Verification

- All `swe/tests/*.sh` suites pass, including the new one.
- `python3 swe/scripts/software_english_lint.py swe/skills/lint-file/SKILL.md --quiet-vocab`
  is clean (deterministic tier).
- Reviewed the inference-tier's `no-unanchored-reference` candidates the
  new prose raised (lines 39 and 50 in the edited file: "the full
  output", "the working tree", "the normal way", "the results"); judged
  each anchored by adjacent context or standard git/English vocabulary
  already used elsewhere in this plugin's own docs, not a real finding.
- `release-plugin.yml` run 40856224372 completed with conclusion
  `success`; tag `swe-v0.24.12` confirmed present after `git fetch --tags`.
