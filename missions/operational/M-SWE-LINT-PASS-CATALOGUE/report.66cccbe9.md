# Report: M-SWE-LINT-PASS-CATALOGUE (software-english#22)

## Outcome

Shipped. `software-english#22` closed by commit.

## Commits

- `software-english` [`54e1fda`](https://github.com/jimbarritt/software-english/commit/54e1fda)
  — "Catalogue summary-before-detail; add no-contradiction-between-sections,
  no-precedent-before-subject". Closes #22.
- `claude-plugins` [`97e0917`](https://github.com/jimbarritt/claude-plugins/commit/97e0917)
  — "swe: bump pinned software-english tag to v0.0.28".

## Releases

- `software-english` [`v0.0.28`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.28)
  (via `release.yml`, run [40715855559](https://github.com/jimbarritt/software-english/actions/runs/40715855559), success).
- `claude-plugins` [`swe-v0.24.1`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.24.1)
  (via `release-plugin.yml`, run [40716219855](https://github.com/jimbarritt/claude-plugins/actions/runs/40716219855), success).

## What changed

- SPEC §7.1 "Summary before detail" expanded from one sentence to a full
  rule (general case: every document type, any length; two faults — no
  summary, summary that names only the subject) and given its first
  catalogue entry, `summary-before-detail`.
- SPEC §7.21 "No contradiction between sections" and §7.22 "No precedent
  before its subject" added as new sections, appended after §7.20 (not
  inserted beside a sibling, so no existing section number shifts), each
  with a full catalogue entry.
- All three: `tier = inference-based`, `check = model-judgement`,
  `severity = warning`. `core-rules.toml` now holds 39 rules (was 36).
- `COLOPHON.md` records the reasoning: why §7.21 stays `warning` rather
  than `error` despite its fault including a false fact (unlike
  `no-count-list-mismatch` §7.20, the fault spans sections rather than
  one checkable sentence, with a higher false-positive risk against
  scoped rules, named exceptions, and recorded history), and why §7.1
  keeps its number while §7.21/§7.22 are new entries at the end of §7.
- `claude-plugins`: `swe/software-english.json` pin bumped v0.0.27 →
  v0.0.28; `swe/.claude-plugin/plugin.json` version bumped 0.24.0 →
  0.24.1 (pin-only, no code change, following the precedent of commit
  `cb48544`).

## Checks run

- `python3 -I` `tomllib` check: TOML parses, 39 unique ids, the three new
  ids have the expected tier/check/severity.
- SPEC consistency: both new headings exist, both Contents anchors match,
  every `§N` cross-reference cited in the new text exists.
- New prose checked against Software English itself: no em dash; scanned
  for banned words and anthropomorphism/abstract-location verbs on
  non-human subjects in the diff. Found and fixed two genuine faults
  before commit: an anthropomorphism finding ("where it goes" → "its
  position in a document" in COLOPHON.md) and another ("the fix chooses
  one value" → "the fix keeps one value", in both SPEC.md and
  `core-rules.toml`). Ran `swe/scripts/software_english_lint.py` directly
  against `spec/SPEC.md` and `COLOPHON.md`: all remaining `[error]`
  findings are pre-existing, outside the diff's changed line ranges,
  except one line that matches an existing, unmodified convention used
  3× elsewhere in the same file (`the reader's task`, a possessive the
  literal banned-word check over-matches as a substring of the flat-out
  banned "the reader" — a pre-existing tool limitation, not a regression).
- `claude-plugins`: all 13 `swe` test suites pass against the freshly
  fetched `v0.0.28` data. `scripts/check-unshipped.sh` clean (swe was
  never released before `swe-v0.24.0`... now `v0.24.1`, so nothing
  compares as unshipped either time).

## Found along the way

- `software-english` has no test suite, Makefile, or CI validation
  beyond the manual release workflow; "done" for a catalogue change
  there means the `tomllib`/consistency/lint checks above, since nothing
  automated enforces catalogue/SPEC consistency.
- The repo's intro slide deck
  (`docs/public/presentations/intro/intro-to-software-english.md`)
  states stale rule counts ("36 rules today... 30 inference rules"),
  now 39/33. Left unchanged: out of scope, needs a deck rebuild via its
  own `build.sh`.
- SPEC Appendix A has a pre-existing minor inaccuracy (it omits
  `model-judgement` from its description of which tiers get catalogue
  entries). Pre-existing, left unchanged.

## Out of scope (recommended follow-up, not filed as a new issue)

Noted in the closing comment on `software-english#22`: a separate
`claude-plugins` issue to (a) switch `/swe:lint-file`'s Pass 3
(`swe/skills/lint-file/SKILL.md` lines 160-204) from its own skill-local
ids to these three catalogue ids, and (b) decide whether
`check = model-judgement` should also surface these three rules in
Pass 1/Pass 2's per-unit "inference pending" lists now that the pin has
moved (a possible future `scope = "document"` schema key). Not filed as
a GitHub issue this run, since the ground rules limit this run to one
issue and the original issue's own text treats this as forward-looking,
non-blocking work.
