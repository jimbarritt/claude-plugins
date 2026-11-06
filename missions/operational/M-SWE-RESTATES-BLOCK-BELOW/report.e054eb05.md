# Report: software-english#30

## Outcome

Closed. Added a new inference-based rule, `no-scope-preamble` (SPEC
§7.23), to `rules/core-rules.toml` and `spec/SPEC.md`, catalogued at
the end of §7 so no existing rule's number changed. It covers a
sentence whose subject is the document, the section, or the block it
is in, and whose verb states what that block contains, where the
block after it already shows the same content ("This section lists
every value the installation requires."). No existing rule owned the
shape: `no-remark-about-the-writing` (§5.3) already excludes a
cross-reference like "§4 lists the retry limits" on purpose, and its
trigger set is navigational/copular wording, not a plain declarative;
`vacuous-classification-property`'s count signpost (§7.6) needs a
number word at the head of the sentence; `summary-before-detail`
(§7.1) covers only the document's own opening paragraph. Added
reciprocal "Distinct from no-scope-preamble" cross-references to all
three siblings' TOML descriptions and SPEC text.

## Commits and releases

- `jimbarritt/software-english@44831c5` — "Catalogue a scope preamble
  as no-scope-preamble (SPEC §7.23)". Closed issue #30.
- Release [v0.0.34](https://github.com/jimbarritt/software-english/releases/tag/v0.0.34).
- `jimbarritt/claude-plugins@b7c225e` — "swe: bump software-english
  pin to v0.0.34" (the change touched `rules/core-rules.toml`, which
  the `swe` plugin fetches, so its pin and version moved too).
- Release [swe-v0.26.3](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.26.3).

## What changed

- `rules/core-rules.toml`: new `no-scope-preamble` rule block, plus
  one-sentence cross-references added to `no-remark-about-the-writing`,
  `vacuous-classification-property`, and `summary-before-detail`.
- `spec/SPEC.md`: new §7.23 section, Contents entry, and
  cross-reference bullets/sentences in §5.3, §7.1, and §7.6.
- `COLOPHON.md`: new rationale subsection for the rule.
- `docs/public/presentations/intro/intro-to-software-english.md` and
  its built `build/intro-to-software-english.{html,pdf}`: rule count
  updated 42→43 total (6 deterministic, unchanged). Rebuilt with
  `build.sh` (Marp via `npx`, Playwright's pre-installed Chromium for
  the PDF step) — both the HTML and PDF are real rebuilds.
- `swe/software-english.json` and `swe/.claude-plugin/plugin.json` in
  `claude-plugins`: pin bumped to `v0.0.34`, plugin version 0.26.2 →
  0.26.3.

## Verification

- `rules/core-rules.toml` parses as TOML; rule count is 43 total, no
  duplicate ids — confirmed by direct parse.
- Every claim in the plan (insertion points, neighbouring rule text,
  SPEC.md section boundaries, the lack of a version file in
  software-english, the real wording of `templates/reference.md:30`)
  was checked directly against the files before editing.
- All 21 `swe/tests/*.sh` suites pass (590 individual assertions, 0
  failed) after the pin and version bump.
- `scripts/check-unshipped.sh` passed after the release (`swe-v0.26.3`
  matches the bumped `plugin.json` version, confirmed after
  re-fetching tags into the local clone).

## Lint findings along the way

The new content (the rule block, the SPEC §7.23 section, the three
reciprocal cross-references, the COLOPHON entry) is deterministic-
and inference-tier clean for every unit it added or touched (24 units
in SPEC.md, 4 new units in COLOPHON.md, 1 touched unit in the intro
deck). `COLOPHON.md` needed one round of fixing: my own new text used
`goes` ("It goes at the end of §7...") for a non-human subject, caught
as anthropomorphism by the deterministic tier; reworded to "It is the
last entry in §7...". Recorded `clean` for the full, re-read
`COLOPHON.md` (71 of 71 units) and for the intro deck (partial: 1 of
146 units — the one line changed).

Two older files had pre-existing lint debt unrelated to this issue,
discovered only because the local git-common-dir's lint ledger is
empty in this fresh clone (it does not travel with the repository), so
recording a verdict for `spec/SPEC.md` required running the lint
against its whole current content, not just the lines touched:

- `spec/SPEC.md` has 23 pre-existing deterministic findings scattered
  through roughly 2,300 lines — mostly `the reader` and `holds` in
  plain (unquoted) normative prose, predating the commits that added
  those words to `vocabulary/banned.tsv`. Fixing this is a sizeable,
  unrelated cleanup, not this issue's scope (same finding the prior
  mission, M-SWE-CONTRAST-PAIR-SPLIT, recorded for this same file two
  releases ago — the debt is still there, one finding fewer than
  before by coincidence of line renumbering, not a fix). Recorded
  honestly as `failed` (not silently as `clean`) with the real finding
  count, and `partial` coverage (24 of 604 units — the units I
  actually added or touched) in the lint ledger, and said so in the
  closing comment on the issue, in case it is worth its own cleanup
  issue.

No `tsk decision add` beyond the one design decision was needed: the
issue stated a fix direction, and the plan resolved the remaining
choice (a new rule id, since none of the three candidate siblings'
trigger or exclusion set covered the shape without widening it past
what each sibling's own "report under X only" boundary allows).
