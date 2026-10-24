# Issue #14: `--force-inference` rule block silently discarded by a findings-shaped grep

[Issue #14](https://github.com/jimbarritt/claude-plugins/issues/14)
Opened by `jimbarritt-pleo` (trusted collaborator). Claimed by the
self-maintaining-repo Routine on 2026-09-30.

## The ask, verbatim

> ## The failure
>
> A document was linted with `--force-inference`, reported clean, and shipped with a metaphor in it (see the sibling issue on `no-metaphor-or-analogy`). The inference tier never ran, and nothing in the output indicated that.
>
> ## Cause
>
> `--force-inference` prints the applicable inference rules to stdout as ordinary text, alongside the deterministic findings. A caller that filters the output, which is the natural thing to do on a long file, discards the rule block silently:
>
> ```
> python3 software_english_lint.py FILE --force-inference --quiet-vocab \
>   | grep -E ":\s*\[(error|warning)\]"
> ```
>
> That pipeline returns the deterministic findings only. When they are empty it prints nothing, which reads exactly like a clean two-tier pass. The rules the model was supposed to apply were never seen, and the exit code is `0` either way.
>
> The docstring is clear that the script "never judges the prose itself", so the inference block is not advisory output, it is a required input to the next step. Discarding it is a silent skip of half the check.
>
> ## Proposed fix
>
> Any one of these closes it. In rough order of preference:
>
> 1. **Make the block unfilterable by shape.** Emit each inference rule on a line matching the same `path:line: [severity] [rule-id] ...` grammar as a deterministic finding, so a caller grepping for findings receives them rather than dropping them. They are already `severity = "warning"` in the catalogue.
> 2. **Use a distinct exit code** when `--force-inference` printed a block that has not been acted on, for example `2`, so a caller cannot treat a filtered run as clean.
> 3. **Write the block to stderr** rather than stdout, so a stdout filter leaves it visible. Weaker than 1, since `2>/dev/null` is common too.
> 4. **At minimum, print a trailing marker line** that survives a findings-shaped grep, for example `path:0: [warning] [inference-pending] N inference rules require model judgement`.
>
> Option 1 is the one that makes the correct behaviour the default rather than relying on the caller knowing the hazard.
>
> ## Related
>
> The nonce machinery already exists to prove `--force-inference` ran on specific content. It proves the script ran, not that its output was read. This issue is about the second half.

(The "sibling issue" is #15, a false negative in `no-metaphor-or-analogy` on
motion verbs with an abstract subject. Out of scope here: #14 is only about
the output shape.)

## Reading

Confirmed against the real code (`swe/scripts/software_english_lint.py` at
`221e451`): deterministic findings print as
`f"{label}:{number}: [{severity}] [{rule}] {detail}"`, but the inference
block (`format_inference_rules()`) prints a different shape
(`- rule-id: description`) inside `===INFERENCE_ADVISED===` fences — no line
in it matches a findings-shaped grep, so the whole block, description text
and rule ids included, is silently dropped by the pipeline the issue
describes. A second, related hole not named in the issue: `--count`
combined with `--force-inference`/`--advise-inference` returns before the
inference block prints and before the nonce mints, so that combination
always reports "0 errors, 0 warnings" and exits 0 regardless of prose
content.

## Plan (from an Opus Plan subagent, reading the real code, tests and docs)

Adopt option 1 plus option 4, keep the fences, and make `--count` combined
with an inference flag an error (exit 2, matching the existing
malformed-argument convention).

**New line grammar**, `<label>` = the same source label deterministic lines
use:

```
<label>:0: [warning] [<rule-id>] inference pending: <description>
<label>:0: [warning] [inference-pending] <N> inference rule(s) above need model judgement; this script does not judge them. Deterministic tier: <E> error(s), <W> warning(s).
```

- Line number is always `0` (never used by a real finding) so a rule line
  is never mistaken for a violation at a real location.
- Severity is always `warning`, regardless of the rule's own catalogue
  severity (today only `one-point-at-a-time` is `error`) — a pending rule
  is not itself a violation. Where the real severity differs, append
  `(severity on violation: error)` to that rule's line so Step 4 still
  gets it.
- `[<rule-id>]` stays the real catalogue id.
- Fixed `inference pending:` prefix distinguishes a rule line from a real
  finding sharing the same rule id.
- `[inference-pending]` is a reserved id (in neither catalogue) marking the
  one summary line, which restates the true deterministic counts so a
  caller counting `[warning]` lines is not misled by the added rule lines.
- Descriptions have their internal newlines collapsed to spaces so each
  rule stays on one grep-able line.
- Order: deterministic finding lines, then the fence, then one line per
  applicable rule (per source), then the summary line, then the closing
  fence, then the nonce line (unchanged position, still last).

Rejected: a distinct exit code (a pipeline reports grep's status, not the
linter's, so it would not fix the cited case; the script cannot know
whether the block "was acted on", so every non-trivial file would get the
same code; codes 2-4 are already taken). Rejected: stderr (every caller
already redirects `2>&1`; weaker than option 1 per the issue itself).

**Files to touch:**

- `swe/scripts/software_english_lint.py`: rewrite `format_inference_rules()`
  to the new grammar; reject `--count` with either inference flag (exit 2);
  keep hooks' fence-based stripping working (`strip_advise_block`/
  `extract_advise_rules` in `swe/hooks/_lib.sh` need no code change, since
  the fences are unchanged); update the module docstring and argparse help.
