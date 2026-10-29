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

Argument given: $ARGUMENTS

This is one file path, relative to the current project unless given as
absolute. If it is blank, ask which file to check.

## Step 2: Fetch the rule data

```
"${CLAUDE_PLUGIN_ROOT}/scripts/fetch-software-english-data.sh"
```

If this fails and prints "no cached data available", report that and
stop: there is nothing to check against.

## Step 3: Run the deterministic tier and get the inference rules

```
out="$(mktemp "${TMPDIR:-/tmp}/swe-lint.XXXXXX")"; python3 "${CLAUDE_PLUGIN_ROOT}/scripts/software_english_lint.py" <file-path> --force-inference --quiet-vocab > "$out" 2>&1; echo "swe-lint output: $out"
```

This writes the full output to a new file outside the working tree,
with a name unique to this run, and prints that file's path after
`swe-lint output:`. Do not write this output, or a copy of it, inside
the repository: an untracked file there shows in `git status`, and a
later `git add -A` stages it (claude-plugins#29). Do not use a fixed
file name: two runs on different files at the same time then write to
the same file, and one overwrites the other. Read the named file with
the `Read` tool, in full, in parts if it is long; everything below
describes that file's content. The file stays outside the repository
after this command; do not delete it.

The file contains the deterministic tier's findings, if any, the normal
way, plus a `swe: rule data <tag>, fetched <age>` line, joined in by
the command's `2>&1`. If a `swe: stale rule data: ...` line follows
it, Step 2's fetch did not update the cache (claude-plugins#28):
report this to the user along with the results, rather than treating
the findings above as current.
`--force-inference` additionally writes a fenced
`===INFERENCE_ADVISED===`...`===END_INFERENCE_ADVISED===` block: one
line per inference-based rule that applies here, each shaped like a
finding so it survives a findings-shaped filter, `<file>:0: [warning]
[rule-id] inference pending: description` (a rule whose own catalogue
severity is not `warning` adds `(severity on violation: <severity>)`),
A rule's own line can be followed by one or more `<file>:0: [warning]
[rule-id] candidate at line N: description` lines: a located structural
signal for that rule (a verbless sentence right after a long one, a run
of bold-lead-in bullet lists, a definite phrase whose head noun's lemma
has not occurred earlier in the document, a recurring undefined term, a
count that does not match its own list, and similar), never a decision
that the fault is real. Treat a candidate as a place to check first, not
a substitute for judging the whole file in Step 4.

After every rule's own lines, the block writes the file's prose as a
numbered worklist: one `<file>:0: [warning] [inference-unit] N prose
unit(s) follow; judge each one against every rule above.` line, then
one `<file>:0: [warning] [inference-unit] unit N of M, <kind>,
line(s) <range>: <text>` line per unit (`<kind>` is `heading`,
`paragraph`, `list-item`, or `table`). `<text>` renders a link as
`text (link: target)` and keeps a code span verbatim, not the
deterministic tier's blanked placeholder. This is the same worklist
Step 4 walks and Step 5's `--units-judged` checks coverage against: a heading
or a paragraph outside a fenced code block, a top-level list item
(a nested bullet or a wrapped continuation line folds into its parent
item, not a separate unit), or a table. The block ends with one
summary line, `<file>:0: [warning] [inference-pending] N inference
rule(s) above need model judgement; this script does not judge them.
Deterministic tier: E error(s), W warning(s).`, with a trailing `K
located candidate(s) above are not findings.` when any candidate
printed, and a trailing `M prose unit(s) listed above; record with
--units-judged M.` when the worklist printed. The script never judges
the file against any of this itself: it has no model access and never
spawns one. It records this pass in
`~/.claude/swe/inference-state.json`, so a hook-advised subagent's pass
on the same file counts too, for the throttle `--advise-inference`
applies.

Do not filter or truncate the file's content when reading it (no
`head`, `sed`, `tail`, or `grep`): this is why the command above
writes to a file instead of printing directly, since the output is
too large to filter safely. Step 4 must judge against the rules and
the worklist written here, in full, not a list recalled from earlier
in the conversation. A findings-shaped grep now keeps the rule,
worklist, and summary lines (they are line-0, `[warning]` lines like
any other), but still drops the `swe-lint-units` and `swe-lint-nonce`
lines Step 5 needs, so filtering still loses something.

The last two lines of the file are `swe-lint-units: <total>` then
`swe-lint-nonce: <value>`. Step 5 needs both values. They are valid
for this file's exact current content only, and only once. If instead
the last line reads `swe: no lint nonce issued for <file>: <reason>`,
the file needs no ledger row (it is outside a git repository, or
matched by `.swe-ignore`); do Step 4 and skip Step 5.

If the file has no prose to check (e.g. empty, or a code file with no
comments), no `===INFERENCE_ADVISED===` block is written, so the
worklist total is 0; skip Step 4. The units and nonce lines still
appear in this case, since a no-prose file still needs a `clean` row
recorded in Step 5, with `--units-judged 0`.

## Step 4: Judge the file against the inference rules yourself

Step 4 has three passes, in this order: the body, the headings, then
the whole document. Passes 1 and 2 use the same rules: the `inference
pending` lines from Step 3. Pass 3 uses the checks given under it,
below.

A judgement made earlier, in this session or any other, never applies
to changed content. Even a one-token edit makes this a new file. Judge
the content as it is now, in full, every time. The ledger is keyed by
content for exactly this reason, and Step 5's nonce enforces it: a
nonce issued before an edit no longer matches the file's blob, so
Step 5 rejects it.

### Pass 1: the body

Read `<file-path>` (the `Read` tool). Using each `inference pending`
line from Step 3, one rule per line, its id in brackets, its
description after `inference pending:`, judge the file's own prose
against each rule directly, as part of your own reasoning. Where a
rule has one or more `candidate at line N` lines under it, check that
line first, but still judge the whole file against the rule: a
candidate is a starting set, not a complete one. Ignore the trailing
`[inference-pending]` summary line; it is a count, not a rule.
There is no separate call to make or process to wait on for this step.
Note any violation as `<file-path>:<line>: [severity] [rule-id]
detail`, matching the deterministic tier's own format. Severity is
`warning` unless the rule's line ends `(severity on violation:
<severity>)`, in which case use that.

### Pass 2: the headings, as a list

After Pass 1, make a list of every heading in the file, in document
order, each with its line number. A heading is a line that starts with
one to six `#` characters and a space, outside a fenced code block.
Make the list from the content you read in Pass 1, or read it directly
off Step 3's worklist: every `heading` unit there is one heading, in
the same order.

Judge each heading in the list as a sentence, against each
`inference pending` rule from Step 3. A heading is prose: a metaphor or
a contrastive frame in a heading is the same fault as in a paragraph.
Note each violation at the heading's own line number, in the same
format as Pass 1.

Do Pass 2 even when Pass 1 found violations: Step 6 reports every
finding from all three passes. Skip Pass 2 for a file that is not
Markdown, and for a Markdown file with no heading.

### Pass 3: the whole document

After Pass 2, read the file once more as a whole, start to end. Some
faults span more than one unit: a heading, a paragraph, or a list
item. No per-unit pass detects them. Report each Pass 3 finding at
`warning` severity, in the same `<file-path>:<line>: [severity]
[rule-id] detail` format as Pass 1, at the line given for each check
below. Do Pass 3 even when Passes 1 and 2 found violations. Skip
Pass 3 for a file that is not Markdown, and for a Markdown file with
fewer than two headings.

Check the whole document against each of the following:

- **`[no-contradiction-between-sections]`.** A later section (a
  decision record, a discussion point, an amendment) states a rule
  that an earlier section contradicts, or a status marker on a later
  entry states that a decision is agreed but not yet applied to the
  body ("agreed, not yet reflected above/below"). Report two findings:
  the earlier, contradicted sentence, and the status marker itself.
  Example: §3 states "every queue has at least one consumer, so the
  router never checks for an empty queue"; §9, decision Q-4, states
  "status: agreed, not yet reflected above. A queue can have zero
  consumers; the router checks before it sends." Report §3's sentence
  as contradicted by Q-4, and Q-4's status marker as stale. Not this
  fault: a later section that states an exception to the earlier rule
  and names it as an exception; an open question that states no
  decision.
- **`[summary-before-detail]` (SPEC §7.1).** A Design or API Design
  document of 300 lines or more with no Summary section and no opening
  paragraph, before the first section heading, giving the document's
  own decision or description. Report at line 1.
- **`[no-mechanical-repetition]`, across sections (SPEC §8.2).** One
  argument or consequence, not only a measurement, restated in more
  than one section in different words, for example the reason a type
  excludes a category of records, given three or four times. Report
  each restatement after the first, at its own line. Not this fault:
  the one restatement a summary is allowed (SPEC §7.1); a
  cross-reference ("for the reason in §3") that states the argument
  only once.
- **Contents list, two rules.** `[no-mechanical-repetition]`: a
  contents list out of scale with the document (SPEC §8.2's own
  threshold: under about 300 lines, none; longer, top-level headings
  only, with a subsection listed only where a reader looks it up by
  number). `[no-unanchored-reference]`: a contents entry, or a bold
  group label inside a contents list, that matches no heading in the
  document: a reference with no referent (SPEC §7.5), not repetition.
  Report one finding per unmatched entry, at that entry's line.
- **`[no-precedent-before-subject]`.** A section whose heading names
  one subject describes a different component, system, or precedent
  first, at more than one paragraph or list, before it states the
  subject's own facts. Fix: state the subject's own facts first; move
  or cut the precedent.

A Pass 3 finding never changes Step 5's error count, and Pass 3 judges
no worklist unit, so `--units-judged` is the same with or without it.
Three of these rule ids are lint-file's own, not from the fetched
`software-english` catalogue: `no-contradiction-between-sections`,
`summary-before-detail`, and `no-precedent-before-subject`.
`no-mechanical-repetition` and `no-unanchored-reference` are
catalogued; Pass 3 applies each past the one-unit scope its catalogue
description covers on its own.

## Step 5: Record the verdict

The commit check (`/swe:install-commit-hook`) reads a repository-local
ledger of judged files, separate from `~/.claude/swe/inference-state.json`
(that file only throttles the automatic hooks' advisories). Record this
pass there, so a commit staging this file is not blocked for content
already checked here.

Count the `error`-severity findings: the deterministic tier's own count
from Step 3, plus any you found judging the inference rules in Step 4
(0 if Step 4 was skipped for lack of prose; Pass 3 adds only warnings,
so it never changes this count). Warnings do not count.

Also count the units from Step 3's worklist judged in Step 4. Walking
the whole worklist (Passes 1 and 2; Pass 3 judges no worklist unit) is
the normal case; state that count honestly, never the total by
default. `M` below is the total Step 3 printed as `swe-lint-units`.

Every unit judged (the normal case), zero errors:

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/software_english_lint.py" \
  --record-lint-result clean --findings 0 --nonce <value from Step 3> \
  --units-judged <M> <file-path>
```

Every unit judged, one or more errors:

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/software_english_lint.py" \
  --record-lint-result failed --findings <count> --nonce <value from Step 3> \
  --units-judged <M> <file-path>
```

Only some units judged (for example, the output file was only read in
part and Step 3 had to be re-run on part of the file): pass
`--units-judged "<N> of <M>"`, quoted. This records as a `partial`
row, which blocks a commit the same way `failed` does, whatever the
verdict given, since a partial pass is not proof the file is clean.

The row is keyed to the file's exact content at this moment, via its
git blob id. Any later edit invalidates it, so run this after judging,
not before, and re-run `/swe:lint-file` after a fix.

Exit 0 means recorded (including a one-line note when the file is
outside a git repository, which needs no further action). Exit 2 means
the command itself was malformed (for example, `<N>` above `<M>`); fix
the arguments and run it again. Exit 3 means the ledger could not be
written: report that line as-is, because a commit staging this file
will then be blocked with no other explanation. Exit 4 means the
nonce or the units claim was rejected: no `--nonce`, an unknown or
already-used nonce, a nonce issued for another file, the file changed
after Step 3, no `--units-judged`, a nonce that predates this flag
(re-run Step 3), or a `--units-judged` value that does not match the
total Step 3 printed for this exact blob. Do not retry with another value: go back to
Step 3 and run Steps 3, 4, and 5 again on the file as it is now.

## Step 6: Report

Print every finding, deterministic and inference-tier alike, one line
each with severity. This is the violations found in Step 4, all three
passes, not the `inference pending` lines, the `candidate at line N`
lines, the worklist's `inference-unit` lines, or the
`[inference-pending]` summary line from Step 3, which name rules and
places to check, not findings. If there are none, say the file is
clean, both tiers. When Step 5 recorded a `partial` row, say so and
name the coverage (`N of M units judged`): the file is not recorded
clean, whatever Step 4 found, until a later pass judges the rest. Do
not fix anything unless asked: this command is a check, not an edit.
