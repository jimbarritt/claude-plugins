# Agent guide: swe

This file is for an agent (a Claude Code session) running inside a
project with this plugin installed. It is not for a human — see
[`../README.md`](../README.md) for that. This file is exempt from
Software English's own enforcement, listed in
[`../../.swe-ignore`](../../.swe-ignore): it is technical reference for
an LLM reader, not the human-facing prose the spec governs.

## What to do when a hook blocks you

A blocking `PreToolUse` hook (`bash-check.sh`, `artifact-check.sh`,
`mcp-send-check.sh`) denies the tool call and returns a reason: a rule
name, the flagged text, and a suggested fix, one line per finding, plus
the path to the full report under `~/.claude/swe/reports/`. Read it,
fix the flagged text as described, then retry the tool call.

If you believe a finding is wrong — a false positive, a false negative,
or a correct finding with a bad suggested fix — do not just work around
it. Run
`/swe:feedback <false-positive|false-negative|wrong-fix|feature-request> [note]`
so the pattern gets tracked, then proceed with your own best correction.
The fourth verdict, `feature-request`, is for feedback about the
tooling itself (a skill, a hook, the feedback loop), not tied to one
specific finding — see
[`../skills/feedback/SKILL.md`](../skills/feedback/SKILL.md).

No hook checks a file write or a chat reply automatically. Run
`/swe:lint-file <file-path>` yourself when you want a file checked; see
"When the inference tier runs" below for how that command works.

## Hooks

| Hook | Event | Covers | Config key |
|---|---|---|---|
| [`../hooks/bash-check.sh`](../hooks/bash-check.sh) | `PreToolUse` on `Bash` | A `git commit` message or a `gh pr`/`gh issue` title or body | `hooks.bash` |
| [`../hooks/artifact-check.sh`](../hooks/artifact-check.sh) | `PreToolUse` on `Artifact` | A file about to publish: markdown directly, HTML via text-node extraction | `hooks.artifact` |
| [`../hooks/mcp-send-check.sh`](../hooks/mcp-send-check.sh) | `PreToolUse` on the `Slack`/`Gmail`/`Drive` send tools | An outbound message body | `hooks["mcp-send"]` (hyphenated key, so a jq path needs bracket syntax) |

