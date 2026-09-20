---
name: feedback
description: Log a false positive, false negative, wrong fix, or feature request about swe, for review by /swe:send-feedback
argument-hint: <false-positive|false-negative|wrong-fix|feature-request> [note]
allowed-tools: Bash
disable-model-invocation: false
---

# feedback

Log one piece of feedback about swe. This command makes no network
call. It only appends one line to a local log file, at
`~/.claude/swe/feedback.jsonl`.

## Step 1: Read the arguments

`$ARGUMENTS` holds a verdict, then an optional note:

- `false-positive`: a finding fired, but the flagged text does not
  break the rule.
- `false-negative`: a real fault exists, but no finding fired for it.
- `wrong-fix`: a finding is correct, but its suggested fix is wrong or
  breaks the sentence.
- `feature-request`: feedback about the tooling itself (a skill, a
  hook, the feedback loop, anything not tied to one specific finding).

The first word is the verdict. Everything after it is the note. Reject
an unrecognised verdict and ask for one of the four above.

## Step 2: Gather the finding's details

**For `false-positive` or `wrong-fix`:** look back through this
conversation for the most recent swe report (a `PreToolUse` block, or
the deterministic-tier output from a manual `/swe:lint-file` run).
Find the specific finding line the user means:

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

**For `feature-request`:** no finding, and no rule involved. Use
`rule_id: null` (not the string `"unknown"`, which means "a real rule
should exist here but I don't know which"). A feature request names no
rule at all, so it needs a different, non-colliding marker. Use
`source: "user-reported"`, leave `location` and `quote` empty, and put
the ask itself in `note`.

## Step 3: Append the log entry

Run this, filling in the values found above (escape embedded quotes and
newlines as normal JSON string content). `rule_id` is a Python
expression, not always a string: use `'<rule id>'` (quoted) for
`false-positive`/`wrong-fix`/a named `false-negative` rule, the literal
string `'unknown'` (quoted) for an unnamed `false-negative`, and the
literal `None` (**not** quoted: it must serialise to JSON `null`, not
the string `"null"`) for `feature-request`:

```
mkdir -p ~/.claude/swe
python3 -c "
import json, datetime, sys
entry = {
    'type': 'finding_feedback',
    'timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'verdict': '<false-positive|false-negative|wrong-fix|feature-request>',
    'rule_id': <'<rule id>' or 'unknown' or None>,
    'source': '<source>',
    'location': '<line number or None>',
    'quote': '''<flagged text, or empty string>''',
    'note': '''<note, or empty string>''',
}
with open('$HOME/.claude/swe/feedback.jsonl', 'a') as f:
    f.write(json.dumps(entry) + '\n')
print('Logged.')
"
```

## Step 4: Confirm

State back, in one short line, what was logged: the verdict, plus the
rule ID and a short excerpt of the quote (or, for `feature-request`,
a short excerpt of the note instead, since there is no rule or quote).
Do not ask whether to log it: running this command already asked.