- `swe/hooks/_lib.sh`: comment update only (fence contract now documented
  as finding-shaped).
- `swe/hooks/artifact-check.sh`, `bash-check.sh`, `mcp-send-check.sh`: one
  added sentence in the advisory message clarifying line `0` and
  "inference pending" so a dispatched subagent does not misread a rule
  line as a finding.
- `swe/skills/lint-file/SKILL.md`: Steps 3-6 updated for the new grammar
  (how to read a rule line, how to compute the deterministic error count
  now that rule lines are also `[warning]`-shaped, when "clean, both
  tiers" may be reported).
- `swe/docs/agent-guide.md`: the block's documented example, the grammar,
  the three splitting regexes (pending rule / summary / real finding),
  the `--count` + inference-flag rejection, a "known limits" bullet noting
  the fix does not prove Step 4 happened, only that a filtered pipe can no
  longer look clean.
- `swe/tests/commit_check_test.sh`: assert the grep from the issue now
  keeps rule + summary lines; nonce still last; no old `- rule:` format;
  rule lines never count as `[error]` at a real line; deterministic-failure
  case still shows both the real finding and the pending lines; no-prose
  case unchanged; a multi-line-description fixture rule stays one line;
  `--advise-inference` still strips cleanly via `_lib.sh` for hooks;
  `--count` with either inference flag exits 2.
- `swe/tests/hooks_test.sh`: update the hand-written fixture block to the
  new grammar so `strip_advise_block`/`extract_advise_rules` are tested
  against real-shaped input.
- `swe/.claude-plugin/plugin.json`: version bump (minor, since the output
  format is a caller-visible change) `0.15.1` -> `0.16.0`.

No `software-english` change: this issue is entirely in `claude-plugins`'
own linter script and its callers.

## Outcome

Shipped end to end, single pass, no escalation. Implemented per the plan
above, with two adjustments found only during implementation:

- The plan's worked example assumed a clean-vocabulary summary line
  (`0 error(s), 0 warning(s)`); the real fixture (and any real file with
  no seeded vocabulary list) trips `vocabulary-membership` on ordinary
  words, so the summary line's true counts are non-zero even on
  deterministically-clean prose. Test expectations were written against
  the linter's actual output, not the plan's illustrative numbers.
- Two em dashes introduced while writing this task's own prose (one in
  `swe/skills/lint-file/SKILL.md`, caught by running `--force-inference`
  on the file itself; two more in `swe/scripts/software_english_lint.py`'s
  docstring and `swe/docs/agent-guide.md`, caught by grepping the diff
  directly, since neither a Python docstring nor an `.swe-ignore`'d file
  is machine-checked) were fixed before committing.

`swe/tests/commit_check_test.sh` gained 16 new assertions (a
`fixture-multiline` rule added to the fixture catalogue to prove a
multi-line TOML description still prints as one grep-able line, plus
coverage of the `--count` rejection and the hooks' `_lib.sh`
strip/extract split); `swe/tests/hooks_test.sh`'s hand-written fixture
block updated to the new grammar. All five suites pass (124 assertions,
up from 108). `scripts/check-unshipped.sh` confirmed clean before and
correctly flagged pending after the version bump.

Version bumped `0.15.1` -> `0.16.0`. Shipped on `main` at
[`337de79`](https://github.com/jimbarritt/claude-plugins/commit/337de79),
which closed the issue automatically via its `closes #14` trailer,
released as
[`swe-v0.16.0`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.16.0).
