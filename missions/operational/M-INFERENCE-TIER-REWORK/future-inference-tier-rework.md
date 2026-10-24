# Future task: rework when and how the inference tier runs

No GitHub issue filed yet. Spun out of
[issue-2-per-hook-toggle.md](issue-2-per-hook-toggle.md) while discussing
that task's Q4. Not started — issue #2's config work finishes first.

## Idea 1: hand off to a subagent instead of running in-hook

Jim, verbatim: the plugin should never run the inference tier itself. When
the deterministic tier passes on a file, the hook should report back to
the main session — "you now need to run a sub agent to do the inference
check on this file `<path>`" — rather than calling `claude -p --safe-mode`
in-process. This runs the inference tier as a subagent the main session
dispatches, not a blocking call inside the hook.

Motivation: this plugin's in-hook inference calls have timed out before.
Moving the call out of the hook removes that failure mode and makes the
check's background work visible instead of hidden inside a hook process.

Today only `file-check.sh`, `bash-check.sh`, `artifact-check.sh`, and
`mcp-send-check.sh` run inference synchronously (`stop-check.sh` already
skips it — see its own header comment on turn-latency cost). So this
touches all four of those hooks.

## Idea 2: reconsider when the inference tier triggers at all

Jim, verbatim: if a full inference check already found 20 issues, re-running
it after every single edit is wasteful — most of those edits are fixing
one of the 20, not introducing new prose. At the same time, Jim does not
want to have to manually remind the agent to run the check, but also does
not think it needs to run on every turn.

So this needs a trigger policy in between "every edit" and "only when
asked": something that knows whether a fresh inference pass is likely to
find something new, without needing a person to ask for it each time.

## Status

