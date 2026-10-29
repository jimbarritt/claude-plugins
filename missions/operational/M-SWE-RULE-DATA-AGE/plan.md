# Plan: claude-plugins#28, report how old the cached rule data is

## 1. The ask, verbatim

**Title:** software_english_lint.py: report the age of the cached rule data, and warn when it is old

**Body:**

> ### Problem
>
> The deterministic tier reports a result against whatever rule data is in the plugin's cache, and the output gives no version or age for that data. A file can be reported clean against old data and fail against current data, with no change to the file.
>
> In one session, a document was linted several times and reported clean apart from two warnings. After `fetch-software-english-data.sh` ran, the same command on the same unchanged file reported 8 errors. One of them was a word added to `banned.tsv` since the cached version, and the document used that word in many places. All of the editing before the refresh was checked against rules that were out of date.
>
> `/swe:lint-file` runs the fetch script in Step 2, but the hooks and a direct call to the script do not.
>
> ### Proposed fix
>
> Any one of these, in order of cost:
>
> 1. **Print the data version on every run.** One stderr line, for example `swe: rule data v1.14.0, fetched 3 days ago`, read from `.fetched-tag` and the file's modification time. No network call.
> 2. **Warn above a threshold.** When the cache is older than a set age (for example 24 hours), print a warning with the command to refresh.
> 3. **Refresh on demand.** When the cache is older than the threshold, run the fetch script before the check, with a fallback to the cached data when the network call fails.
>
> 1 and 2 together are one stderr line, with no network call on the linting path.

## 2. What the code does now, and what the issue needs

### The cache and its marker
- `swe/scripts/fetch-software-english-data.sh` writes to `$PLUGIN_ROOT/data/`. `data/` is gitignored.
- The marker is `data/.fetched-tag`. It holds one line: the tag string, for example `v0.0.32`.
- The pin is `swe/software-english.json`: `{"repo": "jimbarritt/software-english", "tag": "v0.0.32"}`.
- The script does not fetch "latest". It fetches the pinned tag only, and exits 0 at once with no network call when the marker already equals the pin. The script rewrites the marker, and so changes its mtime, only when the tag changes.

### What follows for the issue's options
- The age of the data does not show whether the data is stale. A git tag is fixed: a cache of `v0.0.32` from 30 days ago is still exactly correct while the pin is `v0.0.32`.
- The data is stale in one case only: `.fetched-tag` differs from the pinned `tag` in `software-english.json`. That can be checked with no network call and no clock.
- Option 2 as written (warn past a 24h age) fails: it warns on correct data, and the refresh command it names does nothing when the tag already matches (the fetch script no-ops), so the warning would never clear.
- The scenario in the issue is most likely: the pin was bumped (v0.0.29 to v0.0.32 across recent commits) while a working copy's `data/` kept the old tag, and a direct call or a hook that skips the fetch linted against stale data. A tag-mismatch check catches exactly this.

### The issue's claim about hooks is partly wrong
- `hooks/bash-check.sh`, `hooks/artifact-check.sh` and `hooks/mcp-send-check.sh` all run the fetch script before linting. A mismatch for them is possible only after a failed offline fetch.
- `git-hooks/pre-commit.sh` and `tsk-hooks/pre-docs-commit.sh` do not run the fetch script, by design, so a commit never waits on a network call.
- A direct call to the linter does not run the fetch script either.

### Where the linter prints and loads data
- `software_english_lint.py` sets `PLUGIN_ROOT` and `DATA = PLUGIN_ROOT / "data"`.
- In `main()`: `--record-lint-result` returns before any data is loaded. `load_rule_catalogue()` returning `None` prints a stdout skip message and returns 0. Findings go to stdout; usage errors go to stderr with a `swe:` prefix. A clean run prints nothing to stdout. Exit codes: 0 clean, 1 findings, 2 usage error.
- Every hook captures the linter's output with `2>&1`. `_lib.sh`'s `report_and_maybe_block` counts lines containing the literal tokens `[error]` and `[warning]` — the new lines must not contain either token.

### Decision on scope
1. **Option 1: implement.** Print one stderr line on every linting run with the tag and the marker age.
2. **Option 2: implement, with a different trigger.** Warn when the cached tag is not the pinned tag, not on an age threshold. The age stays in the information line. This is a deliberate deviation from the issue's literal proposal, recorded here and in the commit/issue reply.
3. **Option 3: do not implement.** It puts a network call on the linting path; the two git/tsk hooks leave out the fetch on purpose; the three PreToolUse hooks and `/swe:lint-file` Step 2 already run it.
4. Out of scope: detecting a newer upstream tag than the pin (needs a network call; the plugin cannot use it until the pin is bumped anyway).

