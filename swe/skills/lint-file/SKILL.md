---
name: lint-file
description: Run a full swe check on a named file, on demand — both the deterministic tier and a forced inference tier, regardless of the automatic hooks' gating
argument-hint: <file-path>
allowed-tools: Bash
disable-model-invocation: false
---

# lint-file

Check one named file against Software English, both tiers, right now.
The automatic hooks only run the inference tier when the deterministic
tier is already clean and the prose passes a length threshold; this
command runs inference unconditionally, because it exists for the case
where you want the full check regardless.

## Step 1: Read the argument

`$ARGUMENTS` holds one file path, relative to the current project unless
given as absolute. If empty, ask which file to check.

## Step 2: Fetch the rule data

```
"$CLAUDE_PLUGIN_ROOT/scripts/fetch-software-english-data.sh"
```

If this fails and prints "no cached data available", report that and
stop — there is nothing to check against.

## Step 3: Run both tiers

```
python3 "$CLAUDE_PLUGIN_ROOT/scripts/software_english_lint.py" <file-path> --force-inference --quiet-vocab
```

`--force-inference` runs the inference tier unconditionally, in this
same process: it ignores the deterministic-clean gate, the length
threshold, and the growth-since-last-pass throttle that
`--advise-inference` (used by the hooks) applies instead of running
inference itself. It still skips if the file has no prose to check
(e.g. empty, or a code file with no comments). It records this pass in
`~/.claude/swe/inference-state.json`, so a hook-advised subagent run on
the same file counts too, for the throttle above.

## Step 4: Report

Print the findings back exactly as the linter reported them, one line
each, with severity. If there are none, say the file is clean, both
tiers. Do not fix anything unless asked — this command is a check, not
an edit.
