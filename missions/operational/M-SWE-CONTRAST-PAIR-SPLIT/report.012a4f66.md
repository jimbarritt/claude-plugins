# Report: software-english#28

## Outcome

Closed. Added a new inference-based rule, `no-split-contrast-pair`
(SPEC §8.4), to `rules/core-rules.toml` and `spec/SPEC.md`, catalogued
at the end of §8 so no existing rule's number changed. Did not widen
`no-clipped-sentence-run`: its pronoun-chain trigger and list-item
exclusion are correct for the fault it targets, and the issue's shape
has neither a pronoun chain nor a length dependency — widening it
would have raised false positives across every short-sentence run
that is not this fault.

## Commits and releases

- `jimbarritt/software-english@7429f08` — "Catalogue a split contrast
  pair across short sentences (SPEC §8.4)". Closed issue #28.
- Release [v0.0.33](https://github.com/jimbarritt/software-english/releases/tag/v0.0.33).
- `jimbarritt/claude-plugins@a5e3cc8` — "swe: bump software-english
  pin to v0.0.33" (the change touched `rules/core-rules.toml`, which
  the `swe` plugin fetches, so its pin and version moved too).
- Release [swe-v0.26.1](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.26.1).

## What changed

- `rules/core-rules.toml`: new `no-split-contrast-pair` rule block,
  plus a one-sentence cross-reference added to `no-clipped-sentence-run`'s
  description.
- `spec/SPEC.md`: new §8.4 section, Contents entry, and a
  cross-reference sentence in §3.6.
- `COLOPHON.md`: new decision-record entry for the rule.
- `docs/public/presentations/intro/intro-to-software-english.md` and
  its built `build/intro-to-software-english.{html,pdf}`: rule counts
  updated 35→36 inference, 41→42 total (6 deterministic, unchanged).
  Rebuilt with `build.sh` (Marp via `npx`, Playwright's pre-installed
  Chromium for the PDF step) — both the HTML and PDF are real rebuilds,
  not hand edits.
- `swe/software-english.json` and `swe/.claude-plugin/plugin.json` in
  `claude-plugins`: pin bumped to `v0.0.33`, plugin version 0.26.0 →
  0.26.1.

## Verification

- `rules/core-rules.toml` parses as TOML; rule count is 42 total, 36
  inference-based, 6 deterministic (unchanged) — confirmed by direct
  parse before and after the change.
- Every claim in the plan (insertion points, neighbouring rule text,
  SPEC.md section boundaries, the shared-lock/exclusive-lock example
  already excluded by §8.1, the `no-out-of-scope-comparand` rule id at
  §7.10) was checked directly against the files before editing, not
  taken on the planning subagent's word alone.
- All 21 `swe/tests/*.sh` suites pass (590 individual assertions, 0
  failed) after the pin and version bump.
- `scripts/check-unshipped.sh` passed after the release (confirmed
  `swe-v0.26.1` matches the bumped `plugin.json` version, once tags
  were re-fetched into the local clone).

## Lint findings along the way

The new content (the rule block, the SPEC §8.4 section, the two
cross-references, the COLOPHON entry) is deterministic- and
inference-tier clean. Getting there took three rounds of fixing banned
words my own new text introduced ("two things", "the reader", an
anthropomorphism match on "moves" for an abstract subject) — each
caught by running the deterministic lint after drafting, not by
guessing.

Two older files had pre-existing lint debt unrelated to this issue,
discovered only because the local git-common-dir's lint ledger is
empty in this fresh clone (it does not travel with the repository), so
recording a verdict for either file required running the lint against
its *whole* current content, not just the lines touched:

- `COLOPHON.md` had nine deterministic findings: one genuine stray use
  of a since-banned word (`holds`, fixed to `contains`) and eight
  double-quoted illustrative examples of banned phrases, inside a
  decision record that must quote the exact phrase being discussed.
  Converting the quotes to backtick code spans (SPEC §6.2's literal
  token exemption) fixed all eight with no change in wording. Recorded
  `clean`, 67 of 67 units, in the lint ledger.
- `spec/SPEC.md` has 22 pre-existing deterministic findings scattered
  through roughly 2,300 lines — mostly `the reader` and `holds` in
  plain (unquoted) normative prose, predating the commits that added
  those words to `vocabulary/banned.tsv`. Fixing this is a sizeable,
  unrelated cleanup, not this issue's scope. Recorded honestly as
  `failed` (not silently as `clean`) with the real finding count, and
  `partial` coverage (15 of 581 units — the units I actually added or
  touched) in the lint ledger, and said so in the closing comment on
  the issue, in case it is worth its own cleanup issue.

No `tsk decision add` was needed: the issue stated the fix direction
itself ("judge a unit... or add a worked example"), and the plan
resolved that choice (new rule, because the worklist unit scoping was
already correct — `claude-plugins`' lint-file worklist already treats
a list item as one unit; the gap was purely in the rule data).