## 3. Implementation plan

### Step 1: constants in software_english_lint.py
Next to `DATA`, add `FETCHED_TAG_PATH = DATA / ".fetched-tag"`, `PIN_PATH = PLUGIN_ROOT / "software-english.json"`, `FETCH_SCRIPT = HERE / "fetch-software-english-data.sh"` (absolute path, used in the warning text). No age-threshold constant.

### Step 2: new pure helpers, near `load_rule_catalogue()`
- `format_age(seconds)` -> string. Clamp negative to 0. `<60s` "less than a minute ago"; `<3600s` "N minute(s) ago"; `<48h` "N hour(s) ago"; else "N day(s) ago". Singular when N == 1.
- `read_data_status()` -> `(fetched_tag, pinned_tag, age_seconds)`, each `None` on any read/parse error.
- `data_status_lines(fetched_tag, pinned_tag, age_seconds)` -> list of strings, pure (importable for a unit test).

### Step 3: exact stderr lines
- Information line (marker found): `swe: rule data v0.0.32, fetched 3 days ago`.
- Information line (no marker, catalogue present): `swe: rule data version unknown (no data/.fetched-tag marker)`.
- Stale warning (only when both tags are known and differ), as a second line:
  `swe: stale rule data: the cache holds v0.0.31, but software-english.json pins v0.0.32. Findings from this run use the old rules. Run <abs path>/fetch-software-english-data.sh to refresh.`
- Must not contain the literal tokens `[error]` or `[warning]`.
- No warning when the pin or marker cannot be read, or when only the age is large.

### Step 4: call site in main()
Call after the `if not sources:` check (so "no sources to check" stays quiet) and after the catalogue-missing early return (so that path keeps its current stdout-only message). Print via `print(..., file=sys.stderr)`. Exit codes unchanged in every case; the status is informational only. Stdout contract (`INFERENCE_ADVISED` fences, `swe-lint-units`, `swe-lint-nonce` staying last) is unaffected since these lines are stderr-only.

### Step 5: effect on each hook (no hook code changes needed, document the effect)
- Three PreToolUse hooks: line becomes part of captured `2>&1` output; invisible on status 0; shown in the report file on a block; bracket-free so `_lib.sh` counts are unaffected.
- `git-hooks/pre-commit.sh` and `tsk-hooks/pre-docs-commit.sh`: `DET_OUT`/`OUT` will no longer be empty on a clean commit — the advisory header plus the `swe: rule data …` line (and the stale warning, when relevant) now shows on every commit with staged Markdown. This is the main fix for the issue's scenario. Confirm `commit_check_test.sh` still passes.
- `/swe:lint-file`: a stale warning in Step 3 output means the Step 2 fetch did not actually update the cache (e.g. offline failure).

### Step 6: documentation
- `swe/skills/lint-file/SKILL.md` Step 3: one sentence noting the new stderr line and what a stale warning after Step 2's fetch means.
- `swe/docs/agent-guide.md`: describe the two stderr lines, the mismatch trigger, and why there is no age threshold; correct the "hooks do this automatically" claim to name only the three PreToolUse hooks.
- `swe/README.md`: note that a direct call and the git/tsk hooks do not fetch, and now print `swe: stale rule data:` until the fetch script runs.

### Step 7: new test, `swe/tests/data_version_test.sh`
Follow existing test conventions (`commit_check_test.sh`, `lint_fail_open_test.sh`): `set -uo pipefail`, `PASS`/`FAIL` counters, `mktemp -d` fixture with trap cleanup, isolated `HOME`. Set marker mtime with Python (`os.utime`), not GNU `touch -d`. Cases: fresh matching tag (info line, no stale line, clean stdout/exit 0); old but matching (no stale line — proves age alone doesn't warn); stale tag (stale line with both tags and the fetch script path); stdout byte-identical and exit codes unaffected between fresh/stale; stderr has no `[error]`/`[warning]` tokens; `--count` stdout unaffected; no marker (unknown-version line, no stale line); no `software-english.json` (info line only); no catalogue (no rule-data line, existing skip message intact); `format_age` unit table via direct module import.

Run the full `swe/tests/*.sh` suite afterwards, with particular attention to `commit_check_test.sh`, `docs_hook_test.sh`, `hooks_test.sh`, `lint_fail_open_test.sh`, `define_and_count_candidates_test.sh`, plus `python_syntax_warnings_test.sh` and `scripts/check-unshipped.sh`.

## 4. Version bump and release
- `swe/.claude-plugin/plugin.json`: bump `version` by one patch level.
- After pushing `main`: run `release-plugin.yml` for `swe` via `actions_run_trigger`.
- Run `scripts/check-unshipped.sh` before calling the task done.
