# Report: software-english#25 — navigational meta-remark false negative

## Outcome

Fixed and released.

- **Commit:** [3774593](https://github.com/jimbarritt/software-english/commit/3774593b693232ab5d6bea99e1172cd34095f838)
  on `software-english` `main`, closes
  [software-english#25](https://github.com/jimbarritt/software-english/issues/25).
- **Release tags:** `software-english` [v0.0.31](https://github.com/jimbarritt/software-english/releases/tag/v0.0.31);
  `swe` (claude-plugins) 0.24.8, via
  [release-plugin.yml run 40829073484](https://github.com/jimbarritt/claude-plugins/actions/runs/40829073484),
  commit [f8c66fe](https://github.com/jimbarritt/claude-plugins/commit/f8c66fec253d5ac7be5164c1068c6ed1c7fb20e6)
  on `claude-plugins` `main`.

## What changed

- `spec/SPEC.md` §5.3: replaced the closing "no catalogue entry"
  paragraph with full coverage of the navigational-announcement form
  of "a remark about the writing" — examples, fix, delete-and-check
  test, "not this fault" list, the fixed-list/inference-tier split,
  and a "nearby claim" cross-reference list (§5.10, §7.17, §7.1, §7.6,
  §8.3).
- `spec/SPEC.md` §5.10: one new cross-reference bullet, so a cleft
  whose plain clause still states no fact routes to §5.3's new rule
  instead of §5.10.
- `rules/core-rules.toml`: new `[[rules]]` block,
  `no-remark-about-the-writing` (inference-based, warning), plus
  "Distinct from no-remark-about-the-writing" sentences added to
  `no-framing-device` and `no-reader-reaction-prediction`, and a note
  on `anthropomorphism-fixed-list` that `comes in`/`come in` are now
  banned-word entries claimed ahead of it.
- `vocabulary/banned.tsv`: added `comes in` and `come in` under
  "Meta-commentary on the writing".
- `COLOPHON.md`: new section explaining the fault, why it is a §5.3
  catalogue entry and not a fourth §5.10 shape, and the banned.tsv
  addition — mirrors the existing `M-SWE-READER-REACTION-RULE`
  (software-english#24) section's style.
- Intro deck (`docs/public/presentations/intro/intro-to-software-english.md`
  and its built `html`/`pdf`): rule counts bumped to 41 total, 35
  inference-based. The PDF was rebuilt with `./build.sh` (node/npx and
  the session's pre-installed Playwright Chromium were both
  available — no stale-PDF caveat needed).
- `claude-plugins`/`swe`: `software-english.json` tag moved to
  v0.0.31, `plugin.json` version bumped 0.24.7 → 0.24.8. No linter
  code change — `software_english_lint.py` reads
  `rules/core-rules.toml` and `vocabulary/*.tsv` directly, so a new
  rule or fixed phrase needs no duplicate catalogue entry in
  claude-plugins.

## Design decision (recorded as `tsk decision`)

The issue proposed two possible homes: extend `no-framing-device`
(§5.10) with a fourth shape, or use "the SPEC's meta-remark guidance"
(§5.3) if that is a better home. Chose §5.3, as a new rule id rather
than a reuse of an existing one, because:

- `no-framing-device`'s fault is "a frame that wraps a fact", and its
  fix is always the plain clause. A navigational announcement wraps no
  fact: rewriting `that is what the next section is for` to its plain
  clause (`the next section is for that`) still states nothing about
  the system. Putting this fault under §5.10 would give that rule a
  fix that does not fit its own definition.
- §5.3 already names this fault ("a remark about the writing itself")
  but had no catalogue entry for it (no inference-tier rule id) before
  this change — only fixed phrases in `banned.tsv`. The precedent for
  closing exactly this kind of gap is `M-SWE-READER-REACTION-RULE`
  (software-english#24), which catalogued §5.3's *second* fault
  (reader-reaction prediction) the same way. This change mirrors that:
  one new rule id covers the whole third fault (remark about the
  writing), with the navigational announcement as one named form, not
  a narrower id that would leave a paraphrase like "to put it briefly"
  uncovered.

## What was found along the way

Two of the issue's three example sentences already fired today, with
the *wrong* fix, before this change:

- `"This is where the signing certificate comes in."` — `comes` matched
  the anthropomorphism fixed word list, with a fix of "name the
  mechanism", not "delete the sentence / state the next part's fact".
- `"Here is where the retry limit matters."` — `matters` matched an
  existing `banned.tsv` entry with fix "state the consequence", again
  the wrong correction for a navigational remark.
- `"That is what the next section is for."` — nothing fired on either
  tier before this change; it matches the §5.10 cleft signature, but
  §5.10's own fix (drop the copula: "the next section is for that")
  still states no fact, so even a correct §5.10 match would have given
  a wrong fix.

Adding `comes in`/`come in` to `banned.tsv` corrects the first case
directly, since `check_line` lets a banned-word match claim a span
ahead of the anthropomorphism fixed list. No existing use of either
phrase, or of `this is where`/`here is where` (left out of `banned.tsv`
since each has a correct literal use, e.g. naming a real location), was
found in either repository's prose.

## Verification performed

- `python3 -c "import tomllib; tomllib.load(...)"` on the edited
  `rules/core-rules.toml`: parses, 41 `[[rules]]` entries, 6
  deterministic / 35 inference-based.
- Ran `software_english_lint.py --text` on the issue's three example
  sentences against the edited data: banned-word now reports `comes
  in` and `matters` (not the old anthropomorphism/consequence fixes),
  and `--force-inference` on the third sentence lists
  `no-remark-about-the-writing` in the inference-pending block.
- Lint of the diff region in `spec/SPEC.md`: no new deterministic
  findings in the added text (all existing findings in the file are
  pre-existing, outside the changed line ranges).
- Full `claude-plugins/swe` test suite (`tests/*.sh`, 16 scripts): all
  pass, both before and after the `swe` version bump, against data
  re-fetched at the new v0.0.31 tag.
- `scripts/check-unshipped.sh` on `claude-plugins`: correctly flagged
  the pending `swe` version bump before release, and the release
  workflow (`release-plugin.yml`) completed successfully afterward.
