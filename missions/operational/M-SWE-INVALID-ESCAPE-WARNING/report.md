# Report: claude-plugins#26 — invalid `\s` escape

## Outcome

Fixed and released. Commit `4d3f89e` on `claude-plugins` `main`, tag
`swe-v0.24.4` (plugin version 0.24.3 → 0.24.4).

## What changed

- `swe/scripts/software_english_lint.py`: the module docstring (line 2) is
  now a raw string (`r"""..."""`). The regex it quotes (originally cited as
  line 35) had three invalid escapes — `\s`, `\[`, `\]` — not only the `\s`
  Python's warning named; Python reports only the first invalid escape per
  literal.
- New regression test `swe/tests/python_syntax_warnings_test.sh`: compiles
  every `.py` file under `swe/scripts` (including `_vendor`) with
  `-W error::SyntaxWarning -W error::DeprecationWarning`, across whichever
  of `python3`, `python3.12`, `python3.13` are present. Verified it fails
  before the fix (3 failures on all three interpreters) and passes after.
- New CI workflow `.github/workflows/swe-python-syntax.yml`: runs the new
  test on push to main, pull_request, and workflow_dispatch, on Python 3.12.
- `swe/.claude-plugin/plugin.json`: version bumped 0.24.3 → 0.24.4.

## What was found along the way

- Python 3.11 reports an invalid escape as a `DeprecationWarning`, not a
  `SyntaxWarning`. The issue's own proposed CI command
  (`-W error::SyntaxWarning` only) would pass on 3.11 with the bug still
  present. The test and the plan both account for this by checking both
  warning classes.
- Only one string literal in the whole repository had the fault: the
  docstring at line 2 of `software_english_lint.py`. Checked with
  `tokenize` over every non-raw string literal in the file, and by
  compiling every `.py` file under `swe/` (vendored `tomli` included) with
  all warnings recorded. Every regex elsewhere in the file (from line 599
  on) was already a raw string.
- No CI workflow previously ran any of the `swe/tests/*_test.sh` suites —
  `check-unshipped.yml` only checks version bumps, and `release-plugin.yml`
  only runs by hand. The new workflow is additive and doesn't change that
  for the other suites.

## Verification run

- Full `swe/tests/*_test.sh` suite: all 14 scripts pass (568 total
  assertions, 0 failed).
- `scripts/check-unshipped.sh`: exit 0.
- No prose files were touched, so no `/swe:lint-file` run was needed.
- Push-triggered CI (`check-unshipped.yml`, `swe-python-syntax.yml`) both
  green on commit `4d3f89e`. `release-plugin.yml` run 48 (workflow_dispatch)
  completed with conclusion `success`, producing tag `swe-v0.24.4`.

## Issue closed

`claude-plugins#26`, closed with a comment naming the commit, tag, and
what changed. No other open issue is resolved by this change.
