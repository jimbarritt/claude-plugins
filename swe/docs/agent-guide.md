# Agent guide: swe

This file is for an agent (a Claude Code session) running inside a
project with this plugin installed. It is not for a human — see
[`../README.md`](../README.md) for that. This file is exempt from
Software English's own enforcement, listed in
[`../../.swe-ignore`](../../.swe-ignore): it is technical reference for
an LLM reader, not the human-facing prose the spec governs.

## What to do when a hook blocks you

A blocking `PreToolUse` hook (`bash-check.sh`, `artifact-check.sh`,
`mcp-send-check.sh`) denies the tool call and returns a reason: a rule
name, the flagged text, and a suggested fix, one line per finding, plus
the path to the full report under `~/.claude/swe/reports/`. Read it,
fix the flagged text as described, then retry the tool call.

If you believe a finding is wrong — a false positive, a false negative,
or a correct finding with a bad suggested fix — do not just work around
it. Run
`/swe:feedback <false-positive|false-negative|wrong-fix|feature-request> [note]`
so the pattern gets tracked, then proceed with your own best correction.
The fourth verdict, `feature-request`, is for feedback about the
tooling itself (a skill, a hook, the feedback loop), not tied to one
specific finding — see
[`../skills/feedback/SKILL.md`](../skills/feedback/SKILL.md).

No hook checks a file write or a chat reply automatically. Run
`/swe:lint-file <file-path>` yourself when you want a file checked; see
"When the inference tier runs" below for how that command works.

## Hooks

| Hook | Event | Covers | Config key |
|---|---|---|---|
| [`../hooks/bash-check.sh`](../hooks/bash-check.sh) | `PreToolUse` on `Bash` | A `git commit` message or a `gh pr`/`gh issue` title or body | `hooks.bash` |
| [`../hooks/artifact-check.sh`](../hooks/artifact-check.sh) | `PreToolUse` on `Artifact` | A file about to publish: markdown directly, HTML via text-node extraction | `hooks.artifact` |
| [`../hooks/mcp-send-check.sh`](../hooks/mcp-send-check.sh) | `PreToolUse` on the `Slack`/`Gmail`/`Drive` send tools | An outbound message body | `hooks["mcp-send"]` (hyphenated key, so a jq path needs bracket syntax) |

