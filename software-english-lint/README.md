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

## Pick up a newer version of the Software English spec

Edit the tag in [`software-english.json`](software-english.json). The
next hook run fetches it.

## Read a `warning`-severity finding

Treat it as advisory: it never blocks anything. Most
`vocabulary-membership` findings run at this severity today, since the
approved word list is a seed set, not yet exhaustive.
