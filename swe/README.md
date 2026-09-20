# swe

Checks every commit message, artifact, and outbound message a Claude
Code or Copilot CLI session produces, against
[Software English](https://github.com/jimbarritt/software-english),
automatically, once installed. Also installs an output style, written
to the same rules, that you can select yourself
(`/output-style`) to shape a reply or a file edit directly as it's
written; and a `/swe:lint-file` command to check any file on demand.

See [`docs/agent-guide.md`](docs/agent-guide.md) for the mechanism: the
hooks, the rule tiers, and the inference tier's conditions. That file
is for an agent running inside a project with this plugin installed,
not for a person.

## Install it

```text
/plugin marketplace add jimbarritt/claude-plugins
/plugin install swe@jimbarritt-claude-plugins
```

No further setup is needed.

Have `jq` on `PATH` first: every hook parses its JSON input with it. No
extra tool is needed for the inference tier: it is Claude itself,
reasoning directly, not a separate process. For `/swe:send-feedback`,
have `gh` on `PATH`, authenticated against GitHub.

## What happens once it is installed

Nothing is forced on, and no file edit or chat reply is checked
automatically. Select the output style yourself
(`/output-style`, "Software English") if you want the rules shaping
what Claude writes from the first word, reply or file alike; run
`/swe:lint-file` yourself, e.g. before a commit, to check a file
directly. Neither is wired up to run on its own.

Commit messages, artifacts, and outbound messages do get checked
automatically, on both Claude Code and Copilot CLI, since these are
one-off actions worth catching before they go out, not ongoing prose a
person is already shaping as they write it. When the check finds a
plain, pattern-checkable violation (the deterministic tier: banned
words, vocabulary, tense, and similar), Claude Code blocks the action;
Claude reads the printed report and fixes the text itself, then
continues. Most of the time, this needs no attention from you.

A check that passes deterministically can still be due a deeper,
model-judged pass (the inference tier). Rather than run that inside
the hook itself, which can stall a tool call on a slow or failed model
response, the hook only advises Claude that a fresh pass is worth
doing; Claude dispatches it as a subagent, then fixes anything it
reports. The underlying command or send already went through by the
time the subagent's report comes back, since the hook does not hold it
up for a model call. A commit can be amended after the fact if
something turns up; an already-sent message stays sent regardless.
Publishing the same artefact
file repeatedly does not trigger a fresh deep pass on every single
publish, only once it has grown enough since its last pass to be worth
checking again.

## What the output style costs

Selecting the output style costs roughly 6% to 11% more input tokens
per turn than leaving it unselected. The style's own text goes into the
system prompt on every request, which is where the cost falls.

| Prompt length | Extra input tokens |
|---|---|
| Short | 10.8% |
| Medium | 9.5% |
| Long | 6.0% |

The figure shrinks as a share of the total as the prompt grows, because
the style's text is a fixed size. The styled condition also writes
fewer output tokens throughout, so the extra cost is input-side, not
longer replies.

No latency cost is established. A one-repeat pilot suggested about a
second of extra time to first token, and a 45-run measurement did not
reproduce it: the gap ran in both directions across prompt lengths, and
stayed smaller than the spread within a single condition.

Measured against `swe` 0.9.1 on `sonnet`, 45 runs, 5 repeats across 3
prompt lengths, 0 errors, using the headless latency harness in
`jimbarritt/tsk` (`ops/local/run-latency-harness.py`). The hooks
themselves cost nothing measurable per turn at that version.

## Check one file on demand

```text
/swe:lint-file <file-path>
```

Runs both tiers on the named file, right now: the deterministic tier,
and the inference tier as well, regardless of whether the file already
has deterministic errors or is short enough to normally skip it. Use
this when you want the full check without editing the file first.

## Check commits against a clean lint

```text
/swe:install-commit-hook
```

Installs a git `pre-commit` hook in the current repository. Once
installed, a commit staging a markdown file is blocked unless
`/swe:lint-file` has already recorded a `clean` verdict for that file's
exact staged content. An edit after the last lint pass invalidates the
record, so re-run `/swe:lint-file` after any change.

A blocked commit prints which files need a fresh lint pass and the
exact command to run. `git commit --no-verify` bypasses the check for
one commit. An existing `pre-commit` hook in the repository is kept and
chained, not replaced: it still runs, first, unchanged.

`.git/` is never cloned, so run `/swe:install-commit-hook` again in
each clone of the repository. Run `/swe:install-commit-hook uninstall`
to remove it.

## Report a wrong finding, or feedback about the tooling itself

If you see a finding that looks wrong, or want to report something
about the plugin's own tooling, run this as soon as you notice it:

```text
/swe:feedback <false-positive|false-negative|wrong-fix|feature-request> [note]
```

This takes a few seconds and makes no network call. It logs the rule
ID, the source, the flagged (or missed) text, and your note, to
`~/.claude/swe/feedback.jsonl`.

## Review logged feedback and file issues

Run this on your own schedule, not automatically:

```text
/swe:send-feedback
```

Answer its questions one at a time. For each real pattern it finds
across the log, it proposes a fix direction and asks whether to file a
`gh issue create` against the repository that owns the rule.

## Exempt a whole file from every check

Add a line to a `.swe-ignore` file at the project root, in the same
format as `.gitignore`: a path relative to that root, or a bare
filename to match at any depth. One pattern per line; `#` starts a
comment.

## Exempt one line from every check

Add this marker to the line:

```text
<!-- swe: ignore -->
```

A Markdown blockquote (a line starting with `>`) is exempt without a
marker, for a deliberate quote of someone else's exact words.

## Turn off a check for one project

Each of the plugin's checks can be turned off for one project, without
touching the plugin's own install. Create `.claude/swe-lint.json` at the
project root and set only the keys you want to change:

```json
{
  "hooks": {
    "bash": false
  }
}
```

Keys, all `true` by default:

| Key | Turns off |
|---|---|
| `bash` | The check on a `git commit`, `gh pr`, or `gh issue` message |
| `artifact` | The check on a file about to publish as an Artifact |
| `mcp-send` | The check on an outbound Slack/Gmail/Drive message | <!-- swe: ignore -->

A missing file, a missing key, or a value other than `false` leaves that
check on. The same defaults live in the plugin's own `config.json`, so a
project file only needs to list what it changes.

The commit check reads its own settings from the same file, under
`commit-check`, since the installed git hook runs outside the plugin and
has no access to `config.json`:

| Key | Default | Meaning |
|---|---|---|
| `commit-check.enabled` | `true` | Set `false` to skip the check entirely. |
| `commit-check.block_on_deterministic` | `false` | Set `true` to also block on a deterministic-tier finding, not just a missing or failed lint record. |
| `commit-check.paths` | `["*.md"]` | Glob patterns for which staged files this covers. |

## Pick up a newer version of the Software English spec

Edit the tag in [`software-english.json`](software-english.json). The
next hook run fetches it.

## Read a `warning`-severity finding

Treat it as advisory: it never blocks anything. Most
`vocabulary-membership` findings run at this severity today, since the
approved word list is a seed set, not yet exhaustive.
