# Report: abstract-location fires on the protocol name REST

Mission: M-SWE-ABSTRACT-LOCATION-REST
Issue: software-english#31 — https://github.com/jimbarritt/software-english/issues/31 (closed)

## What changed

### software-english

- `rules/core-rules.toml`: added `case_sensitive_exemptions = ["REST"]` to
  the `abstract-location` rule, and extended its `description` with a
  sentence documenting the exemption.
- `spec/SPEC.md` §5.2: added a paragraph documenting that `REST` written in
  capitals is exempt, as the protocol name rather than the verb.
- Commit [70a8214](https://github.com/jimbarritt/software-english/commit/70a8214)
  ("abstract-location: exempt REST, the protocol name, from the
  rest/rests/rested word list"), `closes #31`. Pushed to `main`.
- Released [v0.0.35](https://github.com/jimbarritt/software-english/releases/tag/v0.0.35)
  via `release.yml` (workflow run 42287224524, success).

### claude-plugins

- `swe/scripts/software_english_lint.py`, `check_line()`: reads
  `rule.get("case_sensitive_exemptions", [])`; before the subject gate,
  skips a word_list match whose exact (non-lowered) text at that span is
  in the exemption set, guarded by a length check between the original
  line and its lowered form (Unicode case folding can change length,
  desyncing offsets — falls back to no exemption rather than guessing).
  Applies generically to any word_list rule that sets the field; the
  do-support (negation) loop is untouched, since base forms are never
  acronyms.
- `swe/tests/anthropomorphism_gate_test.sh`: extended with real-data cases
  (fires on "The config rests in the environment file.", "This rests on
  the cache."; clean on "The service exposes a REST API.", "The request
  is a REST call.", and the issue's own sentence) and a scratch-catalogue
  pair proving `case_sensitive_exemptions` works and that its absence
  still fires on `REST` (proving the `.get` default). 67 assertions pass
  in this file; the full `swe/tests/*_test.sh` suite (20 files) passes
  against the new software-english checkout.
- `swe/software-english.json`: pin bumped v0.0.34 → v0.0.35.
- `swe/.claude-plugin/plugin.json`: version bumped 0.26.3 → 0.26.4.
- Commit [e5fc15f](https://github.com/jimbarritt/claude-plugins/commit/e5fc15f)
  ("swe: honour case_sensitive_exemptions in abstract-location, bump pin
  to v0.0.35"). Pushed to `main`.
- Released [swe-v0.26.4](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.26.4)
  via `release-plugin.yml` (workflow run 42288052328, success).

## Verification

- The issue's own example sentence does not actually trigger the bug
  as written ("adapter" is not a structure noun, so the lookback gate
  fails independently). Verified the real bug with sentences that do
  pass the gate ("The service exposes a REST API.", "The request is a
  REST call.") and used those as the regression tests, plus the issue's
  own sentence as a clean-stays-clean guard.
- Confirmed `rest`/`rests`/`rested` appear nowhere else (no other rule's
  word_list, not in `vocabulary/banned.tsv`), so this is the only place
  needing the fix.
- Confirmed the acronym has no inflected forms; the exemption is the
  exact token `REST` only. Lowercase `rest`, `rests`, `rested` still
  fire exactly as before.

## Lint findings along the way

My own new prose (the `core-rules.toml` description sentence, the
`SPEC.md` §5.2 paragraph, the `check_line()` comment, and the test file's
header/section comments) is deterministic-tier clean. One inference-tier
candidate recurred across all three new passages — a `no-unanchored-
reference` candidate on a short definite phrase ("the transfer", "the
protocol", "the line", "the offsets", "the distinction") — judged not a
real fault in each case: every one is anchored within the same sentence
or the immediately preceding clause, not a document-wide reference with
no antecedent.

Two files carry pre-existing deterministic lint debt unrelated to this
issue, discovered because linting them requires running against their
whole current content, not just the lines touched (same situation
M-SWE-RESTATES-BLOCK-BELOW recorded for `spec/SPEC.md` two releases ago):

- `rules/core-rules.toml`: 123 deterministic errors, almost all quoted
  examples of banned words inside other rules' own descriptions (e.g.
  "reach", "carry", em dashes) — illustrative text that documents those
  rules, not a fault to fix here. Recorded `failed` (123 findings),
  `partial` coverage (1 of 51 units — the `abstract-location` block I
  changed).
- `spec/SPEC.md`: 23 pre-existing deterministic findings scattered
  through the document (the same count M-SWE-RESTATES-BLOCK-BELOW found).
  Recorded `failed` (23 findings), `partial` coverage (1 of 605 units —
  the new §5.2 paragraph).
- `swe/scripts/software_english_lint.py`: 9 pre-existing deterministic
  findings in other comments throughout the file. The comment-extraction
  worklist groups this file's comments into only 4 degenerate units (one
  spans lines 58-2028), so judging the touched unit in full is not
  practical; judged my own added comment directly instead. Recorded
  `failed` (9 findings), `partial` coverage (1 of 4 units).
- `swe/tests/anthropomorphism_gate_test.sh`: 7 pre-existing deterministic
  findings (quoted examples of the words the test fixtures check for).
  Recorded `failed` (7 findings), `partial` coverage (1 of 24 units).

None of this debt is new; none of it is this issue's scope. Worth a
cleanup issue on its own, as the precedent mission also noted for
`spec/SPEC.md`.

## Decisions

- Exempt `abstract-location` on exact capitalisation of the token `REST`
  only; no adjacency check to `API`/`endpoint`/`call`/`route`/"Web
  Services" (capitals alone are enough — the verb "rest" is never written
  in all capitals in normal prose); no change to `word_list` itself.

## Outcome

Closed software-english#31. No other open issue, on either tracker, is
resolved by this change.
