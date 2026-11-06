# claude-plugins#20: numbered unit worklist for the inference-tier pass

[Issue #20](https://github.com/jimbarritt/claude-plugins/issues/20), opened
by `jimbarritt-pleo` (trusted collaborator), claimed by the
self-maintaining-repo Routine on 2026-10-23.

## The ask, verbatim

> Verdict: feature request
>
> The nonce proves that a file has not changed since the lint ran. Nothing
> proves that the inference-tier pass judged the whole file.
> --record-lint-result clean writes the same ledger row for a pass that judged
> one edited section and a pass that judged every paragraph, so a fault outside
> the edited section can be recorded clean.
>
> On a long document the --force-inference output is one large block of rule
> text. The runtime truncates it, and the pass then judges whatever the located
> candidates point at.
>
> Proposal:
>
> - --force-inference prints the document as a numbered worklist of prose
>   units: one per heading and one per paragraph outside a code fence. It
>   prints the total.
> - --record-lint-result requires --units-judged N, and rejects a record whose
>   N does not match the total printed for that blob, with exit 4, the same as
>   a stale or reused nonce.
> - A partial pass declares itself (--units-judged 12 of 60), and the ledger
>   records it as partial, not clean.
>
> Secondary benefit: the rules print once and the units print once, so a pass
> on a long document has a finite structure to walk.

## Reading

A coverage proof to sit alongside the existing staleness proof (the nonce).
The nonce already binds a verdict to one exact blob; this adds a second
binding — that the caller saw the full enumeration of what had to be judged
for that blob, not just that the blob hadn't changed underneath it.

## Plan (from an Opus Plan subagent, which read the real code first)

The subagent read `swe/scripts/software_english_lint.py` directly rather
than trusting the README, and confirmed the existing exit-4 convention
(`record_lint_result`, four checks, none of which consume the nonce — it is
consumed only after every check passes), the existing structure parsers
(`FENCE`, `HEADING`, `prose_lines()`, `register_blocks()`), and the existing
test conventions (`swe/tests/commit_check_test.sh`: bash, `PASS/FAIL`,
`assert`, fixture repo).

**Design, built on `register_blocks(list(prose_lines(text, exemptions)))`
(the same parse the candidate detectors already use):**

- A new `prose_units()` returns `(kind, first_line, last_line, text)` per
  block: `heading`, `paragraph`, `list-item` (one per top-level list item,
  nested bullets/continuations folded into the parent), `table` (one per
  table block). `hr` blocks are not units. Fenced, indented, blockquoted and
  skip-marker content is never a unit, because `prose_lines()` already drops
  it before `register_blocks()` sees it — reuses the existing fence-toggle
  weakness (a ` ``` ` line inside a `~~~` fence still toggles) rather than
  fixing it; noted as a known limit, not fixed here.
- `--force-inference`, single-file case only (the only case that mints a
  nonce): after the existing rule block, print one finding-shaped line per
  unit at line 0 with a new reserved id `[inference-unit]`
  (`unit N of M, <kind>, line(s) <range>: <joined unit text>`), a separator
  line before them, and `swe-lint-units: M` just before the nonce line. The
  existing `[inference-pending]` summary line gains a trailing clause when
  units were printed. Multi-file `--force-inference` and `--advise-inference`
  are unchanged (no nonce, so no total to bind).
- The nonce entry (`lint-nonces.json`) gains `"units": M`, bound to the exact
  `(toplevel, path, blob)` the nonce already carries.
- New required flag `--units-judged`, accepting `"N"` (a full-coverage claim)
  or `"N of M"` (a declared partial, quoted on the shell line). No `N/M`
  form — kept to the one literal syntax the issue itself uses, to avoid
  inventing a second accepted spelling nobody asked for. A malformed value or
  `N > M` is a malformed call: exit 2 (matches the existing "command itself
  is malformed" convention), not exit 4.
- `record_lint_result` gains, after the existing blob check, in order, all
  exit 4, matching the existing one-`swe:`-line-per-reason convention:
  1. no `--units-judged` given;
  2. the nonce predates this change (no `"units"` key — only possible for a
     nonce minted in the window between an upgrade and its first use);
  3. a declared `M` that doesn't match `entry["units"]`;
  4. a bare `N` that doesn't equal `entry["units"]` (a bare number must be a
     full pass; a partial has to say so with `of M`).
  Checks 3 and 4 **do** consume the nonce (unlike the four pre-existing
  checks): a units mismatch means the caller didn't walk the real worklist
  for this blob (stale output, a truncated read), so it has to re-run Step 3
  regardless, and consuming stops a guess-and-retry loop against one nonce.
  Checks 1 and 2 do not consume it, matching the existing missing-`--nonce`
  check.
- Status derivation: `requested == "failed"` always records `"failed"`
  whatever the coverage (a fault found in part of a file still fails it);
  `requested == "clean"` records `"clean"` only when `N == M`, else
  `"partial"`. `units_total` and `units_judged` are recorded on every row
  regardless of status. `"partial"` is derived, never an argparse choice.
- Ledger row gains `units_total`, `units_judged`. `pre-commit.sh` needs **no
  change**: it already blocks on `status != "clean"`, so `"partial"` already
  blocks, with the existing `recorded status: partial` message.
- Backward compatibility: `--units-judged` is required on every
  in-repository call (every call that needs a nonce); outside a repository
  the existing no-nonce-needed exit-0 path is unchanged. Existing ledger rows
  with no `units_*` fields stay valid and keep unblocking their exact
  already-judged blob — the hook reads only `path`/`blob`/`algo`/`status`.
- Front matter, setext headings, the fence-toggle weakness: left as today's
  existing behaviour, documented as known limits, not fixed by this issue.

**Files:**
`swe/scripts/software_english_lint.py` (implementation);
`swe/skills/lint-file/SKILL.md` (Steps 3-6);
`swe/tests/unit_worklist_test.sh` (new, ~22 cases);
`swe/tests/commit_check_test.sh` (every in-repo `--record-lint-result` call
needs `--units-judged` added);
`swe/docs/agent-guide.md`, `swe/README.md` (docs);
`swe/.claude-plugin/plugin.json` (version `0.20.0` -> `0.21.0`).

## Decisions taken on the plan's open questions

The subagent flagged eight open questions and a recommendation for each.
This is one coherent reading of a feature request with a clear intended
shape, not two readings that lead to materially different work, so the
Routine decided these itself rather than escalating, taking the subagent's
own recommendation in every case:

- List items and tables count as units (not just headings/paragraphs as the
  issue's own prose names, since list/table content is most of this repo's
  real prose and the issue's intent — full coverage — would otherwise have a
  gap).
- The worklist prints each unit's text, not just its kind and range (matches
  "prints the document as a numbered worklist of prose units" literally).
- A units mismatch consumes the nonce.
- A partial `failed` pass still records `failed`; `units_*` are recorded
  regardless of status.
- Front matter keeps today's behaviour (one paragraph unit via the existing
  `HR_LINE` match on `---`).
- Multi-file `--force-inference` prints no worklist (single-file only,
  matching the nonce).
- The pre-commit hook and old ledger rows are left alone; no new requirement
  on a row recorded before this change.
- `--units-judged` accepts exactly `"N"` or `"N of M"` — no `N/M` shorthand.

## Status

Shipped, single pass, no escalation. Implemented essentially as planned,
with no deviation from the design above. Smoke-tested by hand against a
throwaway fixture before touching the real test suites (full pass,
partial pass, wrong total, malformed value, N > M, empty file,
multi-file, `--advise-inference`) — every case matched the design on
the first try.

`swe/tests/unit_worklist_test.sh` (new, 47 assertions): the worklist's
unit count and ordering on a fixture exercising every block kind
(heading, wrapped paragraph, two fence styles, an indented block, a
blockquote, a skip-marker line, a nested list, a table), findings-shaped
invariants, the nonce entry's own stored `units`, a 0-unit file, a code
file's comment-run units, `--advise-inference` printing neither
worklist nor total, every `--units-judged` failure mode (missing,
mismatched bare count, mismatched declared total, the mismatch
consuming the nonce), a partial and a failed recording with their
`units_total`/`units_judged` fields, a malformed value and `N > M`
(exit 2), a pre-upgrade nonce with no stored `units` key (hand-written
via a Python one-liner, since no real nonce predates this change), the
outside-a-repository case needing no `--units-judged`, and the
pre-commit hook blocking a `partial` row the same as `failed`.
`swe/tests/commit_check_test.sh` updated throughout: every in-repository
`--record-lint-result` call needed `--units-judged` added, `nonce_for()`
changed to return both the nonce and the units total from one
`--force-inference` run (two separate runs would supersede the first
nonce), several call sites changed from plain command substitution to
`read -r nonce units <<< "$(nonce_for ...)"` so a token meant to be
compared as a bare nonce never silently became `"<nonce> <units>"`.
All ten suites pass, both locally and against the real fetched
`swe-v0.21.0` tag.

`swe/docs/agent-guide.md`, `swe/skills/lint-file/SKILL.md`, and
`swe/README.md` updated; two self-check catches in `SKILL.md`, both
found only by running the real linter against the drafted prose: "you
actually judged" ("actually" is a banned word) and "is missing" (an
adjectival use, not a verb, that still trips the deterministic
`no-continuous-tense` pattern — the same false-positive shape prior
sessions' task files record for this same rule). `--diff --added-only`
reports zero errors/warnings on every changed line across all three
docs after both fixes.

Version bumped `0.20.0` -> `0.21.0`. Shipped on `main` at
[`719a8a9`](https://github.com/jimbarritt/claude-plugins/commit/719a8a9c29322156098e76c06a196704feb05e5d),
which closed the issue automatically (`closes #20`), released as
[`swe-v0.21.0`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.21.0).
`agent:working` label removed on close. `software-english`#21, filed
a few minutes after this issue by the same author, left unclaimed —
one issue per run.
