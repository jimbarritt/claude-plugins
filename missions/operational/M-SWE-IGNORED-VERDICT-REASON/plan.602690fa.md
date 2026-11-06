# Plan: `ignored` verdict with a mandatory `--reason`

Issue: claude-plugins#32, "Ledger: add an \"ignored\" verdict with a mandatory reason".
https://github.com/jimbarritt/claude-plugins/issues/32

## The ask (verbatim)

> The ledger records two verdicts per file, `clean` and `failed`. There is a third real case: a file that was judged, breaks rules, and must not be rewritten. The common example is a document of verbatim quoted source. The quoted wording is the artefact, and every deterministic error is inside the quotation.
>
> That file has three outcomes today, all wrong:
>
> - record `clean`, which falsifies the ledger;
> - record `failed`, which blocks the commit;
> - add the path to `.swe-ignore`.
>
> `.swe-ignore` is a blanket path exclusion. It records no reason, no decision, and no evidence the file was read. A later edit that introduces a real fault is exempt as well.
>
> Proposal: `--record-lint-result ignored --reason "<text>"`, with the reason mandatory. It satisfies the commit hook. It stays keyed to the blob in the way `clean` is, so any edit to the file invalidates the record. The result is an auditable row: the file was judged and deliberately exempted. Exemptions can then be reviewed one by one, which a path glob does not allow.

## Reading

`ignored` is a third verdict, proved the same way as `clean`: a nonce for the
exact blob plus a `--units-judged` claim, a row keyed by `(path, blob)`. It
differs from `clean` in three ways: the row carries a required `reason`;
`--findings` can be non-zero; the pre-commit hook lets it through and names
it and its reason in the output, so the exemption is visible rather than
silent. `.swe-ignore` is left as it is — a separate, coarser mechanism.

A partial `ignored` (not every worklist unit judged) downgrades to
`partial`, exactly as a partial `clean` does: any verdict that lets a
commit through needs full coverage; only `failed` does not.

## Plan

1. `software_english_lint.py` argparse (~2362): add `"ignored"` to
   `--record-lint-result` choices; add a `--reason` flag (default `None`).
2. `main()` validation (~2379): reject (exit 2, nonce unspent) a `--reason`
   given with any verdict but `ignored`, and an `ignored` verdict given
   with no non-empty `--reason`.
3. `record_lint_result()` (~421-560): accept `reason=None`; downgrade rule
   becomes `status in ("clean", "ignored") and partial`; add `"reason"` to
   the row only for `ignored`; include the reason in the success line.
   Update the module docstring (~134-181) to document the new verdict.
4. `pre-commit.sh`: bump `swe-commit-check-version` to 3; header comment
   and block message cover `ignored`; `check_ledger.py` treats
   `status in ("clean", "ignored")` as passing and emits ignored
   path+reason pairs; success line names clean/ignored counts and lists
   each ignored file with its reason; `block_on_deterministic` excludes
   `ignored` files from the deterministic-tier block.
5. `swe/skills/lint-file/SKILL.md` Step 5: when to use `ignored` (errors
   that fixing would destroy the artefact, e.g. verbatim quotation; ask
   the user first if they have not already asked for the exemption),
   command shape with `--reason`, partial behaviour, exit-2 cases. Step 6:
   report an `ignored` file as such, quoting the reason, not as clean.
6. `swe/docs/agent-guide.md`, "The commit check": ledger schema, command
   shape, blocking rule, partial rule, passing-commit output, hook version
   bump, `block_on_deterministic` note.
7. `swe/README.md`: note the `ignored` verdict in "Check commits against a
   clean lint"; optionally cross-reference it from "Exempt a whole file".
8. Tests, `swe/tests/commit_check_test.sh`: missing/blank `--reason` with
   `ignored` (exit 2, nonce unspent); `--reason` with `clean`/`failed`/no
   verdict (exit 2); happy path records `ignored` + reason + findings;
   success line text; a `clean` row has no `reason` key; hook-level: a
   staged `ignored` file lets the commit through with the new summary
   line, an edit after recording re-blocks it, a mixed clean+ignored
   summary, a tab/newline in the reason stays one line, and
   `block_on_deterministic: true` with a deterministic error only inside
   an `ignored` file still lets the commit through (while a `clean` row on
   the same content still blocks). Existing exact-line assertion for the
   no-`ignored` case stays unchanged.
9. Tests, `swe/tests/unit_worklist_test.sh`: a partial `ignored` records
   as `partial` (still carries `reason`) and blocks the commit the same
   way a partial `clean` does.
10. Bump `version` in `swe/.claude-plugin/plugin.json` (not
    `marketplace.json`) in the shipping commit.
11. Run `swe/tests/commit_check_test.sh`, `swe/tests/unit_worklist_test.sh`,
    `swe/tests/skill_frontmatter_test.sh`, and
    `scripts/check-unshipped.sh`; release `swe` via `release-plugin.yml`.

No open question in the issue to log as a decision — the proposal was
concrete enough to implement directly; the few open calls (partial-coverage
behaviour, `.swe-ignore` left alone, `block_on_deterministic` handling) are
resolved above rather than left for the issue author.
