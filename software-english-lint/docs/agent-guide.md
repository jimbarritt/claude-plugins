# Agent guide: software-english-lint

This file is for an agent (a Claude Code session) running inside a
project with this plugin installed. It is not for a human — see
[`../README.md`](../README.md) for that. This file is exempt from
Software English's own enforcement, listed in
[`../../.swe-ignore`](../../.swe-ignore): it is technical reference for
an LLM reader, not the human-facing prose the spec governs.

## What to do when a hook blocks you

A `Stop` or blocking `PreToolUse` hook prints a report and exits 2. Read
it: a rule name, the flagged text, and a suggested fix, one line per
finding. Fix the flagged text as described, then finish the turn (or
retry the tool call) again.

If you believe a finding is wrong — a false positive, a false negative,
or a correct finding with a bad suggested fix — do not just work around
it. Run `/swe-feedback <false-positive|false-negative|wrong-fix> [note]`
so the pattern gets tracked, then proceed with your own best correction.

`stop_hook_active: true` on the hook's input means this turn already
re-ran once this way. The hook still prints its report but exits 0, so
you will not be blocked a second time for the same turn. Claude Code
also caps a `Stop` hook at 8 consecutive blocks regardless, overridable
with `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`.

`PostToolUse` cannot block: the write already happened before
`file-check.sh` runs. It exits 2 anyway when it finds an error-severity
violation, since Claude Code still shows you the stderr as a system
message on exit 2 for this event, even though the write cannot be
undone. Fix the file when you see this report. `PostToolUse` exiting 0
does not reach you at all; only exit 2 does.

## Hooks

| Hook | Event | Covers | Config key |
|---|---|---|---|
| [`../hooks/stop-check.sh`](../hooks/stop-check.sh) | `Stop` | The chat reply and the transcript since the last user message (Copilot CLI only — see below); changed tracked markdown | `hooks.stop.reply` (reply, transcript; Copilot CLI only); `hooks.stop.docs` (tracked markdown) |
| [`../hooks/file-check.sh`](../hooks/file-check.sh) | `PostToolUse` on `Write`\|`Edit` | A markdown file the Stop hook's git diff cannot see: outside the working tree, or untracked. Also tracked markdown, when `hooks.stop.docs` is off | `hooks.file` |
| [`../hooks/bash-check.sh`](../hooks/bash-check.sh) | `PreToolUse` on `Bash` | A `git commit` message or a `gh pr`/`gh issue` title or body | `hooks.bash` |
| [`../hooks/artifact-check.sh`](../hooks/artifact-check.sh) | `PreToolUse` on `Artifact` | A file about to publish: markdown directly, HTML via text-node extraction | `hooks.artifact` |
| [`../hooks/mcp-send-check.sh`](../hooks/mcp-send-check.sh) | `PreToolUse` on the `Slack`/`Gmail`/`Drive` send tools | An outbound message body | `hooks["mcp-send"]` (hyphenated key, so a jq path needs bracket syntax) |

