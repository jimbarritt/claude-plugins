# software-english-lint

Checks every reply, file edit, commit message, artifact, and outbound
message a Claude Code session produces against
[Software English](https://github.com/jimbarritt/software-english),
automatically, once installed.

See [`docs/agent-guide.md`](docs/agent-guide.md) for the mechanism: the
hooks, the rule tiers, and the inference tier's conditions. That file
is for an agent running inside a project with this plugin installed,
not for a person.

## Install it

```text
/plugin marketplace add jimbarritt/claude-plugins
/plugin install software-english-lint@jimbarritt-claude-plugins
```

No further setup is needed.

Have `jq` on `PATH` first: every hook parses its JSON input with it.
For the inference tier, have `claude` on `PATH` too. For
`/swe-send-feedback`, have `gh` on `PATH`, authenticated against
GitHub.

## What happens once it is installed

Claude's own replies, file edits, commit messages, and outbound
messages get checked as they happen. When one breaks a rule, Claude
Code blocks the action; Claude reads the printed report and fixes the
text itself, then continues. Most of the time, this needs no attention
from you.

When a file write breaks a rule, Claude reads the printed report and
fixes the file.

## Report a wrong finding

If you see a finding that looks wrong, run this as soon as you notice
it:

```text
/swe-feedback <false-positive|false-negative|wrong-fix> [note]
```

This takes a few seconds and makes no network call. It logs the rule
ID, the source, the flagged (or missed) text, and your note, to
`~/.claude/software-english-lint/feedback.jsonl`.

## Review logged feedback and file issues

Run this on your own schedule, not automatically:

```text
/swe-send-feedback
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
    "stop": { "reply": false }
  }
}
```

Keys, all `true` by default:

| Key | Turns off |
|---|---|
| `stop.reply` | The Stop hook's check of the chat reply and the transcript |
| `stop.docs` | The Stop hook's check of changed tracked markdown |
| `file` | The per-edit check on an untracked or out-of-tree markdown file, or a code file's comments. Also takes over tracked markdown when `stop.docs` is off |
| `bash` | The check on a `git commit`, `gh pr`, or `gh issue` message |
| `artifact` | The check on a file about to publish as an Artifact |
| `mcp-send` | The check on an outbound Slack/Gmail/Drive message |

A missing file, a missing key, or a value other than `false` leaves that
check on. The same defaults live in the plugin's own `config.json`, so a
project file only needs to list what it changes.

## Pick up a newer version of the Software English spec

Edit the tag in [`software-english.json`](software-english.json). The
next hook run fetches it.

## Read a `warning`-severity finding

Treat it as advisory: it never blocks anything. Most
`vocabulary-membership` findings run at this severity today, since the
approved word list is a seed set, not yet exhaustive.
