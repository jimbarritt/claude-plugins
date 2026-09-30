---
name: send-feedback
description: Review the accumulated swe feedback log for real patterns, and file a confirmed GitHub issue for each one
argument-hint: (no arguments)
allowed-tools: Bash, Read
disable-model-invocation: false
---

# send-feedback

Read the feedback log at `~/.claude/swe/feedback.jsonl`, written by
`/swe:feedback`. Find every entry or cluster of entries worth a GitHub
issue, discuss each one with the user, and file only the ones the user
confirms.

This command makes GitHub API calls (`gh issue create`) once an item
is confirmed. Reading and grouping the log makes no network call.

## The issue tracker is public; the feedback log is not

`/swe:feedback` writes each entry while the user works on their own
project, which is often private code. So an entry's `quote` and `note`
can hold employer and project names, service, domain and repository
names, ticket ids, internal PR or issue numbers, and verbatim excerpts
from internal documents. That is acceptable in the log, which can hold
this detail. A GitHub issue is public, and a published issue cannot be
fully withdrawn.

So never pass an internal reference into an issue title or body:

- no employer, client or project names;
- no service, domain or repository names, other than the public
  repository the issue is filed against;
- no ticket ids, and no internal PR or issue numbers;
- no verbatim excerpts from internal documents or private code.

Describe the fault abstractly. Keep only what a maintainer needs to
reproduce or judge it: the rule ID, the verdict, the grammatical or
structural shape of the text that triggered (or missed) the rule, and
the proposed fix direction. Where the issue needs an example sentence,
write a new one with neutral subjects (for example "the service
returns a list of orders") that shows the same shape. Do not quote the
original, and do not lightly edit it.

This applies to text from any source in the current session, not only
the log entry: the session that runs this command can hold private
context of its own.

## Step 1: Read the log

```
cat ~/.claude/swe/feedback.jsonl 2>/dev/null
```

If the file does not exist, or every line was already archived (see
Step 4), say so and stop. Nothing to review is a normal outcome, not an
error.

Parse each line as one JSON object of type `finding_feedback`: a
person's verdict on one lint finding.

## Step 2: Group the finding feedback

`rule_id` is either a real rule (an id found in
`swe/rules/plugin-rules.toml` or `swe/data/core-rules.toml`), the
string `"unknown"` (a `false-negative` with no named rule), or `null`
(a `feature-request`, never tied to any rule). Only a real `rule_id` is
safe to cluster by: `"unknown"` and `null` are placeholders shared by
unrelated entries, not evidence they describe the same thing (two
`"unknown"` entries about two different problems must not look like
one pattern just because they share the placeholder).

- **Real `rule_id`:** group entries by `(rule_id, verdict)`. Two or
  more sharing both is a candidate cluster, carried into Step 3
  together. A singleton also goes to Step 3, on its own: one clear,
  well-formed entry is reason enough to raise it, not just a cluster.
- **`rule_id: "unknown"` or `null`:** every entry goes to Step 3
  individually, regardless of how many share the placeholder. If, when
  you get to one in Step 3, its `quote`/`note` reads as an obvious
  duplicate of one just discussed, say so and offer to fold them into
  one discussion instead of raising both. Do not group them
  automatically going in, only on this explicit, case-by-case call.

For a real-`rule_id` cluster, use the entries' own `quote` and `note`
fields to judge whether it looks like a real, fixable issue (a genuine
gap or false-positive shape), rather than a one-off misunderstanding.
This needs judgement: two "false-positive" reports on the same rule
that flag unrelated kinds of text are not the same pattern, even though
they share a `rule_id`.

## Step 3: Discuss one item at a time

For each candidate from Step 2, cluster or singleton, in turn:

1. State it: the rule ID (or "no rule" for a `null`/`unknown`
   `rule_id`), the verdict, how many entries, and one or two
   representative quotes (or, when there is no `quote`, as with a
   `feature-request`, the note instead).
2. State a proposed fix direction (e.g. "check the subject before this
   rule fires", "add an exemption for X", "narrow the trigger phrase",
   or, for a `feature-request`, what the ask itself would look like
   built).
3. Ask whether to take it forward to a draft issue. This is not
   approval to publish: Step 4 shows the draft for approval before
   anything is filed.
4. Wait for the answer before moving to the next item. Do not list
   every item up front. This project's own convention is one point at
   a time.

## Step 4: File a confirmed issue, and archive its entries

When the user confirms an item:

1. Decide the target repository:
   - If `rule_id` appears in
     `swe/rules/plugin-rules.toml`, the target is
     `jimbarritt/claude-plugins`.
   - Otherwise, if it appears in
     `swe/data/core-rules.toml` (or the working tree
     at `~/Code/github/jimbarritt/software-english/rules/core-rules.toml`),
     the target is `jimbarritt/software-english`.
   - If `rule_id` is `unknown`, `null`, or not found in either file,
     ask the user which repository to use. A `feature-request` about
     the plugin's own tooling (a skill, a hook, the feedback loop) is
     almost always `jimbarritt/claude-plugins`; ask only when genuinely
     unclear.
2. Draft a short issue title and body under the rule in "The issue
   tracker is public; the feedback log is not" above. Use the rule ID
   if any, the verdict, an abstract description of the text's shape, a
   neutral rewritten example where one is needed, and the proposed fix
   direction. Do not copy `quote` or `note` text into the draft. Do not
   add any AI-assistance attribution.
3. Show the user the exact title and body, and the target repository,
   that will be filed. Wait for approval. If the user asks for
   changes, revise the draft, apply the redaction rule again, and show
   the draft again. Run `gh issue create` only after the user approves
   this text. The Step 3 answer approved the item, not the text. If the
   user declines at this point, treat the item as declined: leave its
   entries in the live log, and do not archive them.
4. Ensure the `auto-fix-candidate` label exists on the target repo:
   `gh label create auto-fix-candidate --repo <owner/repo> --color
   ededed --description "Candidate for the supervised fix harness" 2>/dev/null`
   (a separate, supervised fix harness elsewhere reads issues by this
   label; ignore a "label already exists" error).
   Never apply it to a `feature-request`: that verdict exists
   specifically for something other than a concrete, scoped rule bug,
   so it is never a fix-harness candidate, no need to ask each time.
   For any other verdict, ask the user before applying the label if the
   issue reads as a design question rather than a concrete, scoped rule
   bug.
5. Run `gh issue create --repo <owner/repo> --title "..." --body "..."
   --label auto-fix-candidate` (omit `--label` per item 4 above), with
   the title and body exactly as approved in item 3.
   A session scoped to a different repository fails this call with
   `Access denied: repository "..." is not configured for this
   session.` That is the session harness, not a real permissions
   problem: add the target repo to the session's scope (`add_repo`),
   then retry the same command.
6. Move every log line belonging to this item's entries into an
   archive file: `~/.claude/swe/feedback-archive/{today's date, YYYY-MM-DD}.jsonl`. Rewrite the current log with those
   lines removed. Use a small Python script for this: read all lines,
   split into "belongs to this item" and "everything else," append
   the first group to the archive file, and overwrite the current log
   with the second group.

When the user declines an item, leave its entries in the live log. Do
not archive a dismissed item, in case more evidence changes the call
later.

## Step 5: Summarise

After every item is discussed, state in one or two lines: how many
issues were filed, and how many items were declined and left in the
log. Every entry is raised in some item during a single run (a
cluster, a singleton, or, for a placeholder `rule_id`, individually),
so nothing is left over purely for lack of a sibling.
