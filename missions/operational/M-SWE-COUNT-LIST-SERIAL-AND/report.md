# Report for claude-plugins#24: a serial "and"/"or" at the end of a colon list is not split

## Outcome

Fixed and shipped.

- Commit: `9fed58d073dce149791e7c5475c6d50ee9c54397` on `main`
  ("swe: split a serial and/or in a count list's last comma-part",
  `closes #24`).
- Release: `swe-v0.24.2` (plugin.json bumped 0.24.1 -> 0.24.2, workflow
  run https://github.com/jimbarritt/claude-plugins/actions/runs/40725630053,
  success).
- CI: `check-unshipped.yml` run on the push
  (https://github.com/jimbarritt/claude-plugins/actions/runs/40725585506)
  succeeded.
- Issue https://github.com/jimbarritt/claude-plugins/issues/24 closed by
  the commit; commented with commit/tag/summary; `agent:working` label
  removed.

## What changed

`count_list_items()` in `swe/scripts/software_english_lint.py`: when the
colon-list tail comma-splits into two or more parts, the last part is now
checked for a bare "and"/"or" when it had no leading Oxford and/or
stripped. Exactly one such conjunction counts as a serial split (adds one
item); more than one is ambiguous and returns `None` (not reported),
mirroring the existing single-part branch's ambiguity rule. A last part
that did have a leading Oxford and/or stripped is left unsplit, which
guards the pre-existing "an HTTP API, and an event or message API over
Kafka" fixture from over-splitting on its internal "or".

Also updated:
- The function's own docstring, to describe the new rule.
- `swe/docs/agent-guide.md`'s description of `count_list_items()`
  (stale after the fix).
- `swe/tests/define_and_count_candidates_test.sh`: added the issue's
  three fixtures (serial "and" with no Oxford comma: no candidate; the
  same list with an Oxford comma: no candidate; a true mismatch with a
  trailing "gamma and delta": candidate reported) plus one ambiguity-guard
  fixture (two conjunctions in the last part: no candidate).

## Verification

- Traced the patched function by hand (and with a standalone Python
  snippet against the exact fixture sentences) before touching the real
  test file; all five traced cases matched expectations.
- Ran all 13 `swe` test suites: 352 assertions pass, including the
  existing fixtures that guard against over-splitting an Oxford-comma
  last part and against the pre-existing ambiguous-conjunction case.
- `swe/docs/agent-guide.md` is listed in `.swe-ignore`, so `/swe:lint-file`
  does not apply to it; no other prose file was touched.
- `scripts/check-unshipped.sh` confirmed the version bump matched the
  release tag after the release workflow ran.

## Found along the way

Nothing outside scope. No other open issue is resolved by this change.
