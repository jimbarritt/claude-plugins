# Report: software-english#24, reader-reaction prediction rule

## Outcome

Shipped. `software-english` v0.0.30; `claude-plugins` `swe` v0.24.7.

## Commits

- `software-english` `7cc8331` — added `no-reader-reaction-prediction` to
  `rules/core-rules.toml`, expanded SPEC §5.3 in place, added 5 rows to
  `vocabulary/banned.tsv`, added a COLOPHON.md section, bumped the intro
  deck's rule counts (33→34 inference, 39→40 total) and rebuilt it.
  `Closes #24`.
- `software-english` `bb6c43f` — merge commit resolving a concurrent push
  (another session's `a8b7c6f`, retitling the intro deck's map slide to
  "System Map"). Only the built PDF conflicted as binary; the source `.md`
  auto-merged cleanly. Resolved by rebuilding the deck fresh from the
  merged markdown source so both changes' text landed in the regenerated
  HTML/PDF, rather than picking one side of the binary.
- `claude-plugins` `fe729a9` — pinned `swe/software-english.json` to
  `v0.0.30`, bumped `swe/.claude-plugin/plugin.json` to `0.24.7`, added
  `swe/tests/reader_reaction_test.sh`.

## Releases

- `software-english` `release.yml` → tag `v0.0.30`.
- `claude-plugins` `release-plugin.yml -f plugin=swe` → tag `swe-v0.24.7`.

## What changed

A new inference-tier rule, `no-reader-reaction-prediction` (SPEC §5.3,
warning severity), catalogues the "guess at how someone might react" fault
§5.3 already named but had no rule id for. It covers three shapes: a
prediction with no fact ("that may be exactly what you want"), advice with
no stated consequence ("it helps to keep a terminal open"), and a fact
stated only inside a prediction ("before you find out ..."). §5.3 kept its
section number and was retitled "(mixed)" since both tiers now apply to it.

Five fixed phrases with no plausible correct use went into `banned.tsv`:
`you will be glad`, `you'll be glad`, `before you find out`, `exactly what
you want`, `may be what you want`. Each occurred 0 times in either repo's
prose before being added. `you may find` was already banned, so the
issue's own first example already fired before this change.

Two phrases the issue itself suggested for `banned.tsv` — `it helps to` and
`you may want to` — were deliberately left out and kept inference-only:
`it` can name a component in a correct sentence, and a consequence can
follow in the same sentence, so a flat lookup would misfire on correct
prose. This is recorded as a decision on the mission
(`M-SWE-READER-REACTION-RULE`, against T-03).

## Verification

- `/swe:lint-file` run on `spec/SPEC.md` and `COLOPHON.md`. Both files have
  large pre-existing backlogs unrelated to this change (SPEC.md: 542 prose
  units, 5139 pre-existing warnings; COLOPHON.md: 57 units, 914 warnings),
  so judgement was scoped to the units actually added or changed by this
  issue (SPEC.md units 80-94, the whole of the rewritten §5.3; COLOPHON.md
  units 55-57, the new section). No violation found in either. Recorded as
  `partial` lint-log rows (`15 of 542` and `3 of 57`) rather than `clean`,
  so the ledger does not overstate what was actually checked.
- `swe/tests/reader_reaction_test.sh` (new, 13 assertions): the catalogue
  entry is present after a fetch; each of the 5 new banned rows fires;
  the pre-existing `you may find` row still fires (regression guard);
  `it helps to` and `you may want to` stay clean in sentences with a
  correct use; a stated consequence, a conditional imperative, and a plain
  instruction all stay clean.
- Every `swe/tests/*.sh` suite run against the local `software-english`
  checkout (`SWE_SRC=`): all pass.
- `scripts/check-unshipped.sh`: clean after the release (confirmed
  `swe-v0.24.7` matches the plugin's released version).

## Found along the way

- A concurrent push to `software-english` `main` (another session's
  intro-deck retitle) landed between this session's pull and its own push;
  handled with a merge and a deck rebuild rather than a force-push, per the
  briefing's no-force-push rule.
- `templates/tutorial.md` recommends "You will notice that…", which
  `vocabulary/banned.tsv` already bans — a pre-existing conflict, not
  introduced by this change. Not fixed here; worth its own issue.
- SPEC Appendix A describes the catalogue as holding only
  deterministic-tier rules, which is stale (34 of 40 entries are
  inference-based). Not fixed here; worth its own issue.

## Not resolved by this change

No other open issue, on either tracker, is closed by this commit.
