# Report: software-english#23, a banned.tsv replacement that contains a banned term

## Outcome

Shipped on both repos.

- `jimbarritt/software-english`: commit `b7a8291` ("banned.tsv: hit
  suggests \"exceed a limit\", not the banned \"reach a limit\"",
  `closes #23`). Changed `vocabulary/banned.tsv` row 20 from
  `hit\tcall, reach a limit, or fail` to
  `hit\tcall, exceed a limit, or fail`. Released via `release.yml` as
  tag `v0.0.29`.
- `jimbarritt/claude-plugins`: commit `4232e50` ("swe: pin
  software-english v0.0.29, add banned.tsv replacement-cycle test").
  Bumped `swe/software-english.json`'s pinned tag to `v0.0.29`, added
  `swe/tests/banned_replacement_cycle_test.sh`, bumped
  `swe/.claude-plugin/plugin.json` version 0.24.5 -> 0.24.6. Released
  via `release-plugin.yml` as tag `swe-v0.24.6`.

Issue closed by the `closes #23` commit; comment posted on it naming
both commits and both tags; `agent:working` label removed.

## What changed

1. Fixed the one bad replacement in `vocabulary/banned.tsv`: `hit`'s
   suggested fix used `reach`, a term the same file bans, so following
   the suggestion traded one `banned-word` finding for another.
2. Added `swe/tests/banned_replacement_cycle_test.sh`, a real-data test
   (SWE_SRC checkout, else fetch the pinned tag, else SKIP — same
   convention as `motion_idiom_test.sh`) that imports the real
   `load_banned()` from `software_english_lint.py` and asserts no
   row's replacement text matches any row's `\b<phrase>\b`
   case-insensitive pattern. Matching is not reimplemented, so the
   test can never drift from the rule it checks.
3. Bumped and released both repos' version-bearing artefacts
   (`v0.0.29` on software-english, `swe-v0.24.6` on claude-plugins),
   since the change touches `vocabulary/`, which the `swe` plugin
   fetches.

## What was found along the way

- Re-ran the real `load_banned()` parsing over the whole 204-row
  `banned.tsv` both before and after the fix. Before: `hit` was the
  only row whose replacement matched a banned phrase (the issue's own
  claim, "a check over every row found this to be the only
  replacement", still held — no drift since the issue was filed).
  After: zero rows have the cycle.
- `software-english` has no test infrastructure of its own (no test
  dir, no test CI — only the manual `release.yml`). The new test
  therefore lives in `claude-plugins/swe/tests/`, which already holds
  the real matching logic and the established SWE_SRC/fetch/SKIP
  convention for tests that need real vocabulary data.
- Verified the new test both ways: it fails and names `hit`/`reach`
  against a scratch copy with the old row restored, and passes against
  both the local fixed checkout (`SWE_SRC`) and the fetched, newly
  pinned `v0.0.29` tag.
- `scripts/check-unshipped.sh` counts any change under a plugin's own
  directory, `tests/` included, as needing a release — so the
  test-only addition was not exempt and needed the `swe` version bump
  and release alongside the pin bump, confirmed clean after
  `release-plugin.yml` ran.
- Full `swe/tests/*.sh` suite run clean after all changes (14 files,
  all passing) before committing.

## Commits and tags

| Repo | Commit | Tag |
|---|---|---|
| software-english | `b7a8291` | `v0.0.29` |
| claude-plugins | `4232e50` | `swe-v0.24.6` |
