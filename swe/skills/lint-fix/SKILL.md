---
name: lint-fix
description: Run a full swe check on a named file, fix each finding, check the edit, and report what remains
argument-hint: <file-path>
allowed-tools: Bash, Read, Edit
disable-model-invocation: false
---

# lint-fix

Check one named file against Software English, both tiers, fix the
findings in the file, then check the edited file again. `/swe:lint-file`
runs the same check and changes nothing. This command edits the file
with no prior question: a run of this command is the request to fix.

This command does one fix pass and one second check. It does not
repeat the fix pass until the file is clean. Step 6 reports each
finding that the second check finds.

## Text this command shares with lint-file

Before Step 2, read `${CLAUDE_PLUGIN_ROOT}/skills/lint-file/SKILL.md`
in full with the `Read` tool. Its Step 3 and Step 4 text applies here
without change: what the output file contains, the `swe-lint-units`
and `swe-lint-nonce` lines, the three passes of Step 4, and the finding
format. Run the commands given in this file, not the commands in that
file. Where that file names "Step 5", it means Step 5 of this file.
Where that file states no fix, or states to run `/swe:lint-file` again
after a fix, Steps 3 to 5 of this file apply instead.

## Step 1: Read the argument

Argument given: $ARGUMENTS

This is one file path, relative to the current project unless given as
absolute. If it is blank, ask which file to fix.

## Step 2: Run the first check

Fetch the rule data:

```
"${CLAUDE_PLUGIN_ROOT}/scripts/fetch-software-english-data.sh"
```

If this fails and prints "no cached data available", report that and
stop: there is nothing to check against.

Run the deterministic tier and get the inference rules:

```
out="$(mktemp "${TMPDIR:-/tmp}/swe-lint.XXXXXX")"; python3 "${CLAUDE_PLUGIN_ROOT}/scripts/software_english_lint.py" <file-path> --force-inference --quiet-vocab > "$out" 2>&1; echo "swe-lint output: $out"
```

Read the named output file in full, as lint-file's Step 3 states. Do
not write this output, or a copy of it, inside the repository, and do
not use a fixed file name. Then judge the file in the three passes of
lint-file's Step 4.

Keep a list of every finding from this check: the deterministic tier's
findings from the output file, and each violation from the three
passes. This is the list Step 3 fixes.

If the list is empty, the file needs no edit: skip Steps 3 and 4, and
record the verdict in Step 5 with this check's nonce and unit total.

## Step 3: Fix the findings

Edit `<file-path>` with the `Edit` tool, and no other file, one finding
at a time, every `error` finding first, then every `warning` finding.

For each finding:

- When the finding line names a replacement, use it.
- Change the wording or the order of the text only. Keep every fact: a
  value, a name, a command, a path, a number, a link target, and a
  claim stay the same.
- Change only the text the finding is about, plus the minimum text
  around it that the fix needs, for example the sentence before a
  moved paragraph.
- Do not edit text inside a fenced code block, an inline code span, or
  a blockquote line (a line that starts with `>`). That text is code
  or a quotation. A finding there stays, and Step 6 reports it.
- Do not edit when the fix needs a fact the file does not state, or a
  choice between two facts the file states. For example, for
  `[no-contradiction-between-sections]`, the choice of which section
  is correct belongs to the author. Note the finding as not fixed,
  with the reason, for Step 6.
- Make one fix attempt per finding. Do not edit the same finding a
  second time.

Keep a list of each edit: the line, the rule id, and the change in a
few words. Step 6 reports this list.

## Step 4: Run the second check

If Step 3 made no edit, skip this step: Step 2's findings, nonce, and
unit total are the result.

Otherwise, run Step 2's lint command again, on the file as it is now.
This writes a new output file and prints a new nonce. Step 2's nonce
does not match the edited file, so do not use it. Do not fetch the
rule data again: the second check uses the same rule data as the
first, so the two results compare.

Read the new output file in full, and judge the file again in all
three passes of lint-file's Step 4. Judge the content as it is now, in
full: a judgement from Step 2 does not apply to edited content, and
does not apply to text near an edit.

Do not fix any finding from this step. These findings are the result
that Step 5 records and Step 6 reports.

## Step 5: Record the verdict

Count the `error`-severity findings from the result: the deterministic
tier's count from the last output file, plus the errors from the last
three passes. Pass 3 adds only warnings. Use the nonce and the unit
total `M` from the last output file.

Every unit judged, zero errors:

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/software_english_lint.py" \
  --record-lint-result clean --findings 0 --nonce <value> \
  --units-judged <M> --recorded-by lint-fix <file-path>
```

Every unit judged, one or more errors:

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/software_english_lint.py" \
  --record-lint-result failed --findings <count> --nonce <value> \
  --units-judged <M> --recorded-by lint-fix <file-path>
```

Only some units judged: pass `--units-judged "<N> of <M>"`, quoted, as
lint-file's Step 5 states.

Record `ignored` only when the user asked for the exemption, with the
`--reason` that lint-file's Step 5 requires. Never record `ignored`
for a finding that Step 3 did not fix, unless the user asks for it.

If the last line of the output file reads `swe: no lint nonce issued
for <file>: <reason>`, skip this step.

The exit codes are the same as in lint-file's Step 5. On exit 4, run
Step 4 again on the file as it is now, then this step. Do not run
Step 3 again.

## Step 6: Report

Report three lists, in this order:

1. The edits from Step 3, one line each: line, rule id, and the
   change. If there are none, say that the first check found nothing
   to fix.
2. The findings that Step 3 did not fix, one line each, with the
   reason.
3. Every finding from the result (Step 4, or Step 2 when Step 4 was
   skipped), deterministic and inference-tier alike, one line each
   with severity. This is what remains. If it is empty, say that the
   file is clean, both tiers, after the fix.

The edits are in the working tree and are not committed. `git diff
<file-path>` shows them.

Report a `swe: stale rule data: ...` line, a `partial` row, and an
`ignored` row the same way lint-file's Step 6 states.