Done — shipped on `main` at
[`3108620`](https://github.com/jimbarritt/claude-plugins/commit/3108620).
Jim said "do it in one go": both ideas implemented and shipped in one
pass, with design decisions made directly rather than asked one at a
time first (per the open questions below, now answered by what shipped
rather than by a prior conversation).

Before implementing, delegated two Claude Code mechanics questions to
the `claude-code-guide` agent (no prior confirmed answer existed in
this repo): the correct non-blocking advisory hook JSON shape (a
`systemMessage` alongside `permissionDecision: "allow"` for
`PreToolUse`, or alongside no decision at all for `PostToolUse`, both
Claude Code only; Copilot CLI uses `additionalContext` for
`PostToolUse`, and — unverified — `permissionDecision: "allow"` +
`permissionDecisionReason` for `PreToolUse`, mirroring how this file
already handles Copilot's blocking case), and how an output style's
picker description is shown (`description` verbatim, no truncation
documented).

**Idea 1, implemented as:** `file-check.sh`, `bash-check.sh`,
`artifact-check.sh`, and `mcp-send-check.sh` now call the linter with
a new `--advise-inference` flag instead of the removed `--run-inference`.
This never runs a model call; it only decides whether a fresh pass is
worth dispatching (see idea 2) and prints an `INFERENCE_ADVISED` marker
line when it is. The hook (`strip_advise_marker()` and
`advise_inference()`, new in `hooks/_lib.sh`) strips that marker out of
the deterministic-tier report and, only when the deterministic tier
itself found nothing to block, returns a non-blocking advisory hook
response naming the exact command to run. Claude is expected to
dispatch a subagent (the `Agent` tool) to run it — the subagent's job
is to check and report only, same as `/swe:lint-file`, not to fix
anything; Claude reads its findings and fixes the source itself. For a
file source the command is `--force-inference` directly against the
path; for a text source (a commit/PR message, an outbound MCP
message), the hook first writes the checked text to a scratch file
under `~/.claude/swe/pending-inference/` and points the command at it,
since `bash-check.sh` and `mcp-send-check.sh` now let the underlying
tool call proceed unblocked before the subagent's pass completes.
Accepted cost, named in `docs/agent-guide.md`'s "Known limits": a sent
message cannot be un-sent once the inference pass finds something; a
commit can still be amended.

**Idea 2, implemented as:** `inference_eligible()` in
`software_english_lint.py`. A single named file — the only source with
a stable identity across repeated edits — is compared against its last
recorded `--force-inference` pass
(`~/.claude/swe/inference-state.json`, written by `save_inference_state()`
whenever `--force-inference` actually runs, whether dispatched by a
hook's advisory or run directly via `/swe:lint-file`): eligible again
only once its word or sentence count has grown by another
`config.json` `threshold_words`/`threshold_sentences` since that
recorded pass, not on every single edit regardless of whether the
prior pass found something. A first pass, or a source with no stable
identity across calls (piped text, an HTML file), falls back to the
same plain absolute threshold as before this task.

**Also this session:** the output style's picker description dropped
the redundant "per the swe plugin" clause (Jim's second, unrelated ask
in the same message as "do it in one go"). Version bumped to 0.6.0.

**Verified directly**, not just by reading the code back: ran
`file-check.sh` and `bash-check.sh` by hand against scratch files/`$HOME`s,
confirming a fresh clean file advises, a second identical call still
advises (no state recorded yet), a real `--force-inference` pass
records state, a no-growth re-check then stays silent, and growth past
threshold advises again; also confirmed a deterministic-error case
still blocks and never advises in the same call. Both existing test
suites (`hooks_test.sh`, `lint_fail_open_test.sh`) still pass; added
new coverage: `strip_advise_marker()`/`advise_inference()` unit tests
in `hooks_test.sh`, and a new `tests/inference_eligible_test.sh`
covering the throttle logic directly and offline (no fetched rule
catalogue needed).

## Open questions from before this shipped, now answered by the design above

- Does idea 2's trigger policy replace `file-check.sh`'s per-edit
  `--run-inference` call entirely, or sit alongside it? — Replaces it:
  `--run-inference` no longer exists; `--advise-inference` is the only
  gating path a hook uses.
- What signal decides "worth an inference pass now"? — Growth in word
  or sentence count since the last recorded pass on that same file,
  not a batch count, a time threshold, or an explicit end-of-task
  signal.
- Does idea 1 (subagent hand-off) change what idea 2's trigger can even
  see? — The two are linked through the state file: any
  `--force-inference` run, hook-dispatched or manual, updates the one
  state entry a later `--advise-inference` call reads. No per-call
  state lives inside the subagent itself.

## Addendum: the subprocess itself came out too

The design above still called `claude -p --safe-mode` from inside
`software_english_lint.py`, whether the caller was the hook's
dispatched subagent or `/swe:lint-file`'s own session. Jim asked, in a
follow-up session, why: shelling out to a second `claude` process for
the inference tier duplicated a model that was already available,
right there, in whatever was calling the script. His read: the only
real reason to keep that capability would be a standalone, outside-
the-harness use of the linter, which none of these scripts are built
for (a genuinely headless use case should be its own separate script);
every real call site here already runs inside a skill or a session.

Removed entirely: `run_inference()`, `build_inference_prompt()`, the
`claude`/`shutil`/`uuid`/`time` machinery behind that call, and
`config.json`'s `fast_model`/`model_call_timeout_seconds`.
`--advise-inference`/`--force-inference` now both print a fenced
`===INFERENCE_ADVISED===` block (the applicable rules), gated for the
former, unconditional for the latter, and never judge the prose
themselves. Whoever calls the script, a hook-dispatched subagent or
the current session running `/swe:lint-file`, judges the prose against
those rules directly, in its own context. Isolation from the project's
own CLAUDE.md (what `--safe-mode` used to provide) turned out not to
be wanted at all: Jim called inheriting that context a bonus, not a
risk, since the point was never to isolate the judgement from the
project, only to avoid a second model call duplicating one already
available.

Shipped on `main` at
[`bd9edac`](https://github.com/jimbarritt/claude-plugins/commit/bd9edac).
Full account in `STATE.md`'s "Recently done".
