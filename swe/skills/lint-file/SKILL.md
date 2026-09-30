---
name: lint-file
description: Run a full swe check on a named file, on demand, both tiers, regardless of hook gating
argument-hint: <file-path>
allowed-tools: Bash, Read
disable-model-invocation: false
---

# lint-file

Check one named file against Software English, both tiers, right now.
The automatic hooks only advise a fresh inference pass when the
deterministic tier is already clean and the prose passes a length
threshold; this command runs the check unconditionally, because it
exists for the case where you want the full check regardless.

## Step 1: Read the argument

`$ARGUMENTS` holds one file path, relative to the current project unless
given as absolute. If empty, ask which file to check.

## Step 2: Fetch the rule data

```
"$CLAUDE_PLUGIN_ROOT/scripts/fetch-software-english-data.sh"
```

If this fails and prints "no cached data available", report that and
stop: there is nothing to check against.

## Step 3: Run the deterministic tier and get the inference rules

```
python3 "$CLAUDE_PLUGIN_ROOT/scripts/software_english_lint.py" <file-path> --force-inference --quiet-vocab
```

This prints the deterministic tier's findings, if any, the normal way.
`--force-inference` additionally prints a fenced
`===INFERENCE_ADVISED===`...`===END_INFERENCE_ADVISED===` block: one
line per inference-based rule that applies here, each shaped like a
finding so it survives a findings-shaped filter, `<file>:0: [warning]
[rule-id] inference pending: description` (a rule whose own catalogue
severity is not `warning` adds `(severity on violation: <severity>)`),
followed by one summary line, `<file>:0: [warning] [inference-pending]
N inference rule(s) above need model judgement; this script does not
judge them. Deterministic tier: E error(s), W warning(s).` The script
never judges the file against them itself: it has no model access and
never spawns one. It records this pass in
`~/.claude/swe/inference-state.json`, so a hook-advised subagent's pass
on the same file counts too, for the throttle `--advise-inference`
applies.

Do not filter or truncate this command's output (no `head`, `sed`,
`tail`, or `grep`). Step 4 must judge against the rules printed here,
in full, not a list recalled from earlier in the conversation. A
findings-shaped grep now keeps the rule and summary lines (they are
line-0, `[warning]` lines like any other), but still drops the
`swe-lint-nonce` line Step 5 needs, so filtering still loses something.

The last line of output is `swe-lint-nonce: <value>`. Step 5 needs
that value. It is valid for this file's exact current content only,
and only once. If instead the last line reads `swe: no lint
nonce issued for <file>: <reason>`, the file needs no ledger row (it
is outside a git repository, or matched by `.swe-ignore`); do Step 4
and skip Step 5.

If the file has no prose to check (e.g. empty, or a code file with no
comments), no `===INFERENCE_ADVISED===` block is printed; skip Step 4.
The nonce line still prints in this case, since a no-prose file still
needs a `clean` row recorded in Step 5.

## Step 4: Judge the file against the inference rules yourself

Read `<file-path>` (the `Read` tool). Using each `inference pending`
line from Step 3, one rule per line, its id in brackets, its
description after `inference pending:`, judge the file's own prose
against each rule directly, as part of your own reasoning. Ignore the
trailing `[inference-pending]` summary line; it is a count, not a rule.
There is no separate call to make or process to wait on for this step.
Note any violation as `<file-path>:<line>: [severity] [rule-id]
detail`, matching the deterministic tier's own format. Severity is
`warning` unless the rule's line ends `(severity on violation:
<severity>)`, in which case use that.

A judgement made earlier, in this session or any other, never applies
to changed content. Even a one-token edit makes this a new file. Judge
the content as it is now, in full, every time. The ledger is keyed by
content for exactly this reason, and Step 5's nonce enforces it: a
nonce issued before an edit no longer matches the file's blob, so
Step 5 rejects it.

## Step 5: Record the verdict

The commit check (`/swe:install-commit-hook`) reads a repository-local
ledger of judged files, separate from `~/.claude/swe/inference-state.json`
(that file only throttles the automatic hooks' advisories). Record this
pass there, so a commit staging this file is not blocked for content
already checked here.

Count the `error`-severity findings: the deterministic tier's own count
from Step 3, plus any you found judging the inference rules in Step 4
(0 if Step 4 was skipped for lack of prose). Warnings do not count.

Zero errors:

```
python3 "$CLAUDE_PLUGIN_ROOT/scripts/software_english_lint.py" \
  --record-lint-result clean --findings 0 --nonce <value from Step 3> <file-path>
```

One or more errors:

```
python3 "$CLAUDE_PLUGIN_ROOT/scripts/software_english_lint.py" \
  --record-lint-result failed --findings <count> --nonce <value from Step 3> <file-path>
```

The row is keyed to the file's exact content at this moment, via its
git blob id. Any later edit invalidates it, so run this after judging,
not before, and re-run `/swe:lint-file` after a fix.

Exit 0 means recorded (including a one-line note when the file is
outside a git repository, which needs no further action). Exit 2 means
the command itself was malformed; fix the arguments and run it again.
Exit 3 means the ledger could not be written: report that line as-is,
because a commit staging this file will then be blocked with no other
explanation. Exit 4 means the nonce was rejected: missing, unknown,
already used, issued for another file, or the file changed after
Step 3. Do not retry with another value: go back to Step 3 and run
Steps 3, 4, and 5 again on the file as it is now.

## Step 6: Report

Print every finding, deterministic and inference-tier alike, one line
each with severity. This is the violations found in Step 4, not the
`inference pending` lines or the `[inference-pending]` summary line
from Step 3, which name rules to check, not findings. If there are
none, say the file is clean, both tiers. Do not fix anything unless
asked: this command is a check, not an edit.
