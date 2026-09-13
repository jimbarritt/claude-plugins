---
name: swe-feedback
description: Log a false positive, a false negative, or a wrong fix suggestion from software-english-lint, for later review by /swe-send-feedback
argument-hint: <false-positive|false-negative|wrong-fix> [note]
allowed-tools: Bash
disable-model-invocation: false
---

# swe-feedback

Log one piece of feedback about a software-english-lint finding. This
command makes no network call. It only appends one line to a local log
file, at `~/.claude/software-english-lint/feedback.jsonl`.

## Step 1: Read the arguments

`$ARGUMENTS` holds a verdict, then an optional note:

- `false-positive`: a finding fired, but the flagged text does not
  break the rule.
- `false-negative`: a real fault exists, but no finding fired for it.
- `wrong-fix`: a finding is correct, but its suggested fix is wrong or
  breaks the sentence.

The first word is the verdict. Everything after it is the note. Reject
an unrecognised verdict and ask for one of the three above.

## Step 2: Gather the finding's details

**For `false-positive` or `wrong-fix`:** look back through this
conversation for the most recent software-english-lint report (a Stop
hook block, a `PreToolUse` block, or a `PostToolUse` report). Find the
specific finding line the user means:

- `rule_id`: the bracketed rule name (e.g. `[banned-word]`, or the
  name before `: inference:` on an inference-tier line).
- `source`: the label before the line number (e.g. `reply`,
  `transcript`, a file path, a tool name).
- `location`: the line number, or empty for an inference-tier finding.
- `quote`: the flagged text.

If more than one finding could match and the user's message does not
say which, ask which one before logging anything.

**For `false-negative`:** no prior finding exists to look back at. That
absence is the point. Take the flagged text and, if the user names it,
the rule that should have caught it, from the user's own message. Use
`rule_id: "unknown"` if the user does not name one. Use `source:
"user-reported"` and leave `location` empty.

## Step 3: Append the log entry

Run this, filling in the values found above (escape embedded quotes and
newlines as normal JSON string content):

```
mkdir -p ~/.claude/software-english-lint
python3 -c "
import json, datetime, sys
entry = {
    'type': 'finding_feedback',
    'timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'verdict': '<false-positive|false-negative|wrong-fix>',
    'rule_id': '<rule id>',
    'source': '<source>',
    'location': '<line number or null>',
    'quote': '''<flagged text>''',
    'note': '''<note, or empty string>''',
}
with open('$HOME/.claude/software-english-lint/feedback.jsonl', 'a') as f:
    f.write(json.dumps(entry) + '\n')
print('Logged.')
"
```

## Step 4: Confirm

State back, in one short line, what was logged: the verdict, the rule
ID, and a short excerpt of the quote. Do not ask whether to log it:
running this command already asked.
