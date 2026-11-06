# Report: `ignored` verdict with a mandatory `--reason`

Mission `M-SWE-IGNORED-VERDICT-REASON`, claude-plugins#32.

## Commit and release

- Commit `4adc43a` on `claude-plugins` `main`, `closes #32`.
- Release tag `swe-v0.26.0` (workflow run
  https://github.com/jimbarritt/claude-plugins/actions/runs/42243664529,
  success).

## What changed

- `swe/scripts/software_english_lint.py`: `--record-lint-result` gained
  `ignored` as a third choice, plus a `--reason` flag. `main()` rejects
  (exit 2, nonce unspent) `--reason` given with any verdict but
  `ignored`, and `ignored` given with no non-empty `--reason`.
  `record_lint_result()` accepts `reason`, extends the partial-coverage
  downgrade to `status in ("clean", "ignored")`, adds `reason` to the
  ledger row only for `ignored`, and reports it in the success line.
  The module docstring documents the new verdict. A naming collision
  inside `record_lint_result()` was found and fixed while doing this:
  the function already unpacked `_repo_context()`'s failure string into
  a local called `reason`, which would have silently clobbered the new
  `reason` parameter; renamed to `err`.
- `swe/git-hooks/pre-commit.sh`: `swe-commit-check-version` bumped to 3
  (so already-installed hooks re-copy on next
  `/swe:install-commit-hook` run). `check_ledger.py` treats
  `clean`/`ignored` as passing and writes ignored path+reason pairs to
  a side file. The success line names clean/ignored counts and lists
  each ignored file with its reason. `block_on_deterministic` excludes
  an ignored file from its re-check (re-running the deterministic tier
  on the non-ignored subset when any staged file is ignored).
- `swe/skills/lint-file/SKILL.md` Step 5/6: when to use `ignored`
  (judged, breaks a rule, fixing it would destroy the artefact — ask
  the user first if they have not already asked for the exemption),
  the command shape, partial behaviour, and the new exit-2 cases.
- `swe/docs/agent-guide.md`, "The commit check": ledger schema,
  command shape, blocking rule, partial rule, passing-commit output,
  the hook version bump, and the `block_on_deterministic` exclusion.
  This file is listed in `.swe-ignore`, so it was reviewed by hand
  rather than through the linter; a metaphor ("back door around the
  nonce") introduced while drafting was caught and rewritten.
- `swe/README.md`: notes the `ignored` verdict in "Check commits
  against a clean lint" and cross-references it from "Exempt a whole
  file from every check".
- `swe/tests/commit_check_test.sh` and `swe/tests/unit_worklist_test.sh`:
  new coverage for `--reason` validation, the `ignored` happy path and
  its ledger row, partial-coverage downgrade, the hook's passing
  summary and reason output, blob-keyed invalidation on edit, a mixed
  clean+ignored commit, a reason containing a tab/newline, and
  `block_on_deterministic` excluding an ignored file while still
  blocking a `clean` one with a real deterministic error.
- `swe/.claude-plugin/plugin.json`: version `0.25.1` → `0.26.0`.

## What was found along the way

- `.swe-ignore` is left exactly as it was — a separate, coarser
  mechanism — per the plan's minimal-scope recommendation; the README
  now says so explicitly.
- All 21 `swe/tests/*.sh` suites pass (commit_check_test.sh: 119,
  unit_worklist_test.sh: 60), `scripts/check-unshipped.sh` is clean
  post-release, and `bash -n` / `ast.parse` passed on the two edited
  scripts before commit.
- No open question from the issue needed a `tsk decision`: the
  proposal was concrete enough to implement directly; the few open
  calls (partial-coverage behaviour, `.swe-ignore` scope,
  `block_on_deterministic` handling) are resolved in the plan document
  and reflected in the code and docs above.
