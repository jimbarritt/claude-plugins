# software-english-lint reference

The hooks, the rule tiers, the inference tier's conditions, the rule
data source, and known limits. See [`../README.md`](../README.md) for
install and day-to-day usage.

## Hooks

| Hook | Event | Covers |
|---|---|---|
| [`stop-check.sh`](../hooks/stop-check.sh) | `Stop` | The chat reply, the transcript since the last user message, and changed markdown (tracked and untracked) |
| [`file-check.sh`](../hooks/file-check.sh) | `PostToolUse` on `Write`\|`Edit` | A markdown file the Stop hook's git diff cannot see: outside the working tree, or untracked |
| [`bash-check.sh`](../hooks/bash-check.sh) | `PreToolUse` on `Bash` | A `git commit` message or a `gh pr`/`gh issue` title or body |
| [`artifact-check.sh`](../hooks/artifact-check.sh) | `PreToolUse` on `Artifact` | A file about to publish: markdown directly, HTML via text-node extraction |
| [`mcp-send-check.sh`](../hooks/mcp-send-check.sh) | `PreToolUse` on the `Slack`/`Gmail`/`Drive` send tools | An outbound message body |

All five call
[`../scripts/software_english_lint.py`](../scripts/software_english_lint.py)
after
[`../scripts/fetch-software-english-data.sh`](../scripts/fetch-software-english-data.sh).

A `Stop` or blocking `PreToolUse` finding of severity `error` returns
exit 2. `PostToolUse` cannot block; `file-check.sh` only reports.

`stop-check.sh` reads `stop_hook_active` from its input. When that flag
is true, it prints its report but exits 0.

## Rule tiers

**Deterministic tier.** Checkable by lookup or pattern alone. Runs on
every source, every time:

- Closed vocabulary: [`../data/operations.tsv`](../data/operations.tsv), [`structure.tsv`](../data/structure.tsv), [`qualities.tsv`](../data/qualities.tsv), [`connectives.tsv`](../data/connectives.tsv)
- Banned-word substitutions: [`../data/banned.tsv`](../data/banned.tsv)
- No em dash
- Continuous tense used for system behaviour
- A fixed anthropomorphism word list
- A fixed abstract-location word list (`sits`, `lives`, and similar, standing in for `is`/`belongs to` when the subject is abstract)

**Inference-based tier.** Needs model judgement. Runs conditionally,
per ["When the inference tier runs"](#when-the-inference-tier-runs):
every rule in
[`../data/core-rules.toml`](../data/core-rules.toml) with
`check = "model-judgement"`. New inference-based rules are read
generically, so a new one is picked up automatically once its tag is
fetched.

**Plugin-owned tier.**
[`../rules/plugin-rules.toml`](../rules/plugin-rules.toml) holds one
rule, `one-point-at-a-time`. It governs reply structure, not prose
wording, so it stays out of the Software English spec: a reply with
more than one point needing a decision states the count, then gives
only the first point. It runs only on a conversational source (a chat
reply or a transcript), never on a file, a commit message, or an
artifact.

## When the inference tier runs

All three conditions must hold, checked in this order:

1. The deterministic tier found no violation in this same invocation.
2. `stop_hook_active` is false. (`Stop` only; the other hooks have no
   equivalent flag.)
3. The prose, after code and quote stripping, exceeds a size threshold:
   [`../config.json`](../config.json)'s `threshold_words` (60) or
   `threshold_sentences` (4), whichever comes first.

When all three hold, the linter runs
`claude -p --safe-mode --model <config.json's fast_model>` with the
prose and a prompt built from the inference-based rules, and folds the
result into the same report. `--safe-mode` disables CLAUDE.md, hooks,
skills, and plugins for that one call.

If `claude` is not on `PATH`, or the call fails or times out, the
inference tier is skipped. The deterministic tier's result is
unchanged either way.

## Where the rule data comes from

[`../software-english.json`](../software-english.json) pins a tag of
the [`software-english`](https://github.com/jimbarritt/software-english)
spec repository.
[`../scripts/fetch-software-english-data.sh`](../scripts/fetch-software-english-data.sh)
downloads that tag's `vocabulary/*.tsv` and `rules/core-rules.toml`
into [`../data/`](../data/) on first run, and writes a marker file
recording the fetched tag. A later run compares the marker against the
pin, and fetches again only when they differ.

[`../data/`](../data/) is gitignored: a local cache, not a vendored
copy in this repository. The tag in
[`../software-english.json`](../software-english.json) sets the spec
version this cache reflects.

If the fetch cannot connect to GitHub and no cache exists, the hook
prints a warning and does not block the turn. An existing cache from an
earlier fetch is used when a later fetch fails.

## Known limits

- Vocabulary is a seed set. An unlisted but correct word gets a
  `warning`-severity finding, not an `error`. `vocabulary-membership`
  moves to `error` once the vocabulary is measured against a real
  corpus (SPEC §6.1).
- Lemmatisation is a suffix-strip, not a real lemmatiser. Some
  inflected forms of an approved word do not match.
- No auto-rewrite mechanism exists. A blocking hook reports a
  violation; the model edits the text itself in response. The
  fact-preservation check the specification names in its §9 is not yet
  built.
- No versioning scheme exists beyond a plain tag; `software-english` is
  pre-1.0.
- Sentence splitting runs per Markdown line, not per paragraph. A
  sentence hard-wrapped across two lines is undercounted for length.
- Code-comment extraction covers only Python (`#`) and Bash (`#`).
- `bash-check.sh`'s quote-parsing is regex-based, not a real shell
  parser. A commit or PR body passed through a heredoc
  (`git commit -F - <<'EOF' ... EOF`) passes through unchecked.
- HTML text-node extraction treats every node at or above the
  character threshold as prose, including a button label.
- The Slack matcher in `hooks.json` is unverified: no Slack send tool
  exists in this installation's tool registry to test against.
- The inference tier's model call adds real latency, seconds per call,
  when it runs.