A `Stop` hook (checking the chat reply and changed tracked markdown)
and a `PostToolUse` hook on `Write`/`Edit` (checking a file as it was
written) both existed here previously and were removed: reviewed and
found to be doing very little once the output style existed to shape a
reply directly, at a fixed ~2-second cost on every single turn
regardless of whether anything needed checking (claude-plugins#6). See
`STATE.md` on the `planning` branch for the fuller record.

Each config key resolves via `hook_enabled()` in
[`../hooks/_lib.sh`](../hooks/_lib.sh): the project's own
`.claude/swe-lint.json`, if it sets that key, else the plugin's own
[`../config.json`](../config.json), else `true` (fail open). See the
[README](../README.md#turn-off-a-check-for-one-project) for the
project-level file's format.

All three call
[`../scripts/software_english_lint.py`](../scripts/software_english_lint.py)
after
[`../scripts/fetch-software-english-data.sh`](../scripts/fetch-software-english-data.sh).

## Output style

[`../output-styles/software-english.md`](../output-styles/software-english.md)
carries `keep-coding-instructions: true`. It is a normal installed
output style: a user selects it themselves (`/output-style`), the same
as any other. Nothing forces it on when the plugin is enabled;
`force-for-plugin: true` was removed once the `Stop` hook it justified
went too (see "Hooks" above). Once selected, Claude Code sends its
instructions with every request for the session, the same way it sends
the system prompt, whether the output being written is a chat reply or
a file.

The output style is exempt from this plugin's own checks, listed in
[`../../.swe-ignore`](../../.swe-ignore), for the same reason as this
file: it cites banned words and patterns as examples, which the linter
cannot tell apart from a live violation.

What this does not close, whether or not the style is selected:

- A subagent (the `Agent` tool) runs its own system prompt and does not
  inherit the parent conversation's output style. Its written output is
  covered by `bash-check.sh`, `artifact-check.sh`, and
  `mcp-send-check.sh` when it writes a commit, an artifact, or a
  message; nothing covers a subagent's own reply text or a file it
  writes.
- The output style is a system-prompt instruction, not a check, even
  when selected. A rule the model still gets wrong ships as written;
  nothing downstream catches it automatically for a reply or a file
  edit. `/swe:lint-file` is the deliberate, on-demand way to check a
  file, e.g. before a commit — nothing wires it up automatically.

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

This script has no model access of its own, and never spawns one. Every
invocation of it already runs inside a skill or a hook-dispatched
subagent, which already has a model attached; the script's only job for
the inference tier is to decide whether a fresh pass is worth doing,
and if so, hand over the applicable rules for the caller to judge the
prose against directly, as itself, with its own context. Nothing here
ever shells out to `claude -p` or any other subprocess for the judging
step.

`--advise-inference` (used by the three `PreToolUse` hooks: `bash`,
`artifact`, `mcp-send`) decides only:
gated by `inference_eligible()` below, plus the deterministic tier
being clean this same invocation, plus `stop_hook_active` being false
(`Stop` only; the other hooks have no equivalent flag). When eligible,
it prints a fenced block:

```
===INFERENCE_ADVISED===
- rule-id: description
- rule-id: description
===END_INFERENCE_ADVISED===
```

The hook script (`strip_advise_block()`/`extract_advise_rules()` and
`advise_inference()` in [`../hooks/_lib.sh`](../hooks/_lib.sh)) splits
that block out of the deterministic-tier report and, only when the
deterministic tier itself found nothing to block, returns a
non-blocking advisory hook response: the tool call proceeds, and Claude
is told to dispatch a subagent to read the source (a file path for
`artifact-check.sh`, or the text itself for `bash-check.sh`/
`mcp-send-check.sh`, inlined directly into the advisory message since
there is no file to read) and judge it against those rules, as part of
its own reasoning, then fix anything it finds. No step in that path
re-invokes this script.

A pass is worth advising when:

1. The deterministic tier found no violation in this same invocation.
2. `stop_hook_active` is false.
3. The prose, after code and quote stripping, is eligible per
   `inference_eligible()` in
   [`../scripts/software_english_lint.py`](../scripts/software_english_lint.py):
   - **A single named file** (the only source with a stable identity
     across repeated edits): eligible once its word or sentence count
     has grown by another
     [`../config.json`](../config.json) `threshold_words` (60) /
     `threshold_sentences` (4) since the file's last recorded pass
     (either flag, whichever last printed the block for it), recorded
     in `~/.claude/swe/inference-state.json`, keyed by the file's
     resolved path. A file with no recorded pass yet uses the same
     numbers as a plain absolute threshold (its first pass). This is
     what throttles a file already carrying, say, 20 known inference
     findings: most follow-up edits are fixes to those, not new prose,
     so they do not re-cross the threshold and do not get advised again
     until the file has genuinely grown.
   - **Any other source** (piped text, an HTML file): no stable
     identity across calls, so it always uses the plain absolute
     threshold, exactly as before.

`--force-inference` (used by `/swe:lint-file`) prints the same block
unconditionally: no gate, no threshold, no throttle. It still skips on
empty prose, and still records the pass (word/sentence count, for the
throttle above) whenever it prints the block. It is the current session
itself, right where `/swe:lint-file` was run, that then judges the file
directly; no subagent is dispatched for that command.

## The commit check

`/swe:install-commit-hook` installs a git `pre-commit` hook
([`../git-hooks/pre-commit.sh`](../git-hooks/pre-commit.sh), copied
verbatim as `pre-commit` by
[`../scripts/install-commit-hook.sh`](../scripts/install-commit-hook.sh))
in one repository's `.git/hooks/` (or wherever `core.hooksPath` points).
It runs outside any Claude Code session — no model, no plugin runtime —
so it can only run the deterministic tier itself and check a ledger; it
never judges the inference tier.

**The ledger.** `<git-common-dir>/swe/lint-log.ndjson`
(`git rev-parse --git-common-dir`, so one ledger per repository, shared
by every linked worktree). Append-only NDJSON, one row per
`--record-lint-result` call: `ts`, `path` (repo-relative), `blob` (git's
own blob object id for the exact content judged, via `git hash-object`,
not a `sha256` of the working-tree file), `algo` (`sha1`/`sha256`),
`status` (`clean`/`failed`), `tier` (`"both"`), `findings`, `rules_tag`,
`plugin_version`, `recorded_by`. A row is a candidate for a staged file
when `path` and `blob` both match that file's exact staged git blob (not
the working-tree copy, which can differ from what a partial `git add -p`
staged); among candidates for the same `(path, blob)`, the last row in
file order wins. `clean` means zero `error`-severity findings across
both tiers together; a warning never blocks anything here either,
matching every other check in this plugin.

**Recording a verdict.** Only `/swe:lint-file`'s own Step 5 does this
today, right after it judges a file's inference-tier findings itself
(see [`../skills/lint-file/SKILL.md`](../skills/lint-file/SKILL.md)):

```
python3 scripts/software_english_lint.py --record-lint-result {clean|failed} --findings N <file-path>
```

A standalone mode: no rule catalogue read, no report printed, no other
flag honoured alongside it. Exit 0 means recorded (including a
one-line note for a file outside a git repository, which needs no
ledger); exit 2 means the call itself was malformed; exit 3 means the
ledger could not be written — reported, not silent, unlike
`save_inference_state()` above, because a lost row here becomes a
commit blocked with no visible cause.

**Two state files, and why they are separate.**
`~/.claude/swe/inference-state.json` (above) is global, per-user, keyed
by resolved path, and answers "is a fresh advisory pass worth
dispatching" — a cost heuristic written before any judgement exists.
The ledger is per-repository, keyed by `(path, blob)`, and answers "was
this exact content judged, and what was the verdict" — written after
judgement. Merging them would let a `failed` verdict in one clone
suppress advisories for the same path in every other clone sharing that
global file, and would force the throttle file to grow without bound.
`/swe:lint-file` writes to both, at different steps; that is their only
coupling.

**Fail-open boundary.** The check fails open only when it cannot
evaluate the ledger at all: no `python3` on `PATH`, or the ledger file
present but unreadable. It fails closed on every answer it does
evaluate that is not `clean`, including an absent ledger file, which is
a fresh clone with nothing yet recorded: exactly the case this check
exists for. `git commit --no-verify` is the standing bypass; the block message
repeats it.

**Deterministic tier at commit time.** Advisory by default: findings
print but do not block, run against each staged file's exact staged
content (`git show :<path>`, not the working tree). Set
`commit-check.block_on_deterministic: true` in the project's
`.claude/swe-lint.json` to make it blocking too.

**Project configuration**, read from `<repo>/.claude/swe-lint.json`
only, under `commit-check` — the plugin's own `config.json` has no
equivalent key, because the git hook cannot reach it:

```json
{ "commit-check": { "enabled": true, "block_on_deterministic": false, "paths": ["*.md"] } }
```

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

Add `--advise-inference` to print the `INFERENCE_ADVISED` rules block
when a fresh pass would be worth doing, gated as above. Add
`--force-inference` to print the same block unconditionally instead: this is what `/swe:lint-file` does. Neither ever judges the prose
itself; that is always the caller's own job. Add `--quiet-vocab` to
omit `vocabulary-membership` lines; every hook does this by default.

Run `scripts/fetch-software-english-data.sh` once by hand first, if
`data/` is empty — the hooks do this automatically, a manual run does
not.

```bash
python3 scripts/software_english_lint.py FILE.md --record-lint-result clean --findings 0
```

Records a both-tier verdict for one named file in the commit check's
ledger; see "The commit check" above. Standalone: lints nothing itself,
needs no `data/` fetch, exits 0/2/3.

## Writing a skill's frontmatter

A `SKILL.md` frontmatter value must be valid YAML under a **strict**
parser, not just under Claude Code's own. Two rules, both enforced by
[`../tests/skill_frontmatter_test.sh`](../tests/skill_frontmatter_test.sh):

- An unquoted value must not hold `": "` (a colon then a space). YAML
  reads that as a second mapping separator and rejects the whole
  document. Use a comma instead. Quoting also parses, but a harness
  that splits on the first colon then shows the quote marks in the
  description, so removing the colon is the portable fix.
- An unquoted value must not open with a YAML indicator character
  (`[`, `{`, `|`, `>`, `&`, `*`, `!`, `%`, `@`, `` ` ``, `,`, `#`).
  Quote it: `argument-hint: "[uninstall] [repo-path]"`.

This is not theoretical. Claude Code accepts the invalid form, so a
broken skill looks fine locally while a strict-parsing harness drops it
with no error anyone sees. `/swe:lint-file`'s own description carried a
`": "` from `bd9edac` (v0.7.0) to v0.10.1 and was invisible in GitHub
Copilot CLI that whole time, while every other skill in the same plugin
loaded normally. A skill "missing" on one harness but not another is
this, until proven otherwise.

Copilot CLI additionally requires the frontmatter `name` to match the
skill's own directory name exactly; the same test asserts it.

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
- Judging the inference-based rules still costs real time, whether it
  is the current session doing it for `/swe:lint-file` or a dispatched
  subagent for a hook's advisory: it is real reasoning over real text,
  not a lookup. Moving it out of the script removed the subprocess and
  its own timeout, but not the underlying cost of the judgement itself.
- `bash-check.sh` and `mcp-send-check.sh` advise inference only after
  already letting the underlying tool call proceed unblocked: a commit
  can be amended once a finding comes back, but a sent message cannot
  be un-sent. This is the accepted cost of not holding up either tool
  call for the judgement.
- The growth-since-last-pass throttle (`inference_eligible()`) only
  applies to a single named file. A commit/PR message or an outbound
  MCP message has no identity across separate tool calls, so each one
  is still judged solely against the plain absolute threshold, same as
  before this rework.
- `~/.claude/swe/inference-state.json` is never pruned. It holds a
  small amount of text per file ever checked; it is not cleaned up
  automatically yet.
- The commit check's ledger is never pruned either, and `.git/` is never
  cloned, so each clone of a repository starts with an empty ledger and
  needs its own `/swe:install-commit-hook` run.
- `git diff --cached --diff-filter=ACM` skips a pure rename (`R`), which
  is correct (the content was already judged), but a rename with edits
  is also reported as `R` and so slips through unchecked.
- A partial stage (`git add -p`) can leave the staged blob different
  from any content that was ever judged, blocking the commit until the
  staged content itself is judged, not just the file on disk.
- `git commit --amend` re-runs `pre-commit`; a rebase or a merge commit
  (`pre-merge-commit`) does not, since this hook is installed under that
  name alone.
- A `clean` row proves a judgement happened, not that it was correct:
  the check trusts whatever `/swe:lint-file`'s Step 5 recorded.
- The `pre-commit` hook duplicates `is_path_ignored()`/
  `load_ignore_patterns()` from `scripts/software_english_lint.py`
  rather than importing them, since it must behave the same whether or
  not the plugin that installed it is still present. The two
  implementations can drift.
