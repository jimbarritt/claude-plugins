# software-english-lint

Enforces [Software English](https://github.com/jimbarritt/software-english)
deterministic-tier rules via a Claude Code Stop hook.

## What it checks

- Closed vocabulary ([`data/operations.tsv`](data/operations.tsv), [`structure.tsv`](data/structure.tsv), [`qualities.tsv`](data/qualities.tsv),
  [`connectives.tsv`](data/connectives.tsv))
- Banned-word substitutions ([`data/banned.tsv`](data/banned.tsv))
- Sentence length
- Continuous and perfect tense used for system behaviour
- A fixed anthropomorphism word list
- A fixed abstract-location word list (e.g. "sits", "lives" standing in
  for "is"/"belongs to" when the subject is abstract)

These are Software English's deterministic-tier rules — checkable by lookup or pattern
alone. Software English's inference-based-tier rules (commentary, hedging, unlisted
anthropomorphism paraphrases) need model judgement and are not linted
here.

## How it runs

[`hooks/hooks.json`](hooks/hooks.json) registers [`hooks/stop-check.sh`](hooks/stop-check.sh) on Claude Code's `Stop`
event. The wrapper first runs [`scripts/fetch-software-english-data.sh`](scripts/fetch-software-english-data.sh),
then runs [`scripts/software_english_lint.py`](scripts/software_english_lint.py) `--diff --added-only` against
changed Markdown, and exits 2 (blocking the Stop event) on any violation, so
Claude must fix the file before the turn ends.

## Where the rule data comes from

[`software-english.json`](software-english.json) pins a tag of the
[`software-english`](https://github.com/jimbarritt/software-english) spec
repo. [`scripts/fetch-software-english-data.sh`](scripts/fetch-software-english-data.sh)
downloads that tag's `vocabulary/*.tsv` and `rules/core-rules.toml` into
[`data/`](data/) the first time it runs, and writes a marker file recording
the tag it fetched. Every later run compares the marker against the pin and
does no network work when they match — the fetch happens once per tag, not
once per Stop event.

[`data/`](data/) is gitignored. It holds a local cache, not a vendored copy in
this repository's own history. Bump the tag in `software-english.json` to
pick up a newer spec version; the next run re-fetches.

If the fetch cannot reach GitHub and no cache exists yet, the hook prints a
warning and does not block the turn. If a cache from an earlier fetch already
exists, that cache is used even when a later fetch fails.

## Known limits (v0.1)

- Vocabulary is a seed set. A correct word not yet listed causes a
  `warning`-severity finding (non-blocking) — this is expected; Software English's
  vocabulary grows from corrections (see the parent spec's
  [`vocabulary/`](https://github.com/jimbarritt/software-english/tree/main/vocabulary)
  admission note). `vocabulary-membership` will move to `error` once the
  vocabulary is measured against a real corpus (SPEC §6.1).
- Lemmatisation is a crude suffix-strip, not a real lemmatiser. Some
  inflected forms of an approved word will not match yet.
- No auto-rewrite mechanism exists yet. The Stop hook blocks and reports
  violations; Claude edits the file itself in response, the same way the
  existing personal `STE: checked` convention already works today. A
  true unattended auto-rewrite (with the fact-preservation check specified
  in the parent spec §9) is not yet built.
- The [`data/`](data/) directory is a local cache, fetched from the tag
  pinned in [`software-english.json`](software-english.json) — see "Where the
  rule data comes from" above. No versioning scheme beyond a plain tag
  exists yet; `software-english` is pre-1.0.
- Sentence splitting runs per Markdown line, not per paragraph, so a
  sentence hard-wrapped across two lines is undercounted for length.
- Checks Markdown only. Does not check commit messages, code comments, or
  live chat replies directly, though a Stop hook does fire after every
  chat turn, so a future version could extend the check to the
  transcript itself.

### Fixed after initial review

- The technical-name (now "literal token") exclusion previously matched
  almost nothing — a bug in its end-of-string check meant it always fired.
  It now correctly skips acronyms, `snake_case`/dotted/path tokens,
  `camelCase`, version numbers, and mid-sentence capitalised words.
- `--added-only` previously had no effect — the whole file was linted
  regardless of the flag. It now parses `git diff --unified=0` hunks and
  checks only the changed line ranges.
- The perfect-tense check previously had no historical-fact exception and
  ran at blocking severity. It is now inference-based-tier, advisory-only.
- A blockquote line (`>`) is now exempt — it holds quoted material, not
  the document's own prose.
- Added a gated `abstract-location` check for verbs like "sits"/"lives"
  standing in for "is"/"belongs to" on an abstract subject — the same
  fault category as "reach"/"carry" in [`banned.tsv`](data/banned.tsv), but not addable to a
  flat banned list because these verbs are correct English for a physical
  or human subject. Excludes `user` from the subject gate, since it names
  a human referent despite living in [`structure.tsv`](data/structure.tsv).
- Tier terminology renamed throughout: "Core" → "Deterministic",
  "Extended" → "Inference-based" — clearer names for what each tier
  actually means.
- Rules used to be hardcoded in this script, duplicating
  `rules/core-rules.toml` (then `core-rules.yaml`) by hand. The script
  now parses the catalogue directly via Python's stdlib `tomllib`
  (severities, word lists, tense-pattern regexes, stoplists, sentence
  length, and lookback windows all come from the TOML file) — the
  catalogue was converted from YAML to TOML specifically so this could
  happen without a third-party dependency (`tomllib` is stdlib since
  Python 3.11; YAML has no stdlib parser). See the
  [colophon](https://github.com/jimbarritt/software-english/blob/main/COLOPHON.md)
  for the reasoning.
- The continuous/perfect tense regexes previously false-matched non-verb
  "-ing"/"-en" words ("during", "nothing", "has ten"). Both now use a
  stoplist.
- The anthropomorphism check previously fired on any subject, including a
  human one ("the reviewer expects..."). It now requires a structure noun
  or system-referring pronoun within four words before the match.
- A banned-word match and an anthropomorphism match on the same phrase
  previously double-reported. The anthropomorphism check now skips a span
  already matched as a banned word.

## Manual use

Run `scripts/fetch-software-english-data.sh` once first, if `data/` is empty
or missing — the Stop hook does this automatically, but a manual run does
not.

```bash
python3 scripts/software_english_lint.py FILE.md            # check named files
python3 scripts/software_english_lint.py --diff --added-only  # check changed lines only
python3 scripts/software_english_lint.py FILE.md --count      # totals only
```

Exemption markers, on any line or file:

```text
<!-- swe: skip-file -->
<!-- swe: ignore -->
```

A Markdown blockquote line (starts with `>`) is also exempt — it holds
quoted material, not this document's own prose.
