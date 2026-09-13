# software-english-lint

Enforces [Software English](https://github.com/jimbarritt/software-english)
on every kind of output a Claude Code session produces, via five hooks.
See [`docs/output-taxonomy.md`](docs/output-taxonomy.md) for the full
taxonomy of output kinds this covers.

## What it checks

Deterministic tier — checkable by lookup or pattern alone, runs on every
source, every time:

- Closed vocabulary ([`data/operations.tsv`](data/operations.tsv), [`structure.tsv`](data/structure.tsv), [`qualities.tsv`](data/qualities.tsv),
  [`connectives.tsv`](data/connectives.tsv))
- Banned-word substitutions ([`data/banned.tsv`](data/banned.tsv))
- Continuous tense used for system behaviour
- A fixed anthropomorphism word list
- A fixed abstract-location word list (e.g. "sits", "lives" standing in
  for "is"/"belongs to" when the subject is abstract)
- Sentence length and perfect-tense-for-behaviour are also computed here
  (both are deterministically countable), but stay advisory-only —
  their tier assignment is inference-based, per the catalogue.

Inference-based tier — needs model judgement, runs conditionally (see
"When the inference tier runs" below): every rule in `core-rules.toml`
with `check = "model-judgement"`. The catalogue is read generically, so a
new inference-based rule (for example `no-unanchored-reference`,
`no-planning-content-in-reference`) is picked up automatically once its
tag is fetched — nothing here names a rule by hand.

Plugin-owned tier — [`rules/plugin-rules.toml`](rules/plugin-rules.toml)
holds one rule, `one-point-at-a-time`: a reply with more than one point
needing a decision states the count, then gives only the first point and
stops, rather than listing every point at once. This governs reply
structure, not prose wording, so it stays out of the Software English
spec. It runs only on a conversational source (a chat reply or a
transcript) — never on a file, a commit message, or an artifact, since a
document can legitimately list many points at once.

## How it runs

Five hooks in [`hooks/hooks.json`](hooks/hooks.json), all calling
[`scripts/software_english_lint.py`](scripts/software_english_lint.py)
after [`scripts/fetch-software-english-data.sh`](scripts/fetch-software-english-data.sh):

| Hook | Event | Covers |
|---|---|---|
| [`stop-check.sh`](hooks/stop-check.sh) | `Stop` | The chat reply, the transcript since the last user message, and changed markdown (tracked and untracked) |
| [`file-check.sh`](hooks/file-check.sh) | `PostToolUse` on `Write`\|`Edit` | A markdown file the Stop hook's git diff cannot see — outside the working tree, or untracked |
| [`bash-check.sh`](hooks/bash-check.sh) | `PreToolUse` on `Bash` | A `git commit` message or a `gh pr`/`gh issue` title or body |
| [`artifact-check.sh`](hooks/artifact-check.sh) | `PreToolUse` on `Artifact` | A file about to publish — markdown directly, HTML via text-node extraction |
| [`mcp-send-check.sh`](hooks/mcp-send-check.sh) | `PreToolUse` on the `Slack`/`Gmail`/`Drive` send tools | An outbound message body before it reaches another person |

A `Stop` or blocking `PreToolUse` finding of severity `error` returns
exit 2, so Claude must fix the text before the action completes.
`PostToolUse` cannot block (the write already happened) — `file-check.sh`
only reports.

`stop-check.sh` reads `stop_hook_active` from its input and never blocks
twice in a row for the same turn: when that flag is true, it still
prints its report, but always exits 0.

### When the inference tier runs

Not on every event — only when all of these hold, checked in this order:

1. The deterministic tier found no violation in this same invocation.
2. `stop_hook_active` is false (Stop only; the other hooks have no
   equivalent flag and always allow the inference tier once condition 1
   and 3 hold).
3. The prose, after code/quote stripping, exceeds a size threshold
   (`config.json`: 60 words or 4 sentences, whichever comes first).

When all three hold, the same script process shells out to
`claude -p --model <config.json's fast_model>` with the prose and a
prompt built from the inference-based rules read out of `core-rules.toml`,
and folds the result into the same report. If `claude` is not on `PATH`,
or the call fails or times out, the inference tier is skipped — the
deterministic tier's result still stands.

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
- No auto-rewrite mechanism exists yet. A blocking hook reports
  violations; Claude edits the text itself in response. A true
  unattended auto-rewrite (with the fact-preservation check specified in
  the parent spec §9) is not yet built.
- The [`data/`](data/) directory is a local cache, fetched from the tag
  pinned in [`software-english.json`](software-english.json) — see "Where the
  rule data comes from" above. No versioning scheme beyond a plain tag
  exists yet; `software-english` is pre-1.0.
- Sentence splitting runs per Markdown line, not per paragraph, so a
  sentence hard-wrapped across two lines is undercounted for length.
- Code-comment extraction covers only Python (`#`) and Bash (`#`) — the
  two languages present in these two repos today. No block-comment
  extraction yet.
- A commit or PR title/body message passed as a single-quoted argument
  is matched (see "Fixed after initial review"), but `bash-check.sh`'s
  quote-parsing is still regex-based, not a real shell parser — an
  unusual quoting or escaping style could still defeat it. A heredoc
  case (below) is the known instance of this.
- HTML text-node extraction treats every node at or above the character
  threshold as prose, including a long button label; it does not
  distinguish UI copy from body prose.
- A commit or PR text embedded in a heredoc (`git commit -F -
  <<'EOF' ... EOF`) is not parsed by `bash-check.sh` — its regex-based
  extraction only handles a quoted `-m`/`--body`/`--title` argument or a
  `-F`/`--body-file` path. A heredoc case passes through unchecked rather
  than risk a false block from a misparse.
- The Slack matcher in `hooks.json` and the tool-name case in
  `mcp-send-check.sh` are unverified — no Slack send tool exists in this
  installation's tool registry to test against (only `authenticate` and
  `complete_authentication` are present). The pattern follows this
  integration's own naming convention and should start working once a
  matching tool is added, but this has not been confirmed against a real
  Slack send.