Each config key resolves via `hook_enabled()` in
[`../hooks/_lib.sh`](../hooks/_lib.sh): the project's own
`.claude/swe-lint.json`, if it sets that key, else the plugin's own
[`../config.json`](../config.json), else `true` (fail open). See the
[README](../README.md#turn-off-a-check-for-one-project) for the
project-level file's format.

All five call
[`../scripts/software_english_lint.py`](../scripts/software_english_lint.py)
after
[`../scripts/fetch-software-english-data.sh`](../scripts/fetch-software-english-data.sh).

## Output style

[`../output-styles/software-english.md`](../output-styles/software-english.md)
carries `force-for-plugin: true` and `keep-coding-instructions: true`.
Claude Code applies it automatically whenever this plugin is enabled,
overriding the session's own `outputStyle` setting, and sends its
instructions with every request for the session, the same way it sends
the system prompt.

This is why `stop-check.sh`'s reply/transcript check always skips under
Claude Code: the condensed rules in the output style shape the reply
before it is written, instead of catching a violation after the fact.
`hooks.stop.reply` still exists for Copilot CLI, which has no
output-style mechanism and so keeps the reactive check.

The output style is exempt from this plugin's own checks, listed in
[`../../.swe-ignore`](../../.swe-ignore), for the same reason as this
file: it cites banned words and patterns as examples, which the linter
cannot tell apart from a live violation.

Two gaps this does not close:

- A subagent (the `Agent` tool) runs its own system prompt and does not
  inherit the parent conversation's output style. Its written output is
  covered by `file-check.sh`, `bash-check.sh`, `artifact-check.sh`, and
  `mcp-send-check.sh` when it writes a file, a commit, an artifact, or a
  message, same as before; nothing yet covers a subagent's own reply
  text.
- The output style is a system-prompt instruction, not a check. A rule
  the model still gets wrong ships in the reply unless another hook
  (`hooks.stop.docs`, `hooks.file`, and the rest) catches it downstream.

## Rule tiers

**Deterministic.** Checkable by lookup or pattern alone. Runs on every
source, every time:

- Closed vocabulary: [`../data/operations.tsv`](../data/operations.tsv), [`structure.tsv`](../data/structure.tsv), [`qualities.tsv`](../data/qualities.tsv), [`connectives.tsv`](../data/connectives.tsv)
- Banned-word substitutions: [`../data/banned.tsv`](../data/banned.tsv)
- No em dash
- Continuous tense used for system behaviour
- A fixed anthropomorphism word list
- A fixed abstract-location word list (`sits`, `lives`, and similar, standing in for `is`/`belongs to` when the subject is abstract)

**Inference-based.** Needs model judgement. Runs conditionally, per
"When the inference tier runs" below: every rule in
[`../data/core-rules.toml`](../data/core-rules.toml) with
`check = "model-judgement"`.

**Plugin-owned.** [`../rules/plugin-rules.toml`](../rules/plugin-rules.toml)
holds one rule, `one-point-at-a-time`: a reply with more than one point
needing a decision states the count, then gives only the first point.
This governs reply structure, not prose wording, so it stays out of the
Software English spec. It runs only on a conversational source (a chat
reply or a transcript), never on a file, a commit message, or an
artifact.

## When the inference tier runs

All three conditions must hold, checked in this order:

1. The deterministic tier found no violation in this same invocation.
2. `stop_hook_active` is false (`Stop` only; the other hooks have no
   equivalent flag).
3. The prose, after code and quote stripping, exceeds a size threshold:
   [`../config.json`](../config.json)'s `threshold_words` (60) or
   `threshold_sentences` (4), whichever comes first.

When all three hold, the linter runs
`claude -p --safe-mode --model <config.json's fast_model>` with the
prose and a prompt built from the inference-based rules, and folds the
result into the same report. `--safe-mode` disables CLAUDE.md, hooks,
skills, and plugins for that one call — required, since without it the
subprocess loads the calling project's own CLAUDE.md and any mandatory
session-start skill, which competes with the linting prompt.

If `claude` is not on `PATH`, or the call fails or times out, the
inference tier is skipped. The deterministic tier's result stands
either way.

## Where the rule data comes from

[`../software-english.json`](../software-english.json) pins a tag of
the [`software-english`](https://github.com/jimbarritt/software-english)
spec repository.
[`../scripts/fetch-software-english-data.sh`](../scripts/fetch-software-english-data.sh)
downloads that tag's `vocabulary/*.tsv` and `rules/core-rules.toml`
into [`../data/`](../data/) on first run, and writes a marker file
recording the fetched tag. A later run compares the marker against the
pin, and fetches again only when they differ.

[`../data/`](../data/) is gitignored — a local cache, not a vendored
copy in this repository.

If the fetch cannot connect to GitHub and no cache exists, the hook
prints a warning and does not block the turn. An existing cache from an
earlier fetch is used when a later fetch fails.

## Run the linter directly

```bash
python3 scripts/software_english_lint.py FILE.md
python3 scripts/software_english_lint.py --diff --added-only
python3 scripts/software_english_lint.py FILE.md --count
echo "some prose" | python3 scripts/software_english_lint.py --text --source-label reply
python3 scripts/software_english_lint.py --transcript /path/to/transcript.jsonl
python3 scripts/software_english_lint.py --html-file page.html
```

Add `--run-inference` to also run the inference tier. Add
`--quiet-vocab` to omit `vocabulary-membership` lines; every hook does
this by default.

Run `scripts/fetch-software-english-data.sh` once by hand first, if
`data/` is empty — the hooks do this automatically, a manual run does
not.

## Known limits

- Vocabulary is a seed set. An unlisted but correct word gets a
  `warning`-severity finding, not an `error`. `vocabulary-membership`
  moves to `error` once the vocabulary is measured against a real
  corpus (SPEC §6.1).
- Lemmatisation is a suffix-strip, not a real lemmatiser. Some
  inflected forms of an approved word do not match.
- No auto-rewrite mechanism exists. A blocking hook reports a
  violation; you edit the text yourself in response. The
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
- The inference tier's own model call adds real latency, seconds per
  call, when it runs. The inference-tier prompt receives prose with
  inline code, links, and URLs blanked out by character count (not
  removed) — this can read as missing content to the model and produce
  a spurious `no-unanchored-reference` finding pointing at a blanked
  span. Not yet fixed; logged as feedback when found.
