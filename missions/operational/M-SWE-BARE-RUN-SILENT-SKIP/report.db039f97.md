# Report: claude-plugins#34, a bare linter run states what it did not check

## Outcome

Shipped. Commit `dd3012e0fd2673f63052da4a5be656e1bb19231d` on
`jimbarritt/claude-plugins` `main`, closes claude-plugins#34. Released as
`swe-v0.26.6` via `release-plugin.yml` run #66 (success).

## What changed

`swe/scripts/software_english_lint.py`:

- New helper `applicable_inference_rules(rules, plugin_rules, is_conversational)`,
  factored out of the `--force-inference` block, so the bare-run skip count
  and the force-path rule count are computed from one place and always agree.
- A bare run (neither `--force-inference` nor `--advise-inference`) now ends
  with a trailing line: `swe: inference tier not run; N rule(s) need model
  judgement; run /swe:lint-file <file>` (no filename for a multi-file or
  non-file source). Printed after the findings, and after `--count`'s
  one-line summary. Silent when there is no prose to judge in any source, or
  when the catalogue holds no model-judgement rules — nothing was skipped
  either way. Plain text, not finding-shaped, so a `grep -c '\[warning\]'`
  or a findings-only scan does not miscount it as a pending rule.
  `--force-inference`, `--advise-inference`, and `--record-lint-result` are
  all unaffected; exit codes are unchanged.
- Module docstring gained a paragraph documenting this.

`swe/tests/commit_check_test.sh`:

- Fixed one pre-existing assertion whose `grep -c "tabbed.md"` picked up the
  new trailing line as a second match (the hook's advisory deterministic
  check now names the single staged file); narrowed to match only the
  ledger's own `ignored:` summary line.
- Added a new section (9 assertions) covering the trailing line itself: bare
  run wording, `--count` interaction, absence under `--force-inference`,
  `--advise-inference`, and `--record-lint-result`, the two-named-files
  wording, the no-prose case, and that N agrees with the `--force-inference`
  count.

`swe/docs/agent-guide.md`: one paragraph telling an agent that a clean bare
run is a deterministic-only result, not a verdict on the whole file.

`swe/.claude-plugin/plugin.json`: version `0.26.5` -> `0.26.6`.

## Found along the way

`swe/scripts/software_english_lint.py` extracts only `#`-prefixed line
comments as prose for a `.py` file (`COMMENT_PREFIXES`/`extract_comments()`);
triple-quoted docstrings are never linted by this tool, in this file or any
other `.py` source it checks. The new module-docstring paragraph and the new
function's own docstring are therefore outside what the tool itself ever
inspects; the one new `#`-comment block (explaining the bare-run condition)
was judged against the inference rules by hand and is clean, and a
whole-file `--force-inference` pass confirmed no deterministic finding in
any line this change touched.

The file as a whole is not clean: a full-file run surfaces roughly ten
pre-existing deterministic findings (`gate`, `carries`, `sits`, `leave`,
`arrive`, an em dash) in long-standing `#` comments far from this change,
none introduced by it. Fixing those is unrelated to claude-plugins#34 and
was left alone; recording a ledger "clean" verdict for the whole file was
not attempted, since it would be false. No commit-check block follows: the
default `commit-check.paths` is `*.md`, so a staged `.py` file is outside
the hook's scope regardless.

`agent-guide.md` is itself listed in the repo's own `.swe-ignore`, so it
needs no ledger row.
