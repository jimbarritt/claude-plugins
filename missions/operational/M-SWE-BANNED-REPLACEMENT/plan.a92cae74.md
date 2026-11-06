# Plan: software-english#23, a banned.tsv replacement that contains a banned term

## 1. The ask, verbatim

```
## Verdict

Wrong fix, `banned-word`.

## Problem

The `banned.tsv` row for `hit` suggests:

    hit	call, reach a limit, or fail

`reach` is a banned term in the same file. A writer who follows the
suggestion and writes "the client reaches the rate limit" gets a new
`banned-word` error on the next run.

A check over every row found this to be the only replacement that
contains a term the same file bans.

## Proposed fix

1. Change the replacement, for example:

       hit	call, exceed a limit, or fail

2. Add a test that fails when the replacement text of any row in
   `banned.tsv` contains a term that `banned.tsv` bans, with the same
   word-boundary and inflection matching that the `banned-word` rule
   uses. The test reads one file and stays fast, and it catches a new
   cycle when a row is added.
```

## 2. Reading of it

What is asked:
- (a) Change the replacement text on the `hit` row so it no longer contains `reach`.
- (b) Add a regression test that fails if any row's replacement column contains a phrase that the same file bans. The test must use the same matching as the `banned-word` rule.

Verified independently:
- `vocabulary/banned.tsv` line 20 is `hit\tcall, reach a limit, or fail`. Line 1 is `reach\tname the action: read, write, upload, fetch, call`.
- `load_banned()` in `swe/scripts/software_english_lint.py` (lines 892-910) reads `banned.tsv`, skips blanks/`#` lines, splits on tab (column 1 = phrase, column 2 = fix, default `"rewrite"`), dedupes phrases case-insensitively, and builds `re.compile(r"\b" + re.escape(phrase) + r"\b", re.IGNORECASE)` per phrase. There is no separate inflection engine: inflected forms are separate rows.
- Re-ran the whole-file check with the real parsing logic: the `hit`/`reach` row is still the only replacement in the current 204-row file that contains a banned phrase. No other data row needs changing.
- `software-english` HEAD (54e1fda) is tag `v0.0.28`, which is what `claude-plugins/swe/software-english.json` currently pins — the pinned data carries the bug today.

Ambiguity 1, where the test lives: `software-english` has no test infrastructure (no test dir, no test CI — only the manual `release.yml`). The real matching logic exists only in `claude-plugins/swe`. Resolution: put the test in `claude-plugins/swe/tests/`, following the real-data convention already used by `motion_idiom_test.sh` (SWE_SRC checkout, else fetch the pinned tag, else SKIP and exit 0), and have it import and call the real `load_banned()` from the fixture's copy of `scripts/software_english_lint.py` (module has an `if __name__ == "__main__":` guard, so import is side-effect free) rather than re-implementing the regex, so the test can never drift from the real rule.

Ambiguity 2, does a row's own replacement count: yes — the issue says "any row". The check includes a row's own phrase against its own fix. Nothing hits today apart from `hit`/`reach`.

Ambiguity 3, test wiring: claude-plugins has no aggregate test runner. CI (`swe-python-syntax.yml`) runs only `python_syntax_warnings_test.sh`; the rest of `swe/tests/*.sh`, `motion_idiom_test.sh` included, are run by hand / by the maintainer Routine. Matching convention means adding the file under `swe/tests/` with no extra CI wiring; a CI workflow for real-data tests is a possible follow-up, out of scope here.

## 3. The plan

### Repo A: jimbarritt/software-english (the issue's own repo)

1. Edit `vocabulary/banned.tsv` line 20: `hit\tcall, reach a limit, or fail` -> `hit\tcall, exceed a limit, or fail`. Keep the single-tab separator.
2. Re-run the whole-file check after the edit (same real parsing logic). Expect zero rows where a replacement matches any banned phrase's `\b...\b` pattern.
3. Commit with `closes #23` in the message, plus attribution lines. Push to `main`. This is the only commit anywhere that uses `closes #23`.
4. Release software-english: `release.yml` with version `0.0.29` (newest tag is `v0.0.28`; required because the change touches `vocabulary/`).

