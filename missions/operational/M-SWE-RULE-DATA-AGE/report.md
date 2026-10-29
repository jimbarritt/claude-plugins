# Report: claude-plugins#28, report how old the cached rule data is

## Outcome

Shipped. Commit `e2b5686` on `jimbarritt/claude-plugins` `main`, closing
issue #28. Released as `swe-v0.24.11` via `release-plugin.yml` (run
40849290439, success).

## What changed

`swe/scripts/software_english_lint.py`:
- New constants `FETCHED_TAG_PATH`, `PIN_PATH`, `FETCH_SCRIPT`.
- New helpers `format_age()`, `read_data_status()`, `data_status_lines()`.
- `main()` now prints, on stderr, on every linting run with sources:
  - `swe: rule data <tag>, fetched <age>` (or `swe: rule data version
    unknown (no data/.fetched-tag marker)` with no marker).
  - `swe: stale rule data: the cache holds <tag>, but
    software-english.json pins <tag>. Findings from this run use the old
    rules. Run <path>/fetch-software-english-data.sh to refresh.` — only
    when both tags are known and differ.
- No age threshold, by design (see Decision below).

`swe/tests/data_version_test.sh` (new): 26 assertions covering fresh
matching tag, old-but-matching tag (proves age alone never warns), stale
tag, stdout/exit-code invariance, no `[error]`/`[warning]` tokens in the
new stderr lines, `--count` invariance, missing marker, missing pin file,
missing catalogue, and a `format_age()` unit table.

Three existing tests fixed: `define_and_count_candidates_test.sh`,
`definite_phrase_candidates_test.sh`, `register_candidates_test.sh`. Each
captured a `--count` call with `2>&1` and asserted the combined output
started with `"0 errors"`. The new stderr info line now prints first in
that combined capture, so each was changed to `2>/dev/null` for that one
capture — the assertions only ever cared about `--count`'s stdout
contract, not stderr.

Documentation: `swe/docs/agent-guide.md` (one paragraph on the two
stderr lines and the mismatch trigger, one correction of "the hooks do
this automatically" to name only the three PreToolUse hooks),
`swe/README.md` (one sentence under "Pick up a newer version of the
Software English spec"), `swe/skills/lint-file/SKILL.md` Step 3 (one
sentence on what a stale-data line after Step 2's fetch means).

`swe/.claude-plugin/plugin.json`: `0.24.10` -> `0.24.11`.

## What was found along the way

The issue's proposed option 2 (warn when the cache is older than a 24h
threshold) does not hold up: `fetch-software-english-data.sh` fetches an
exact pinned tag and exits at once, with the marker untouched, once that
tag is already cached. A tag that still matches the pin is correct
regardless of its age, and an age-based warning would name a refresh
command that does nothing in that case — it would never clear. The real
staleness signal is a tag mismatch between `data/.fetched-tag` and the
`tag` pinned in `software-english.json`, which needs no clock and no
network call. Recorded as a decision on the mission.

The issue's claim that "the hooks ... do not" run the fetch script is
only half right: the three PreToolUse hooks (`bash-check.sh`,
`artifact-check.sh`, `mcp-send-check.sh`) already run it before linting.
Only the git commit hook and the tsk documents hook skip the fetch, by
design, so a commit never waits on a network call — those two, plus a
direct call to the linter, are exactly the paths where the new stale
warning now surfaces the issue's scenario.

## Verification

Full `swe/tests/*.sh` suite: all pass (no regressions beyond the three
fixed above). `python_syntax_warnings_test.sh`: pass.
`scripts/check-unshipped.sh`: confirmed the version bump was pending
before the release workflow ran, and the release workflow completed
with conclusion `success`.
