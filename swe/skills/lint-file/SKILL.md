---
name: lint-file
description: Run a full swe check on a named file, on demand: both tiers, regardless of hook gating
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
`===INFERENCE_ADVISED===`...`===END_INFERENCE_ADVISED===` block:
the inference-based rules that apply here (`- rule-id: description`,
one per line). The script never judges the file against them itself:
it has no model access and never spawns one. It records this pass in
`~/.claude/swe/inference-state.json`, so a hook-advised subagent's pass
on the same file counts too, for the throttle `--advise-inference`
applies.

If the file has no prose to check (e.g. empty, or a code file with no
comments), no block is printed; skip Step 4.

## Step 4: Judge the file against the inference rules yourself

Read `<file-path>` (the `Read` tool). Using the rules from the block
above, judge the file's own prose against each one directly, as part
of your own reasoning. There is no separate call to make or process to
wait on for this step. Note any violation as `<file-path>:<line>:
[severity] [rule-id] detail`, matching the deterministic tier's own
format. Severity comes from the rule's own catalogue entry
(`data/core-rules.toml`).

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
  --record-lint-result clean --findings 0 <file-path>
```

One or more errors:

```
python3 "$CLAUDE_PLUGIN_ROOT/scripts/software_english_lint.py" \
  --record-lint-result failed --findings <count> <file-path>
```

The row is keyed to the file's exact content at this moment, via its
git blob id. Any later edit invalidates it, so run this after judging,
not before, and re-run `/swe:lint-file` after a fix.

Exit 0 means recorded (including a one-line note when the file is
outside a git repository, which needs no further action). Exit 2 means
the command itself was malformed; fix the arguments and run it again.
Exit 3 means the ledger could not be written: report that line as-is,
because a commit staging this file will then be blocked with no other
explanation.

## Step 6: Report

Print every finding, deterministic and inference-tier alike, one line
each with severity. If there are none, say the file is clean, both
tiers. Do not fix anything unless asked: this command is a check, not
an edit.