### Repo B: jimbarritt/claude-plugins (secondary)

5. Bump the pin in `swe/software-english.json`: `"tag"` `v0.0.28` -> `v0.0.29` (after step 4's tag exists).
6. Add executable `swe/tests/banned_replacement_cycle_test.sh`, modelled on `motion_idiom_test.sh`'s fixture/SKIP pattern:
   - Header comment explaining it covers software-english#23, uses the real `load_banned()`, runs against real data via `SWE_SRC` or the fetched pinned tag, SKIPs (exit 0) with neither.
   - Setup: `set -uo pipefail`, PASS/FAIL/assert helper, `mktemp -d` + trap cleanup, fixture copy of `scripts/`, `config.json`, `software-english.json`; `SWE_SRC` copies `vocabulary/*.tsv` + `rules/core-rules.toml` into `$FIXTURE/data/`, else run `fetch-software-english-data.sh`, else SKIP.
   - Precondition assert: `$FIXTURE/data/banned.tsv` exists and `load_banned()` returns more than 0 rules (avoids a vacuous pass).
   - Core check: `PYTHONPATH="$FIXTURE/scripts" python3 -B -c '...'` imports `software_english_lint as m`, calls `m.load_banned()`, and for every `(phrase, fix, _)` × every `(banned, _, pattern)` where `pattern.search(fix)`, prints the offending triple. Capture to a variable (not a pipe, to preserve exit-code reporting under `pipefail`), assert it is empty, echo any offending lines as failures.
   - Footer: print pass/fail counts, exit non-zero on any FAIL.
7. Verify the test both ways: passes with `SWE_SRC=/home/user/software-english` after step 1; fails and names `hit`/`reach` against the unfixed data (old pin or a scratch copy); passes with no `SWE_SRC` once the pin is bumped to v0.0.29. Also run `motion_idiom_test.sh` against the new pin as a smoke test.
8. Bump `swe/.claude-plugin/plugin.json` version `0.24.5` -> `0.24.6`. (`scripts/check-unshipped.sh` counts `git rev-list "$tag..HEAD" -- "$plugin/"`, which covers `swe/tests/`, so a tests-only change still counts as unreleased work and needs a bump.)
9. Commit in claude-plugins (pin bump must land before or together with the test, never the test alone, since the default fetch-pinned run of the test would fail against the buggy v0.0.28 data): reference `software-english#23` without `closes` (the issue is not in this repo). Include the version bump.
10. Release swe: `release-plugin.yml -f plugin=swe` (creates `swe-v0.24.6`). Confirm `scripts/check-unshipped.sh` reports swe up to date after `git fetch --tags`.
11. Close the loop: comment on software-english#23 with both commits and both release tags (`v0.0.29`, `swe-v0.24.6`); confirm the issue closed (step 3's `closes #23` should have done it automatically).

### Risks and notes

- `load_banned()`'s case-insensitive dedupe means only the first row for a duplicate phrase is checked — consistent with how the linter itself behaves, so no gap.
- The test checks only `banned.tsv` against itself, as the issue asks; other vocab files are out of scope.
- A CI workflow running the real-data tests is a possible follow-up, not in scope.

### Critical files

- `/home/user/software-english/vocabulary/banned.tsv`
- `/home/user/claude-plugins/swe/tests/motion_idiom_test.sh` (fixture/SKIP pattern to copy)
- `/home/user/claude-plugins/swe/scripts/software_english_lint.py` (`load_banned()`, lines 892-910)
- `/home/user/claude-plugins/swe/software-english.json`
- `/home/user/claude-plugins/swe/.claude-plugin/plugin.json`
- `/home/user/claude-plugins/scripts/check-unshipped.sh`
