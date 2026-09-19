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

## Step 5: Report

Print every finding, deterministic and inference-tier alike, one line
each with severity. If there are none, say the file is clean, both
tiers. Do not fix anything unless asked: this command is a check, not
an edit.
