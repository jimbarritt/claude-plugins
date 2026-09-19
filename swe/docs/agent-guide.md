# Agent guide: swe

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
it. Run `/swe:feedback <false-positive|false-negative|wrong-fix> [note]`
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

The four non-`Stop` hooks (`file`, `bash`, `artifact`, `mcp-send`) never
run a model call themselves. Each calls the linter with
`--advise-inference` instead of running inference in-process — this
avoids a hook process ever stalling on `claude -p`, the failure mode
that motivated this design. `--advise-inference` only decides whether a
fresh pass is worth dispatching, and prints a single `INFERENCE_ADVISED`
marker line when it is. The hook script (`strip_advise_marker()` and
`advise_inference()` in [`../hooks/_lib.sh`](../hooks/_lib.sh)) reads
that marker, strips it out of the deterministic-tier report, and — only
when the deterministic tier itself found nothing to block — returns a
non-blocking advisory hook response: the tool call proceeds (or, for
`PostToolUse`, already had), and Claude is told to dispatch a subagent
to run the actual check.

A pass is worth dispatching when:

1. The deterministic tier found no violation in this same invocation.
2. `stop_hook_active` is false (`Stop` only; the other hooks have no
   equivalent flag, and never call `--advise-inference` in the first
   place — see below).
3. The prose, after code and quote stripping, is eligible per
   `inference_eligible()` in
   [`../scripts/software_english_lint.py`](../scripts/software_english_lint.py):
   - **A single named file** (the only source with a stable identity
     across repeated edits): eligible once its word or sentence count
     has grown by another
     [`../config.json`](../config.json) `threshold_words` (60) /
     `threshold_sentences` (4) since the file's last recorded
     `--force-inference` pass — recorded in
     `~/.claude/swe/inference-state.json`, keyed by the file's resolved
     path. A file with no recorded pass yet uses the same numbers as a
     plain absolute threshold (its first pass). This is what throttles a
     file already carrying, say, 20 known inference findings: most
     follow-up edits are fixes to those, not new prose, so they do not
     re-cross the threshold and do not get advised again until the file
     has genuinely grown.
   - **Any other source** (piped text, an HTML file): no stable identity
     across calls, so it always uses the plain absolute threshold,
     exactly as before.

The advisory message the hook builds names the exact command to run: for
a file, `--force-inference` directly against its path; for a text
source (a commit/PR message, an outbound MCP message), the hook first
writes the text to a scratch file under `~/.claude/swe/pending-inference/`
and points the command at it with `--force-inference --text
--source-label ... < <scratch-file>`, since the tool call that produced
the text has already run by the time the subagent checks it (`bash-check.sh`
and `mcp-send-check.sh` allow the underlying `Bash`/MCP-send tool call
through unblocked, same as the hook doing nothing at all). The dispatched
subagent's job is to check and report only — same as `/swe:lint-file` —
not to fix anything; Claude reads its findings and fixes the source
itself, same as before.

`--force-inference` (used by `/swe:lint-file`, and by the subagent an
advisory dispatches) is what actually runs inference: it shells out to
`claude -p --safe-mode --model <config.json's fast_model>` with the
prose and a prompt built from the inference-based rules, and folds the
result into the same report. `--safe-mode` disables CLAUDE.md, hooks,
skills, and plugins for that one call — required, since without it the
subprocess loads the calling project's own CLAUDE.md and any mandatory
session-start skill, which competes with the linting prompt. It bypasses
conditions 1 and 3 above entirely — it runs regardless of deterministic
errors already found, and regardless of the prose threshold or growth
throttle — but still skips on empty prose, and still records the pass
(word/sentence count, for the throttle above) once it runs. Condition 2
(`stop_hook_active`) does not apply outside the `Stop` hook, so it is
moot here.

If `claude` is not on `PATH`, or the call fails or times out, the
inference tier is skipped. The deterministic tier's result stands
either way.

## Where the rule data comes from

[`../software-english.json`](../software-english.json) pins a tag of
the [`software-english`](https://github.com/jimbarritt/software-english)
spec repository.
[`../scripts/fetch-software-english-data.sh`](../scripts/fetch-software-english-data.sh)
clones that tag with `git clone --depth 1 --branch <tag>` and copies
`vocabulary/*.tsv` and `rules/core-rules.toml` into [`../data/`](../data/)
on first run, then writes a marker file recording the fetched tag. A
later run compares the marker against the pin, and fetches again only
when they differ.

The fetch goes through `git clone`, not a raw HTTPS tarball download: a
cloud session's egress policy can deny a generic HTTPS download while
still serving git's own smart-HTTP protocol for a public repo clone,
through a separate, git-specific proxy lane. See claude-plugins#3.

[`../data/`](../data/) is gitignored — a local cache, not a vendored
copy in this repository.

If the fetch cannot connect to GitHub and no cache exists, the hook
prints a warning and does not block the turn. An existing cache from an
earlier fetch is used when a later fetch fails. This holds even if a
hook calls the linter without checking the fetch script's own exit code:
`load_rule_catalogue()` returns `(None, None)` when
`data/core-rules.toml` is still missing, and `main()` prints a skip
message and returns 0 rather than crash with an uncaught
`FileNotFoundError` (claude-plugins#3's second bug — the crash's
traceback, not a real finding, used to reach `report_and_maybe_block` as
a misleading "0 errors, 0 warnings" block).

## Run the linter directly

```bash
python3 scripts/software_english_lint.py FILE.md
python3 scripts/software_english_lint.py --diff --added-only
python3 scripts/software_english_lint.py FILE.md --count
echo "some prose" | python3 scripts/software_english_lint.py --text --source-label reply
python3 scripts/software_english_lint.py --transcript /path/to/transcript.jsonl
python3 scripts/software_english_lint.py --html-file page.html
```

Add `--advise-inference` to print `INFERENCE_ADVISED` when a fresh pass
would be worth dispatching, gated as above, without running it. Add
`--force-inference` to run the inference tier directly instead — this
is what `/swe:lint-file` does. Add `--quiet-vocab` to omit
`vocabulary-membership` lines; every hook does this by default.

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
  call, when it runs — moved out of the hook process by the subagent
  dispatch above, but the subagent (and so Claude) still waits on it.
  The inference-tier prompt receives prose with inline code, links, and
  URLs blanked out by character count (not removed) — this can read as
  missing content to the model and produce a spurious
  `no-unanchored-reference` finding pointing at a blanked span. Not yet
  fixed; logged as feedback when found.
- `bash-check.sh` and `mcp-send-check.sh` advise inference only after
  already letting the underlying tool call proceed unblocked: a commit
  can be amended once a finding comes back, but a sent message cannot
  be un-sent. This is the accepted cost of moving these two hooks off a
  blocking in-process model call.
- The growth-since-last-pass throttle (`inference_eligible()`) only
  applies to a single named file. A commit/PR message or an outbound
  MCP message has no identity across separate tool calls, so each one
  is still judged solely against the plain absolute threshold, same as
  before this rework.
- `~/.claude/swe/inference-state.json` and
  `~/.claude/swe/pending-inference/` are never pruned. Both hold small
  text; neither is cleaned up automatically yet.