- The inference tier's model call adds real latency (seconds, not
  instant) whenever it runs. It is gated to reduce how often that
  happens, not eliminated.

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
- Code-comment checking (taxonomy row 5) had the extraction logic but no
  hook ever called it — `file-check.sh` filtered to `*.md` only. It now
  also checks `.py`/`.sh`/`.bash` files, unconditionally (nothing else
  covers code comments, tracked or not).
- `extract_comments` previously matched only a comment that was an entire
  line. A trailing comment after real code (`x = 1  # like this`) was
  missed. It now finds the comment marker outside any quoted string on
  the line, wherever it falls.
- `bash-check.sh` previously matched only a double-quoted `-m "..."`
  argument; a single-quoted `-m '...'` passed through unchecked. It now
  matches both. It also matched only `gh pr create`/`gh pr comment`, not
  `gh pr edit` or `gh pr review` — both can carry a body. It now matches
  any `gh pr` subcommand.

## Manual use

Run `scripts/fetch-software-english-data.sh` once first, if `data/` is empty
or missing — the Stop hook does this automatically, but a manual run does
not.

```bash
python3 scripts/software_english_lint.py FILE.md              # check named files
python3 scripts/software_english_lint.py --diff --added-only  # changed lines, tracked and untracked
python3 scripts/software_english_lint.py FILE.md --count      # totals only
echo "some prose" | python3 scripts/software_english_lint.py --text --source-label reply
python3 scripts/software_english_lint.py --transcript /path/to/transcript.jsonl
python3 scripts/software_english_lint.py --html-file page.html
```

Add `--run-inference` to any of the above to also run the inference tier
when the deterministic tier is clean and the prose passes the size
threshold. Add `--quiet-vocab` to omit `vocabulary-membership` lines from
the printed report (they never block; this only reduces noise — the hooks
all use this by default).

Exemption markers, on any line or file:

```text
<!-- swe: skip-file -->
<!-- swe: ignore -->
```

A Markdown blockquote line (starts with `>`) is also exempt — it holds
quoted material, not this document's own prose.
