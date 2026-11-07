# Plan: claude-plugins#34, a bare linter run states that the inference tier did not run

## 1. The ask, verbatim

> Running the lint script directly, without `--force-inference`, prints deterministic findings only and ends with a count. That count reads as a verdict on the whole text. An agent that runs the script that way reports the file clean, and every judgement-based rule is skipped with no sign that it was.
>
> Seen in a real session: a draft was reported clean on a bare run that returned zero errors. The full skill run on the same unchanged content then returned 23 inference findings, including an unanchored reference in the opening paragraph that a reader had already spotted unaided.
>
> Ask: make the bare run state what it did not check. A trailing line is enough, for example `inference tier not run; N rule(s) need model judgement; run /swe:lint-file`. The enumeration already exists, since `--force-inference` lists those rules.

(https://github.com/jimbarritt/claude-plugins/issues/34)

## 2. What is wrong (from reading the code)

All line numbers refer to `swe/scripts/software_english_lint.py`, 2754 lines.

`main()` starts at line 2384. On a bare run (no `--force-inference`, no `--advise-inference`), stdout gets these lines and nothing else:

- **Without `--count`:** one `label:N: [severity] [rule] detail` line per deterministic finding (lines 2555-2571). An empty file prints nothing. The run has no summary line at all, so a clean file gives **empty stdout and exit 0**. The `swe: rule data <tag>, fetched <age>` line goes to stderr (lines 2545-2547).
- **With `--count`:** lines 2549-2553 print `"{E} errors, {W} warnings across {n} files"` and return straight away. This is the "ends with a count" case in the issue, and the agent guide documents it (`swe/docs/agent-guide.md` line 685).

Neither output says that the catalogue's `check = "model-judgement"` rules were not run. The script already has that rule set:

- **Rule selection:** line 2600 inside `main()`, in the `due_for_inference` branch builds `inference_rules = {rid: r for rid, r in rules.items() if r.get("check") == "model-judgement"}`, extended with `plugin_rules` when conversational.
- **Count already printed:** `format_inference_rules()` (line 2315) puts `len(inference_rules)` into the `[inference-pending]` summary line at line 2372.

Only the `--force-inference` and `--advise-inference` paths build this dict, so a bare run never computes N. The `N` the issue asks for is `len()` of that same dict.

The exit code reflects only the deterministic tier; this change does not alter that.

## 3. Implementation plan

### Step 1: Move rule selection into one shared helper

Add a module-level function near `format_inference_rules()`:
`applicable_inference_rules(rules, plugin_rules, is_conversational)`, returning the dict built today at lines 2600-2603. Replace that block with a call to it, so the bare-run N and the force-path N come from one code path.

### Step 2: Build the trailing line once, in `main()`

Build it after the "No sources to check" exit and after the stderr data-status lines, before the `if args.count:` branch, when ALL of:

1. Bare run: `not args.force_inference and not args.advise_inference`. `--advise-inference` is used only by the three PreToolUse hooks and is left alone.
2. At least one source has prose: `any(prose.strip() for _, _, prose, _ in sources)`.
3. N > 0, where N = `len(applicable_inference_rules(...))`. When N is 0, print nothing — nothing was skipped.

None of these change the outcome: deterministic errors present, `--stop-hook-active`, `--quiet-vocab`, `--diff`/`--added-only`.

### Step 3: Wording and output stream

Stdout, as the last line, plain `swe:` prefix (not finding-shaped, so it is not miscounted as a `[warning]` by `grep -c '\[warning\]'` in `_lib.sh` or by an agent scanning for findings):

- Single named file (existing `inference_key is not None` test): `swe: inference tier not run; {N} rule(s) need model judgement; run /swe:lint-file {args.files[0]}`
- Otherwise: `swe: inference tier not run; {N} rule(s) need model judgement; run /swe:lint-file`

### Step 4: Print it in both bare-run exits

- `--count` branch: after the counts line, before `return`.
- Normal path: after the findings loop, just before the `stop_hook_active`/`return` block, so it is the last stdout line.

Exit codes are unchanged.

### Step 5: `--record-lint-result` is not affected

That path returns before the rule catalogue loads and before any source is linted; no change needed.

Two other early exits print no trailing line, correctly: the missing-catalogue exit (cannot compute N) and "No sources to check." (nothing to check).

### Step 6: Effect on other callers — no edits needed

All downstream callers capture stdout+stderr together, so stream choice doesn't matter to them:

- `swe/git-hooks/pre-commit.sh` (bare, advisory): the new line is accurate context for its follow-on ledger check.
- `swe/tsk-hooks/pre-docs-commit.sh` (bare): on status 0 it correctly qualifies "passed"; on status 1 it already recommends `/swe:lint-file`.
- The three PreToolUse hooks: excluded by condition 1.
- `swe/skills/lint-file/SKILL.md`: uses `--force-inference`, unaffected.

### Step 7: Tests

- `data_version_test.sh`: fixture has 0 model-judgement rules, so N=0 and no line prints — unaffected; add one assertion that stdout has no `inference tier not run`.
- Other existing tests only grep specific `[rule]` tokens, unaffected.
- New section in `commit_check_test.sh` (fixture has exactly 2 model-judgement rules):
  1. Bare run on a prose file: last stdout line is exactly `swe: inference tier not run; 2 rule(s) need model judgement; run /swe:lint-file a.md`, exit 0.
  2. `--count` on the same file: counts line first, trailing line last, exit 0.
  3. File with a deterministic error: trailing line still last, exit still 1.
  4. N agrees between bare run and `--force-inference`'s `[inference-pending]` count.
  5. `--force-inference`: no `inference tier not run` line present.
  6. `--advise-inference --text`: no `inference tier not run` line present.
  7. Empty-prose file: no trailing line.
  8. Two named files: line ends `run /swe:lint-file` with no path.
  9. `--record-lint-result`: no `inference tier not run` line present.

### Step 8: Docs and release

- Module docstring: short new paragraph after the `--count` paragraph, covering the trailing line, its conditions, why it's not finding-shaped, and that the exit code is unchanged. Reference claude-plugins#34.
- `swe/docs/agent-guide.md` "Run the linter directly": one or two sentences — a bare or `--count` run ends with the trailing line, and a clean bare run is a deterministic-only result, not a verdict on the file.
- `swe/.claude-plugin/plugin.json`: bump `version` (patch).
- `scripts/check-unshipped.sh`, then `gh workflow run release-plugin.yml -f plugin=swe`.

### Sequencing

1. Helper extraction (Step 1); confirm `--force-inference` output unchanged.
2. Trailing-line logic and both print sites (Steps 2-4).
3. New tests (Step 7); run all of `swe/tests/*.sh`.
4. Docstring, agent guide, version bump.

### Critical files

- swe/scripts/software_english_lint.py
- swe/tests/commit_check_test.sh
- swe/tests/data_version_test.sh
- swe/docs/agent-guide.md
- swe/.claude-plugin/plugin.json
