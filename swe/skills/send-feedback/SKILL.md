---
name: send-feedback
description: Review the accumulated swe feedback log for real patterns, and file a GitHub issue for each one the user confirms
argument-hint: (no arguments)
allowed-tools: Bash, Read
disable-model-invocation: false
---

# send-feedback

Read the feedback log at `~/.claude/swe/feedback.jsonl`
(written by `/swe:feedback` and by the linter's inference tier). Find
patterns worth a GitHub issue, discuss each one with the user, and file
only the ones the user confirms.

This command makes GitHub API calls (`gh issue create`) once a pattern
is confirmed. Reading and clustering the log makes no network call.

## Step 1: Read the log

```
cat ~/.claude/swe/feedback.jsonl 2>/dev/null
```

If the file does not exist, or every line was already archived (see
Step 5), say so and stop. Nothing to review is a normal outcome, not an
error.

Parse each line as one JSON object. Two kinds of entry:

- `finding_feedback`: a person's verdict on one lint finding.
- `inference_call_start` / `inference_call_end`: bracket one inference-
  tier model call, matched by `call_id`.

## Step 2: Find the stalled-call pattern

Match every `inference_call_start` to an `inference_call_end` with the
same `call_id`. A `start` with no matching `end` means the hook process
was terminated mid-call. Claude Code gives no other signal when a hook
times out.

Count these. If one or more exist, this is itself a candidate pattern:
"N inference-tier calls started but never finished." Treat it the same
as a rule-based pattern in Step 4 (one point, on its own, discussed
before moving to the next).

## Step 3: Cluster the finding feedback

Group `finding_feedback` entries by `rule_id` and `verdict`. A cluster
of two or more entries sharing both is a candidate pattern. A single
entry with no siblings is not a pattern yet: leave it in the log for a
future run, where more evidence might join it (see Step 5).

For each candidate cluster, use the entries' own `quote` and `note`
fields to judge whether it looks like a real, fixable issue (a genuine
gap or false-positive shape), rather than a one-off misunderstanding.
This needs judgement: two "false-positive" reports on the same rule
that flag unrelated kinds of text are not the same pattern, even though
they share a `rule_id`.

## Step 4: Discuss one pattern at a time

For each real candidate pattern found in Step 2 or Step 3, in turn:

1. State the pattern: the rule ID, the verdict, how many entries, and
   one or two representative quotes.
2. State a proposed fix direction (e.g. "check the subject before this
   rule fires", "add an exemption for X", "narrow the trigger phrase").
3. Ask whether to file a GitHub issue for it.
4. Wait for the answer before moving to the next pattern. Do not list
   every pattern up front. This project's own convention is one point
   at a time.

## Step 5: File a confirmed issue, and archive its entries

When the user confirms a pattern:

1. Decide the target repository:
   - If `rule_id` appears in
     `swe/rules/plugin-rules.toml`, the target is
     `jimbarritt/claude-plugins`.
   - Otherwise, if it appears in
     `swe/data/core-rules.toml` (or the working tree
     at `~/Code/github/jimbarritt/software-english/rules/core-rules.toml`),
     the target is `jimbarritt/software-english`.
   - For the stalled-call pattern (Step 2), the target is
     `jimbarritt/claude-plugins`: the hook mechanism, not the spec.
   - If `rule_id` is `unknown` or not found in either file, ask the
     user which repository to use.
2. Draft a short issue title and body from the pattern's own detail (the
   rule ID, the verdict, the representative quotes, the proposed fix
   direction). Do not add any AI-assistance attribution.
3. Ensure the `auto-fix-candidate` label exists on the target repo:
   `gh label create auto-fix-candidate --repo <owner/repo> --color
   ededed --description "Candidate for the supervised fix harness" 2>/dev/null`
   (the harness in the Operational hardening / feedback loop Delta
   reads issues by this label; ignore a "label already exists" error).
   Ask the user before applying the label to an issue that reports
   something other than a concrete, scoped rule bug. A design question
   or a feature request is not a fix-harness candidate.
4. Run `gh issue create --repo <owner/repo> --title "..." --body "..."
   --label auto-fix-candidate` (omit `--label` if Step 3 said not to
   apply it).
5. Move every log line belonging to this pattern's entries into an
   archive file: `~/.claude/swe/feedback-archive/{today's date, YYYY-MM-DD}.jsonl`. Rewrite the current log with those
   lines removed. Use a small Python script for this: read all lines,
   split into "belongs to this pattern" and "everything else," append
   the first group to the archive file, and overwrite the current log
   with the second group.

When the user declines a pattern, leave its entries in the live log.
Do not archive a dismissed pattern, in case more evidence changes the
call later.

## Step 6: Summarise

After every pattern is discussed, state in one or two lines: how many
issues were filed, how many patterns were declined, and how many
individual entries remain in the log (too few to cluster yet).
