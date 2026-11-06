# Plan for claude-plugins#24: a serial "and"/"or" at the end of a colon list is not split

## 1. The ask, verbatim

> ## Verdict
>
> False positive, from the `no-count-list-mismatch` candidate locator in
> `software_english_lint.py` (the `--force-inference` candidate lines).
>
> ## Shape
>
> A sentence with a count, a colon, and a comma-separated list that ends in
> "X and Y" with no Oxford comma, where one item before the end has several
> words:
>
> > The service reads from seven sources: alpha, beta, gamma, delta, the
> > Northwind Order Archive, epsilon and zeta.
>
> The list has seven items. The locator prints:
>
>     candidate at line N: count "seven" before a colon list of 6 items
>
> The final "epsilon and zeta" is counted as one item.
>
> ## Expected
>
> No candidate. When the last separator is " and " or " or " with no
> comma before it, the locator counts the two sides as separate items.
>
> ## Proposed fix
>
> In the list splitter that the candidate locator uses, split the last
> comma-separated segment on a top-level " and " / " or " as well. Add test
> fixtures for:
>
> - seven items, a serial "and", no Oxford comma: no candidate;
> - the same list with an Oxford comma: no candidate;
> - a true mismatch ("three sources: alpha, beta, gamma and delta"):
>   candidate reported.

Issue: https://github.com/jimbarritt/claude-plugins/issues/24

## 2. Reading

`count_list_items(tail)` in `swe/scripts/software_english_lint.py` (lines
1716-1763) comma-splits the list tail outside parentheses and double
quotes, strips a leading "and"/"or" off the last part (an Oxford comma),
and then:

- when exactly **one** comma-part remains, it checks that single part for
  a bare "and"/"or": no conjunction gives 1 item, one conjunction gives 2,
  more than one is ambiguous and returns `None` (not reported);
- when **two or more** comma-parts remain, it returns `len(parts)`
  unconditionally, never looking inside the last part for a serial
  conjunction.

That second branch is the bug: "alpha, beta, gamma, delta, the Northwind
Order Archive, epsilon and zeta" comma-splits into 6 parts, the last being
"epsilon and zeta" (no leading and/or, so not an Oxford comma), and the
function returns 6 instead of 7.

A same-shaped existing test guards against over-splitting: "an HTTP API,
and an event or message API over Kafka" has a last part that starts with
"and" (an Oxford comma) and, after that leading and/or is stripped, still
contains an "or". It must NOT be split again, so the fix only applies the
internal-conjunction check when the last part did **not** have a leading
and/or stripped (i.e. not an Oxford comma).

## 3. The code change

Only `count_list_items` changes. After the existing comma split and the
existing leading-and/or strip on the last part, track whether that strip
fired (Oxford comma), and when it did not, look inside the last part for
exactly one bare "and"/"or":

- 0 comma-parts beyond the single-part branch: unchanged (that branch is
  untouched).
- Last part had a leading and/or stripped (Oxford comma): no further
  split; return `len(parts)` as today.
- Last part had no leading and/or, and contains exactly one bare
  "and"/"or": return `len(parts) + 1`.
- Last part had no leading and/or, and contains more than one bare
  "and"/"or": ambiguous, return `None` (not reported) -- mirrors the
  single-part branch's existing ambiguity rule.
- Otherwise (no conjunction found): return `len(parts)` as today.

Reuse the same `\s+(?:and|or)\s+` pattern already used for the
single-part branch, so "top-level" conjunction detection is identical in
both branches (does not special-case parentheses/quotes beyond what the
comma splitter already strips).

Update the function's docstring to state the new rule for the multi-part
case.

No other function changes: `find_count_list_mismatches`,
`COUNT_COLON_LIST`, `COUNT_WORDS`, and the module's rule-list docstring
(lines 55-66) all stay as they are.

One doc line is stale after this: `swe/docs/agent-guide.md` (around lines
207-208) describes the old "and/or split only when exactly one part
remains" behaviour. Update it to describe the new rule: a last part with
no leading and/or is also checked for a single bare and/or.

## 4. Fixtures (traced against the new logic)

| Sentence | Stated | Old count | New count | Candidate? |
|---|---|---|---|---|
| "The service reads from seven sources: alpha, beta, gamma, delta, the Northwind Order Archive, epsilon and zeta." | 7 | 6 (false positive) | 7 | No |
| "The service reads from seven sources: alpha, beta, gamma, delta, the Northwind Order Archive, epsilon, and zeta." | 7 | 7 | 7 (Oxford, unchanged) | No (regression guard) |
| "The service reads from three sources: alpha, beta, gamma and delta." | 3 | 3 (missed mismatch) | 4 | Yes: "colon list of 4 items" |

Optional ambiguity guard: "The service exposes three endpoints: read,
write and delete or purge." -- last part has two conjunctions, so the
count is `None` and nothing is reported.

Existing fixtures in `swe/tests/define_and_count_candidates_test.sh`
(lines 150-168) re-traced and unaffected: the two-conjunction ambiguous
case, the Oxford-comma case with an internal "or" in the last part (must
stay unsplit), and the cases with no count word or a too-long noun
phrase.

Add the new fixtures to that file, matching its existing `assert`/
`has_cand`/`no_cand` style exactly:
- a `has_cand` assertion for the true-mismatch sentence under the
  true-positives block for `no-count-list-mismatch`;
- two `no_cand` assertions (serial "and" without Oxford comma; same list
  with an Oxford comma) under the true-negatives block;
- optionally, the ambiguity-guard `no_cand` case.

## 5. Tasks

1. Fix `count_list_items` in `software_english_lint.py`.
2. Update its docstring.
3. Update the stale line in `swe/docs/agent-guide.md`.
4. Add the four test fixtures to
   `swe/tests/define_and_count_candidates_test.sh`.
5. Run the test suite and `/swe:lint-file` on touched prose, plus
   `scripts/check-unshipped.sh`.
6. Bump `swe`'s `version` in `swe/.claude-plugin/plugin.json` (patch:
   0.24.1 -> 0.24.2 per the plan; confirm the current value before
   editing).
7. Commit with `closes #24`, push `main`.
8. Run `release-plugin.yml` for `swe`, poll to completion.
9. Close the loop on the issue, record the outcome in the ledger.

No open question in the issue needs a `tsk decision add` entry; the issue
is a bug report with a proposed fix the plan follows.