A `Stop` hook (checking the chat reply and changed tracked markdown)
and a `PostToolUse` hook on `Write`/`Edit` (checking a file as it was
written) both existed here previously and were removed: reviewed and
found to be doing very little once the output style existed to shape a
reply directly, at a fixed ~2-second cost on every single turn
regardless of whether anything needed checking (claude-plugins#6). See
`STATE.md` on the `planning` branch for the fuller record.

Each config key resolves via `hook_enabled()` in
[`../hooks/_lib.sh`](../hooks/_lib.sh): the project's own
`.claude/swe-lint.json`, if it sets that key, else the plugin's own
[`../config.json`](../config.json), else `true` (fail open). See the
[README](../README.md#turn-off-a-check-for-one-project) for the
project-level file's format.

All three call
[`../scripts/software_english_lint.py`](../scripts/software_english_lint.py)
after
[`../scripts/fetch-software-english-data.sh`](../scripts/fetch-software-english-data.sh).

## Output style

[`../output-styles/software-english.md`](../output-styles/software-english.md)
carries `keep-coding-instructions: true`. It is a normal installed
output style: a user selects it themselves (`/output-style`), the same
as any other. Nothing forces it on when the plugin is enabled;
`force-for-plugin: true` was removed once the `Stop` hook it justified
went too (see "Hooks" above). Once selected, Claude Code sends its
instructions with every request for the session, the same way it sends
the system prompt, whether the output being written is a chat reply or
a file.

The output style is exempt from this plugin's own checks, listed in
[`../../.swe-ignore`](../../.swe-ignore), for the same reason as this
file: it cites banned words and patterns as examples, which the linter
cannot tell apart from a live violation.

What this does not close, whether or not the style is selected:

- A subagent (the `Agent` tool) runs its own system prompt and does not
  inherit the parent conversation's output style. Its written output is
  covered by `bash-check.sh`, `artifact-check.sh`, and
  `mcp-send-check.sh` when it writes a commit, an artifact, or a
  message; nothing covers a subagent's own reply text or a file it
  writes.
- The output style is a system-prompt instruction, not a check, even
  when selected. A rule the model still gets wrong ships as written;
  nothing downstream catches it automatically for a reply or a file
  edit. `/swe:lint-file` is the deliberate, on-demand way to check a
  file, e.g. before a commit — nothing wires it up automatically.

## Rule tiers

**Deterministic.** Checkable by lookup or pattern alone. Runs on every
source, every time:

- Closed vocabulary: [`../data/operations.tsv`](../data/operations.tsv), [`structure.tsv`](../data/structure.tsv), [`qualities.tsv`](../data/qualities.tsv), [`connectives.tsv`](../data/connectives.tsv)
- Banned-word substitutions: [`../data/banned.tsv`](../data/banned.tsv)
- No em dash
- Continuous tense used for system behaviour
- A fixed anthropomorphism word list
- A fixed abstract-location word list (`sits`, `lives`, and similar, standing in for `is`/`belongs to` when the subject is abstract)

**Inference-based.** Needs model judgement. Runs conditionally, per
"When the inference tier runs" below: every rule in
[`../data/core-rules.toml`](../data/core-rules.toml) with
`check = "model-judgement"`.

**Plugin-owned.** [`../rules/plugin-rules.toml`](../rules/plugin-rules.toml)
contains one rule, `one-point-at-a-time`: a reply with more than one point
needing a decision states the count, then gives only the first point.
This governs reply structure, not prose wording, so it stays out of the
Software English spec. It runs only on a conversational source (a chat
reply or a transcript), never on a file, a commit message, or an
artifact.

## When the inference tier runs

This script has no model access of its own, and never spawns one. Every
invocation of it already runs inside a skill or a hook-dispatched
subagent, which already has a model attached; the script's only job for
the inference tier is to decide whether a fresh pass is worth doing,
and if so, hand over the applicable rules for the caller to judge the
prose against directly, as itself, with its own context. Nothing here
ever shells out to `claude -p` or any other subprocess for the judging
step.

`--advise-inference` (used by the three `PreToolUse` hooks: `bash`,
`artifact`, `mcp-send`) decides only:
gated by `inference_eligible()` below, plus the deterministic tier
being clean this same invocation, plus `stop_hook_active` being false
(`Stop` only; the other hooks have no equivalent flag). When eligible,
it prints a fenced block:

```
===INFERENCE_ADVISED===
doc.md:0: [warning] [anthropomorphism-paraphrase] inference pending: A paraphrase of anthropomorphic language ...
doc.md:0: [warning] [no-metaphor-or-analogy] inference pending: State a fact or a mechanism directly ...
doc.md:0: [warning] [no-cadence-device] inference pending: A cadence device is a sentence written for rhythm ...
doc.md:0: [warning] [no-cadence-device] candidate at line 42: verbless sentence "No silent drops." follows a 19-word sentence; judge whether it states a fact that sentence does not.
doc.md:0: [warning] [inference-pending] 3 inference rule(s) above need model judgement; this script does not judge them. Deterministic tier: 0 error(s), 0 warning(s). 1 located candidate(s) above are not findings.
===END_INFERENCE_ADVISED===
```

`--force-inference` (below) adds a further block, after every rule's
own lines and before the `[inference-pending]` summary, for a single
named file inside a git repository: the file's prose as a numbered
worklist, so a `clean` recording can later be checked for coverage
(claude-plugins#20; see "Proof that Step 3 ran"):

```
doc.md:0: [warning] [inference-unit] 2 prose unit(s) follow; judge each one against every rule above.
doc.md:0: [warning] [inference-unit] unit 1 of 2, heading, line 1: # Title
doc.md:0: [warning] [inference-unit] unit 2 of 2, paragraph, lines 3-4: A paragraph that wraps over two lines.
```

A unit's text (claude-plugins#27) renders a Markdown link as
`text (link: target)` and keeps a code span verbatim, not the
deterministic tier's blanked, same-length placeholder. A model judges
the worklist, and a blanked link or code span reads as an unresolved
reference or a missing object.

Each rule line is shaped like a deterministic finding (`label:line:
[severity] [rule-id] detail`), deliberately: a caller filtering output
for finding lines (a `grep -E ":\s*\[(error|warning)\]"`, the natural
thing to do on a long file) used to drop this whole block silently, so
a filtered `--force-inference` run read as a clean two-tier pass when
the inference tier had never run at all (claude-plugins#14). Line
number is always `0` (never used by a real finding, since `prose_lines()`
counts from 1) and severity is always `warning` (a pending rule is not
itself a violation), whatever the catalogue's own severity for that
rule is; where that differs, the line ends `(severity on violation:
<severity>)` so the judging step still has it. `[inference-pending]` is
a reserved id, in neither catalogue, marking the one summary line,
which restates the source's real deterministic counts so a caller
counting `[warning]` lines is not misled by the added rule lines.

Directly after a rule's own `inference pending` line,
`find_register_candidates()` (claude-plugins#18, #19, software-english#21)
can add one or more `candidate at line N: ...` lines for that same rule: a
located structural signal, never a decision that the fault is real. Six
rules get this today. `no-cadence-device`: a verbless sentence right after a
sentence of 15 or more words, in the same paragraph (a fragment that is
its own paragraph is not detected, since nothing in the line structure
then tells it apart from a caption or a label); and two adjacent
sentences, 4-12 words each, with an identical sequence of word classes
(determiner/verb/noun/quality/other, from the vocabulary data) and at
least one verb between them. `no-mechanical-repetition`: a run of three
or more markdown lists, not broken by a non-qualifying list (a
paragraph or heading between qualifying lists does not break the run),
where every list has at least two top-level bullets and every bullet
opens with a bold span followed by real text. A single such list does
not fire, since several of this repo's own templates use one
deliberately for a defined term or a named set of required sections,
exactly the catalogue's own exclusion. `no-unanchored-reference` and
`no-unstated-presupposition`: `find_definite_first_mentions()` walks the
document once, title and headings included, and flags a definite noun
phrase ("the"/"these"/"those"/"both the" plus an optional cardinal, up to
two adjective-shaped modifiers, then a head noun) whose head noun's lemma
has not occurred earlier in the document. A cardinal inside the phrase
("the two queues", "both the options") routes the candidate to
`no-unstated-presupposition` instead, since that rule's own trigger is a
cardinal or a completed-act participle, not only an earlier noun.
`define-before-use`: `find_undefined_terms()` groups the document's words
by lemma and flags a group that occurs three or more times, with at least
one occurrence in a heading, preceded somewhere by a determiner or
cardinal (confirming a noun use), outside the approved vocabulary/verb
lexicon/single-word banned phrases, and never followed by a definition
clause (a bold span, "X means"/"refers to"/"is defined as", "called X",
"a X is a", a parenthetical gloss, or a glossary bullet/table row).
`no-count-list-mismatch`: a number word (two to twelve, no numerals, no
"one", no "both") immediately before a short lowercase noun phrase and a
colon, in the same sentence, whose following list's item count
(`count_list_items()`: comma-split outside parentheses/quotes, then an
and/or split of the lone remaining part, or of the last part when it has
no leading Oxford and/or) differs from the stated number. Each detector reads a closed, stdlib-only verb/auxiliary list
(`load_verb_lexicon()`), not real part-of-speech tagging, so a verb
outside that list can still produce an extra candidate, and a word
`vocabulary/operations.tsv` also uses as a noun can still miss one.
`no-cadence-device`'s own fragment check (`find_cadence_fragments()`,
`sentence_has_verb()`) narrows this in two ways (claude-plugins#25): a
code span counts as one noun-phrase token, not blank space, so it no
longer disappears from the subject or the length cap; and a word
directly before an object pronoun ("them", "it", "these", and similar,
with a subject token before it) counts as a finite verb even when it is
outside the closed lexicon. The closed-list gap itself remains; see
"Known limits" below. Candidates are capped at 20 per rule per source (a
further line names the count omitted past the cap) and, like a pending
rule, never affect `error_total`, `--count`, or the exit code. The
judging step still reads the whole source: a candidate names one place
to check first, not every instance of the fault. `--html-file` gets no
candidates, since adjacent extracted text nodes are not adjacent prose
lines.

Splitting a pending rule, a candidate, a worklist unit, the summary,
and a real finding apart, by regex:

- pending rule: `^.+:0: \[warning\] \[[a-z0-9-]+\] inference pending: `
- candidate: `^.+:0: \[warning\] \[[a-z0-9-]+\] candidate at line [0-9]+: `
- worklist unit: `^.+:0: \[warning\] \[inference-unit\] `
- summary: `\[inference-pending\]`
- real finding: any finding-shaped line with a line number of 1 or more

The hook script (`strip_advise_block()`/`extract_advise_rules()` and
`advise_inference()` in [`../hooks/_lib.sh`](../hooks/_lib.sh)) splits
that block out of the deterministic-tier report and, only when the
deterministic tier itself found nothing to block, returns a
non-blocking advisory hook response: the tool call proceeds, and Claude
is told to dispatch a subagent to read the source (a file path for
`artifact-check.sh`, or the text itself for `bash-check.sh`/
`mcp-send-check.sh`, inlined directly into the advisory message since
there is no file to read) and judge it against those rules, as part of
its own reasoning, then fix anything it finds. No step in that path
re-invokes this script.

A pass is worth advising when:

1. The deterministic tier found no violation in this same invocation.
2. `stop_hook_active` is false.
3. The prose, after code and quote stripping, is eligible per
   `inference_eligible()` in
   [`../scripts/software_english_lint.py`](../scripts/software_english_lint.py):
   - **A single named file** (the only source with a stable identity
     across repeated edits): eligible once its word or sentence count
     has grown by another
     [`../config.json`](../config.json) `threshold_words` (60) /
     `threshold_sentences` (4) since the file's last recorded pass
     (either flag, whichever last printed the block for it), recorded
     in `~/.claude/swe/inference-state.json`, keyed by the file's
     resolved path. A file with no recorded pass yet uses the same
     numbers as a plain absolute threshold (its first pass). This is
     what throttles a file already carrying, say, 20 known inference
     findings: most follow-up edits are fixes to those, not new prose,
     so they do not re-cross the threshold and do not get advised again
     until the file has genuinely grown.
   - **Any other source** (piped text, an HTML file): no stable
     identity across calls, so it always uses the plain absolute
     threshold, exactly as before.

`--force-inference` (used by `/swe:lint-file`) prints the same block
unconditionally: no gate, no threshold, no throttle. It still skips on
empty prose, and still records the pass (word/sentence count, for the
throttle above) whenever it prints the block. It is the current session
itself, right where `/swe:lint-file` was run, that then judges the file
directly; no subagent is dispatched for that command. That judgement
has three passes (Step 4 of
[`../skills/lint-file/SKILL.md`](../skills/lint-file/SKILL.md)): the
body, then the file's headings as a separate list, against the same
rules, then the whole document once more for a fault that spans more
than one unit (a contradiction between sections, a missing summary, an
argument restated across sections, a contents-list fault, a section
that states a precedent before its own subject). For the heading pass,
the agent builds the heading list itself, from the same `Read` output
the body pass already used, or reads it straight off the printed
worklist's `heading` units. The deterministic tier already
checks each heading line too, because `prose_lines()` yields a `#`
line like any other prose line. For a single named file inside a git
repository, it also prints the worklist, a `swe-lint-units: M` total,
and a single-use nonce bound to the file's exact git blob id, whether
or not the rules block printed — see "Proof that Step 3 ran" below.

Neither `--advise-inference` nor `--force-inference` can be combined
with `--count`: `--count` returns its one-line summary before the
inference block would print and before a nonce would mint, so the
combination would always report "0 errors, 0 warnings" and exit 0
regardless of prose content, the same failure claude-plugins#14
describes, just reached a different way. The combination exits 2
rather than being silently accepted.

The exit code still reflects the deterministic tier only, on both
flags: a pending inference rule is never itself a finding, and a shell
pipeline like the one in claude-plugins#14 reports the last command's
(here, `grep`'s) exit status regardless, so a distinct "block printed,
not yet judged" exit code would not reach the caller the issue
describes. The finding-shaped rule lines are the fix for that case, not
the exit code.

The hooks strip the whole fenced block (`strip_advise_block()`) before
they count `[error]`/`[warning]` lines for
`report_and_maybe_block()`, so the added rule and summary lines never
change a hook's own error/warning counts or its blocking decision.

## The commit check

`/swe:install-commit-hook` installs a git `pre-commit` hook
([`../git-hooks/pre-commit.sh`](../git-hooks/pre-commit.sh), copied
verbatim as `pre-commit` by
[`../scripts/install-commit-hook.sh`](../scripts/install-commit-hook.sh))
in one repository's `.git/hooks/` (or wherever `core.hooksPath` points).
It runs outside any Claude Code session — no model, no plugin runtime —
so it can only run the deterministic tier itself and check a ledger; it
never judges the inference tier.

**The ledger.** `<git-common-dir>/swe/lint-log.ndjson`
(`git rev-parse --git-common-dir`, so one ledger per repository, shared
by every linked worktree). Append-only NDJSON, one row per
`--record-lint-result` call: `ts`, `path` (repo-relative), `blob` (git's
own blob object id for the exact content judged, via `git hash-object`,
not a `sha256` of the working-tree file), `algo` (`sha1`/`sha256`),
`status` (`clean`/`failed`/`partial`), `tier` (`"both"`), `findings`,
`rules_tag`, `plugin_version`, `recorded_by`, `units_total`,
`units_judged` (the last two from claude-plugins#20; absent on a row
recorded before that change, see "Proof that Step 3 ran" next). A row
is a candidate for a staged file when `path` and `blob` both match
that file's exact staged git blob (not the working-tree copy, which
can differ from what a partial `git add -p` staged); among candidates
for the same `(path, blob)`, the last row in file order wins. `clean`
means zero `error`-severity findings across both tiers together, over
the whole worklist; `partial` means the same verdict over less than
the whole worklist. A warning never blocks anything here either,
matching every other check in this plugin, and the pre-commit hook
treats `partial` exactly like `failed`: anything but `clean` blocks.

**Recording a verdict.** Only `/swe:lint-file`'s own Step 5 does this
today, right after it judges a file's inference-tier findings itself
(see [`../skills/lint-file/SKILL.md`](../skills/lint-file/SKILL.md)):

```
python3 scripts/software_english_lint.py --record-lint-result {clean|failed} --findings N --nonce N --units-judged M <file-path>
```

A standalone mode: no rule catalogue read, no report printed, no other
flag honoured alongside it. Exit 0 means recorded (including a
one-line note for a file outside a git repository, which needs no
ledger); exit 2 means the call itself was malformed; exit 3 means the
ledger could not be written — reported, not silent, unlike
`save_inference_state()` above, because a lost row here becomes a
commit blocked with no visible cause; exit 4 means the nonce or the
units claim failed, covered in "Proof that Step 3 ran" next.

**Proof that Step 3 ran.** `--record-lint-result` used to trust its
caller completely: nothing stopped an agent recording `clean` on the
strength of an earlier session's judgement of different content
(claude-plugins#10). `--force-inference` now mints a single-use nonce
for a single named file inside a git repository and stores it in
`<git-common-dir>/swe/lint-nonces.json`, keyed by the nonce, with
the file's repo-relative path, its worktree toplevel, its blob id at
mint time, and the total units on its printed worklist (`units`;
claude-plugins#20). `--record-lint-result` requires that nonce back
(`--nonce`), for `clean` and `failed` alike, and checks it in order:
given at all, known in the store, issued for this same file, and
issued for this file's *current* blob. Any failure exits 4 with the
reason, consuming nothing.

It then requires a coverage claim back too (`--units-judged`): `N`, or
`"N of M"` for a declared partial. `N`, or `M` when given, must match
the nonce's own stored total exactly, or the call exits 4 the same
way — a wrong value proves the caller did not walk the real worklist
for this blob (stale output, a truncated read), so Step 3 has to run
again regardless; unlike the four nonce checks above, a units mismatch
*does* consume the nonce, closing a guess-and-retry loop against one
value. A nonce minted before claude-plugins#20 shipped has no stored
total; that also exits 4, naming the pre-upgrade nonce, rather than
trusting an unmeasured claim. On success the entry is deleted before
the ledger row is appended, so the nonce is spent by its first use
regardless of whether that write succeeds; a write failure after that
still needs a fresh `--force-inference` pass, not a retry with the
same value. A `failed` verdict needs a nonce and a units claim for the
same reason a `clean` one does: without that, a `failed` recording
could be followed by a `clean` recording on the same nonce, letting
the second one through unjudged. A `clean` verdict with `N` below the
stored total records `partial` instead (claude-plugins#20's "declares
itself"); a `failed` verdict always records `failed`, whatever `N` is,
since a fault found in part of a file still fails it.

This proves that `--force-inference` ran on this exact content, that
its output reached the caller, and that the caller saw the worklist's
real total for this blob. It does not, and cannot, prove that the
caller judged every unit on that worklist against the rules the block
printed: that step happens inside the model, invisible to this script
by construction. A caller with direct shell access can still write the
ledger or the nonce store by hand. The design turns an accidental
shortcut — recording a verdict without running Step 4, or without
reading the whole worklist — into a deliberate forgery, which is the
realistic case this closes.

**Three state files, and why they are separate.**
`~/.claude/swe/inference-state.json` (above) is global, per-user, keyed
by resolved path, and answers "is a fresh advisory pass worth
dispatching" — a cost heuristic written before any judgement exists.
The ledger is per-repository, keyed by `(path, blob)`, and answers "was
this exact content judged, and what was the verdict" — written after
judgement. The nonce store is also per-repository, keyed by the nonce
itself, and answers "did `--force-inference` run on this exact
content, and has that pass already been claimed" — short-lived, since
an entry lasts only from one `--force-inference` pass to the
`--record-lint-result` call that consumes it, or until a later
`--force-inference` pass on the same file supersedes it. Merging the
first two would let a `failed` verdict in one clone suppress advisories
for the same path in every other clone sharing that global file, and
would force the throttle file to grow without bound. `/swe:lint-file`
writes to all three, at different steps; that is their only coupling.
The ledger row schema gained the `units_total`/`units_judged` fields
and the `partial` status (claude-plugins#20); the pre-commit hook is
unchanged by any of this, since it already blocks on anything but
`clean` — it still cannot tell how a row was written, and the guard
sits entirely at the only sanctioned writer, `--record-lint-result`
itself.

**Fail-open boundary.** The check fails open only when it cannot
evaluate the ledger at all: no `python3` on `PATH`, or the ledger file
present but unreadable. It fails closed on every answer it does
evaluate that is not `clean`, including an absent ledger file, which is
a fresh clone with nothing yet recorded: exactly the case this check
exists for. `git commit --no-verify` is the standing bypass; the block message
repeats it.

**A passing commit prints too** (claude-plugins#11): one line, naming
the number of staged markdown files verified and the clean verdict:
`swe: commit check passed. N staged markdown file(s) have a clean lint
record for their staged content.` It prints right before the hook's own
final `exit 0`, so it shows only once the commit proceeds (after the
ledger check and `block_on_deterministic`, not before). Every path
where nothing was checked (no staged files matching
`commit-check.paths`, `commit-check.enabled: false`, everything staged
matched by `.swe-ignore`) and every fail-open path (no `python3`, an
unreadable ledger) stays silent on this line, since neither confirms
the ledger clean.

**Deterministic tier at commit time.** Advisory by default: findings
print but do not block, run against each staged file's exact staged
content (`git show :<path>`, not the working tree). Set
`commit-check.block_on_deterministic: true` in the project's
`.claude/swe-lint.json` to make it blocking too.

**Project configuration**, read from `<repo>/.claude/swe-lint.json`
only, under `commit-check` — the plugin's own `config.json` has no
equivalent key, because the git hook cannot reach it:

```json
{ "commit-check": { "enabled": true, "block_on_deterministic": false, "paths": ["*.md"] } }
```

## The tsk documents check

Controlled by `docs_hook.enabled` in [`../config.json`](../config.json),
`false` today: `/swe:install-commit-hook`'s own Step 3 reads that field
first and, when it is `false`, skips Steps 3 through 5 with a one-line
note, running none of the commands this section describes. The scripts
and hook below are built and shipped regardless; the switch controls
only whether the skill offers and installs them. Set it to `true` to
turn this back on.

`/swe:install-commit-hook` also installs a second, independent hook
([`../tsk-hooks/pre-docs-commit.sh`](../tsk-hooks/pre-docs-commit.sh),
copied verbatim by
[`../scripts/install-docs-hook.sh`](../scripts/install-docs-hook.sh))
when [tsk](https://github.com/jimbarritt/tsk) 0.26.1 or later is
installed (claude-plugins#22). tsk's own documents worktree is a linked
git worktree of the code repository; before tsk 0.26.1, the commit
check above fired on tsk's own commits there too, since a linked
worktree shares `.git/hooks/`. tsk 0.26.1 runs its own git commands
with hooks disabled, and calls this hook directly instead, through its
own hook point (ADR 0025 in `jimbarritt/tsk`), so swe's documents check
has no dependency on the tsk binary at all: it is a plain script that
tsk happens to call.

**Why no ledger row.** `<git-common-dir>/swe/lint-log.ndjson` records a
both-tier, nonce-guarded verdict, read only by the commit check above.
Writing a row there for a ledger document risks a path collision with
a code-repository path of the same name (both share one
`git-common-dir`), and nothing would read it anyway: tsk's own git
commands run with hooks disabled, so the commit check never sees a
ledger document. The hook's exit status and printed output are its
whole answer; tsk shows both unchanged.

**Deterministic tier only, always.** Unlike the commit check above,
this is not configurable: the hook runs outside any Claude Code
session, with no model attached, and `tsk ledger push` must not wait
on one. `/swe:lint-file <path>` still runs both tiers, on demand, on
one document.

**Finding the plugin's linter at run time.** Lookup order: first
`$SWE_PLUGIN_ROOT` (manual override, and what the test suite sets),
then `<git-common-dir>/swe/plugin-root`, the same pointer file
[`../scripts/install-commit-hook.sh`](../scripts/install-commit-hook.sh)
already writes for the commit check above, read here via `git
rev-parse --git-common-dir` from inside the documents worktree, which
resolves to the *code* repository's own `.git` (a linked worktree
shares it). `install-docs-hook.sh` (re)writes that same pointer on
every successful `--place`, regardless of which of the three places
has the *hook script itself*: the pointer is per code-repository,
not per hook-script location, so a user- or clone-level hook script
shared across many repositories still resolves the right plugin
install for whichever repository's ledger is under lint, provided
`/swe:install-commit-hook` ran at least once from inside that
repository. With neither pointer present, the hook fails open with a
note naming the fix (re-run `/swe:install-commit-hook`). This also
means a swe update does not silently break the hook: the pointer is
stale only until that command runs again, the same contract the
commit check's own pointer already has.

**Fail-open boundary.** No `python3` on `PATH`, no linter found, no
rule catalogue cached (`data/core-rules.toml` missing; this hook never
runs the fetch script itself, matching the commit check's own
restraint, to keep a push from waiting on a network call), or any
linter exit code other than 0 or 1 (an uncaught Python exception exits
1, so it counts as a real failure, not a fail-open case: an accepted,
narrow edge rather than a special case to add). It blocks only on an
evaluated error-severity finding.

**The three install places**, matching what `tsk config docs-hook`
itself resolves, in the same precedence order (`TSK_DOCS_HOOK`, then
clone, then user, then repo):

- **user**: `${XDG_CONFIG_HOME:-$HOME/.config}/tsk/hooks/pre-docs-commit`.
- **clone**: a `hooks/` directory next to the ledger's own state
  directory: the `dirname` of `tsk ledger path`'s own printed path,
  which this task confirmed ends in `/repos/<clone-id>/ledger-db`,
  sibling to `hooks/`. Unavailable with no clone id yet (`tsk ledger
  fetch` mints one).
- **repo**: `.tsk/hooks/pre-docs-commit` at the repository's toplevel.

`install-docs-hook.sh --place` never chains a foreign file the way the
commit check's installer does for an existing `pre-commit`: the issue
this implements specifies stop, not chain, since a documents hook has
no established convention yet for what a foreign script there would
mean.

**Agents must not use `TSK_SKIP_DOC_CHECK`.** tsk itself reads this
environment variable and skips calling the hook entirely when it is
set; the hook script never reads it and never mentions it in its own
output, so only tsk's own documentation describes the bypass, not this
plugin. An agent working in a repository with this hook installed must
not set it to get past a blocked `tsk ledger push` or `tsk ledger doc
put`: fix the finding, the same discipline `git commit --no-verify`
already gets in this plugin's own skills.

## Where the rule data comes from

[`../software-english.json`](../software-english.json) pins a tag of
the [`software-english`](https://github.com/jimbarritt/software-english)
spec repository.
[`../scripts/fetch-software-english-data.sh`](../scripts/fetch-software-english-data.sh)
clones that tag with `git clone --depth 1 --branch <tag>` and copies
`vocabulary/*.tsv` and `rules/core-rules.toml` into [`../data/`](../data/)
on first run, then writes a marker file recording the fetched tag. A
later run compares the marker against the pin, and fetches again only
when they differ.

The fetch goes through `git clone`, not a raw HTTPS tarball download: a
cloud session's egress policy can deny a generic HTTPS download while
still serving git's own smart-HTTP protocol for a public repo clone,
through a separate, git-specific proxy lane. See claude-plugins#3.

[`../data/`](../data/) is gitignored — a local cache, not a vendored
copy in this repository.

If the fetch cannot connect to GitHub and no cache exists, the hook
prints a warning and does not block the turn. An existing cache from an
earlier fetch is used when a later fetch fails. This applies even if a
hook calls the linter without checking the fetch script's own exit code:
`load_rule_catalogue()` returns `(None, None)` when
`data/core-rules.toml` is still missing, and `main()` prints a skip
message and returns 0 rather than crash with an uncaught
`FileNotFoundError` (claude-plugins#3's second bug — the crash's
traceback, not a real finding, used to reach `report_and_maybe_block` as
a misleading "0 errors, 0 warnings" block).

Every linting run prints a `swe: rule data <tag>, fetched <age>` line to
stderr, naming the tag in `data/.fetched-tag` and its age (claude-plugins#28).
A tag's age alone is never a reason to warn: the fetch script pins an
exact tag and leaves an already-matching marker untouched, so an old but
matching marker still reports exactly correct data. A second stderr
line, `swe: stale rule data: ...`, prints instead when the marker holds a
tag other than the one pinned in `../software-english.json` — the case
where editing happened against a cache the pin has since moved past.

## Run the linter directly

```bash
python3 scripts/software_english_lint.py FILE.md
python3 scripts/software_english_lint.py --diff --added-only
python3 scripts/software_english_lint.py FILE.md --count
echo "some prose" | python3 scripts/software_english_lint.py --text --source-label reply
python3 scripts/software_english_lint.py --transcript /path/to/transcript.jsonl
python3 scripts/software_english_lint.py --html-file page.html
```

Add `--advise-inference` to print the `INFERENCE_ADVISED` rules block
when a fresh pass would be worth doing, gated as above. Add
`--force-inference` to print the same block unconditionally instead: this is what `/swe:lint-file` does, and, for a single named file inside
a git repository, it also prints the file's prose as a numbered
worklist and a `swe-lint-units: M` total (claude-plugins#20). Neither
flag ever judges the prose itself; that is always the caller's own
job. Add `--quiet-vocab` to omit `vocabulary-membership` lines; every
hook does this by default. Counting `[warning]` lines in either flag's
output includes the `inference pending` rule lines, any `candidate at
line N` lines under them, the worklist's `inference-unit` lines (only
for `--force-inference`), and the trailing `[inference-pending]`
summary line, not just real warning findings; the summary line's own
text states the source's real deterministic error/warning counts.
Neither flag can be combined with `--count` (exits 2).

Run `scripts/fetch-software-english-data.sh` once by hand first, if
`data/` is empty. Only the three PreToolUse hooks (bash, artifact,
mcp-send) run the fetch script before linting; the git commit hook, the
tsk documents hook, and a direct call do not, so a mismatch between the
cache and the pin shows there as the stale-rule-data line above instead.

```bash
python3 scripts/software_english_lint.py FILE.md --force-inference --quiet-vocab
# note the printed swe-lint-units and swe-lint-nonce values, then:
python3 scripts/software_english_lint.py FILE.md --record-lint-result clean --findings 0 --nonce <value> --units-judged <units>
```

Records a both-tier verdict for one named file in the commit check's
ledger; see "The commit check" above. Standalone: lints nothing itself,
needs no `data/` fetch, exits 0/2/3/4 (4: the nonce or the units claim
failed — "Proof that Step 3 ran" above has the reasons).

## Writing a skill's frontmatter

A `SKILL.md` frontmatter value must be valid YAML under a **strict**
parser, not just under Claude Code's own. Two rules, both enforced by
[`../tests/skill_frontmatter_test.sh`](../tests/skill_frontmatter_test.sh):

- An unquoted value must not contain `": "` (a colon then a space). YAML
  reads that as a second mapping separator and rejects the whole
  document. Use a comma instead. Quoting also parses, but a harness
  that splits on the first colon then shows the quote marks in the
  description, so removing the colon is the portable fix.
- An unquoted value must not open with a YAML indicator character
  (`[`, `{`, `|`, `>`, `&`, `*`, `!`, `%`, `@`, `` ` ``, `,`, `#`).
  Quote it: `argument-hint: "[uninstall] [repo-path]"`.

This is not theoretical. Claude Code accepts the invalid form, so a
broken skill looks fine locally while a strict-parsing harness drops it
with no error anyone sees. `/swe:lint-file`'s own description carried a
`": "` from `bd9edac` (v0.7.0) to v0.10.1 and was invisible in GitHub
Copilot CLI that whole time, while every other skill in the same plugin
loaded normally. A skill "missing" on one harness but not another is
this, until proven otherwise.

Copilot CLI additionally requires the frontmatter `name` to match the
skill's own directory name exactly; the same test asserts it.

## Known limits

- Vocabulary is a seed set. An unlisted but correct word gets a
  `warning`-severity finding, not an `error`. `vocabulary-membership`
  moves to `error` once the vocabulary is measured against a real
  corpus (SPEC §6.1).
- Lemmatisation is a suffix-strip, not a real lemmatiser. Some
  inflected forms of an approved word do not match.
- No auto-rewrite mechanism exists. A blocking hook reports a
  violation; you edit the text yourself in response. The
  fact-preservation check the specification names in its §9 is not yet
  built.
- No versioning scheme exists beyond a plain tag; `software-english` is
  pre-1.0.
- Sentence splitting runs per Markdown line, not per paragraph. A
  sentence hard-wrapped across two lines is undercounted for length.
- Code-comment extraction covers only Python (`#`) and Bash (`#`).
- `bash-check.sh`'s quote-parsing is regex-based, not a real shell
  parser. A commit or PR body passed through a heredoc
  (`git commit -F - <<'EOF' ... EOF`) passes through unchecked.
- `/swe:lint-file`'s heading pass judges headings only against the
  catalogued inference rules. Inconsistent grammatical form across
  sibling headings has no catalogue rule yet (proposed against
  `software-english`), so the pass reports none of it.
- `/swe:lint-file`'s Pass 3 (the whole-document pass) uses three rule
  ids of its own — `no-contradiction-between-sections`,
  `summary-before-detail`, and `no-precedent-before-subject` — that are
  not in the fetched `software-english` catalogue (proposed against
  `software-english` as a follow-up). Pass 3 also does not judge
  whether prose would fit a table better; that fault is left out.
- HTML text-node extraction treats every node at or above the
  character threshold as prose, including a button label.
- The Slack matcher in `hooks.json` is unverified: no Slack send tool
  exists in this installation's tool registry to test against.
- Judging the inference-based rules still costs real time, whether it
  is the current session doing it for `/swe:lint-file` or a dispatched
  subagent for a hook's advisory: it is real reasoning over real text,
  not a lookup. Moving it out of the script removed the subprocess and
  its own timeout, but not the underlying cost of the judgement itself.
- `bash-check.sh` and `mcp-send-check.sh` advise inference only after
  already letting the underlying tool call proceed unblocked: a commit
  can be amended once a finding comes back, but a sent message cannot
  be un-sent. This is the accepted cost of not delaying either tool
  call for the judgement.
- The growth-since-last-pass throttle (`inference_eligible()`) only
  applies to a single named file. A commit/PR message or an outbound
  MCP message has no identity across separate tool calls, so each one
  is still judged solely against the plain absolute threshold, same as
  before this rework.
- The register-rule candidate detectors (claude-plugins#18) read a
  closed, stdlib-only verb/auxiliary list, not real part-of-speech
  tagging: a verb outside that list can produce an extra
  `no-cadence-device` candidate, and a word `vocabulary/operations.tsv`
  also uses as a noun elsewhere can still miss one. A word directly
  before an object pronoun ("them", "it", and similar; claude-plugins#25)
  counts as a verb regardless of the list, and a code span now counts as
  one noun-phrase token rather than blank space, but a verb outside the
  list with no following pronoun and no code-span subject still misses.
- The verbless-fragment candidate only looks within one paragraph. A
  fragment set as its own paragraph (no blank line, just a one-line
  paragraph after the long sentence's own) is not detected: nothing in
  the line structure alone tells it apart from a caption or a label.
- `--html-file` gets no register-rule candidates: adjacent extracted
  text nodes are not adjacent prose lines, so the adjacency the
  detectors need does not hold.
- The definite-phrase detector (claude-plugins#19) is lexical only: a
  synonym, title or heading semantics, or a link target does not anchor
  a noun, only a shared lemma does. A noun introduced only inside a
  fenced code block or a blockquote does not anchor a later mention,
  since `prose_lines()` excludes those lines from the document it
  scans. A completed-act-participle marker ("the agreed plan", with no
  cardinal) is not detected; it falls through to
  `no-unanchored-reference` as a plain unanchored phrase instead, which
  the rules' own stated precedence still treats as correct, just not
  flagged as a presupposition specifically. A code file's extracted
  comments still get candidates even though an antecedent there is
  often a code identifier, not prose. A high-candidate-volume document
  is capped at 20 per rule, in document order, the same cap the #18
  detectors share.
- The undefined-term detector (`define-before-use`, software-english#21)
  has no cross-document state: a term that recurs across several related
  files, each linted separately, is counted only within the one file
  being checked. The heading-occurrence gate is a corpus-tuned precision
  filter, not part of the rule's own text: a term that recurs 3+ times
  with no definition but never appears in a heading is not a candidate.
  No part-of-speech tagging means a domain noun the vocabulary data
  happens to miss can still candidate the same as a coined term.
- The count/list mismatch detector (`no-count-list-mismatch`,
  software-english#21) only looks for a colon immediately after the
  counted noun phrase, in the same sentence: the issue's own "and/or list
  with no colon" variant, and a count followed by a separate bullet list
  in the next block, are not detected. Only the number words two through
  twelve are recognised, not a numeral or "one".
- `~/.claude/swe/inference-state.json` is never pruned. It contains a
  small amount of text per file ever checked; it is not cleaned up
  automatically yet.
- The commit check's ledger is never pruned either, and `.git/` is never
  cloned, so each clone of a repository starts with an empty ledger and
  needs its own `/swe:install-commit-hook` run.
- The nonce a `--force-inference` pass mints proves that pass ran on
  this exact content and its output reached the caller; it does not
  prove Step 4's judgement happened, since that step is invisible to
  the script by construction. Direct shell access can still write the
  ledger or `lint-nonces.json` by hand, bypassing both. `lint-nonces.json`
  contains at most one pending entry per file per worktree, so unlike the
  other two state files, it stays bounded on its own.
- The finding-shaped inference rule lines (claude-plugins#14) stop a
  findings-shaped grep from silently discarding the block, so a
  filtered run no longer looks clean when it is not. They do not, on
  their own, prove Step 4 happened: a caller could still read the rule
  lines and skip judging them. That boundary is the same one the nonce
  above already accepts.
- `prose_units()` (claude-plugins#20) reuses `register_blocks()`'s own
  parse, so it inherits that parse's own gaps: the `FENCE` toggle
  matches a bare ` ``` ` or `~~~` line regardless of the other fence
  style, so one style's closing line can be read as opening the other
  inside mixed, malformed fencing; a setext heading (a title line
  followed by a line of `=`/`-` characters) is not recognised as a
  heading, so it becomes an ordinary paragraph unit instead; and a
  leading YAML front-matter block's `---` delimiters match `HR_LINE`,
  so the front matter between them becomes one paragraph unit like any
  other, not a block skipped outright. None of these is fixed by this
  change; each was already true of the candidate detectors that share
  the same parse.
- `--units-judged`'s coverage claim proves only that the caller saw
  the worklist's real total for this blob, the same boundary the nonce
  itself already accepts: it does not, and cannot, prove that every
  unit claimed as judged was actually judged against every rule, since
  that judgement happens inside the model, invisible to this script by
  construction. A caller could copy the printed total without reading
  the worklist at all.
- `git diff --cached --diff-filter=ACM` skips a pure rename (`R`), which
  is correct (the content was already judged), but a rename with edits
  is also reported as `R` and so slips through unchecked.
- A partial stage (`git add -p`) can leave the staged blob different
  from any content that was ever judged, blocking the commit until the
  staged content itself is judged, not just the file on disk.
- `git commit --amend` re-runs `pre-commit`; a rebase or a merge commit
  (`pre-merge-commit`) does not, since this hook is installed under that
  name alone.
- A `clean` row proves a judgement happened, not that it was correct:
  the check trusts whatever `/swe:lint-file`'s Step 5 recorded.
- The `pre-commit` hook duplicates `is_path_ignored()`/
  `load_ignore_patterns()` from `scripts/software_english_lint.py`
  rather than importing them, since it must behave the same whether or
  not the plugin that installed it is still present. The two
  implementations can drift.
