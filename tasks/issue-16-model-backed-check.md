# Issue #16: run a model-backed check before the action, within fixed limits

Status: escalated to supervisor.

## The ask, verbatim

> Evaluate whether swe can run a model-backed check before an outbound
> message or an artifact publish, for a named subset of rules, under fixed
> limits.

Raised by comparison with OpenAPPA, an information-flow policy engine whose
annotators/authorities/sanitizers can be model-backed, with the engine
checking each model answer against declared permits before acting, under a
timeout and concurrency limit. The issue lists five open questions it does
not answer itself:

- Which rules need judgement and are worth the delay.
- What the check does when the model times out or fails: allow or block.
- How a model call before the action fits with the README's stated concern
  that running a model inside the hook "can stall a tool call".
- How the model's answer is restricted (e.g. a fixed pass/fail-plus-rule-ID
  result set).
- A cost limit per action, and whether the existing repeat-pass throttle
  applies.

## Reading

This is a design/research question, not a bounded feature request. Each of
the five open questions is a product decision; different answers lead to
materially different implementations (the routine's own escalation
trigger). Dispatched a Plan subagent (Opus) to read the issue against the
current `swe` architecture before concluding this — see Plan below.

## Plan (from the Opus Plan subagent, verified against the repo)

The subagent's core finding, checked directly against the cited files:

- `swe/docs/agent-guide.md` ("When the inference tier runs"): "This script
  has no model access of its own, and never spawns one... Nothing here
  ever shells out to `claude -p` or any other subprocess for the judging
  step."
- `swe/README.md`: the inference tier is deliberately *not* run inside the
  hook, "which can stall a tool call on a slow or failed model response";
  instead the hook only advises Claude to dispatch a subagent after the
  action has already gone through.

Issue #16 proposes the opposite: a synchronous, blocking model call
*before* the action (OpenAPPA-style), for at least some rules. That is a
reversal of a documented design invariant, not an extension of it. Only
Jim can decide whether to lift that constraint, and if so, how the fail
mode, rule scope, timeout, and cost limit should work — guessing at any of
these risks spending the routine's two-attempt budget on a speculative
implementation that gets reverted wholesale once a real answer arrives.

Current architecture, for reference (verified in `swe/hooks/hooks.json`,
`swe/hooks/_lib.sh`, `swe/hooks/mcp-send-check.sh`,
`swe/hooks/artifact-check.sh`):

- **Deterministic tier**: each `PreToolUse` hook (`bash-check.sh`,
  `artifact-check.sh`, `mcp-send-check.sh`) runs the linter and blocks the
  action synchronously on a plain, pattern-checkable violation.
- **Inference tier**: if the deterministic tier is clean, `--advise-inference`
  plus `inference_eligible()` (throttled via
  `~/.claude/swe/inference-state.json`) decide whether to print an
  `===INFERENCE_ADVISED===` block. This is advisory only, surfaced to
  Claude itself to re-check as a subagent, non-blocking, and runs after the
  action has already completed.

No hook today makes a synchronous external model call, and nothing in the
plugin has a timeout, cost limit or concurrency limit — all five of the
issue's open questions are genuinely unanswered in the existing code, not
merely undocumented.

Research the issue cites (OpenAPPA comparison, Jev classifier) lives in
`jimbarritt/tsk`, which is out of scope for this session; not read.

### If Jim confirms the direction, likely scope for a follow-up run

- A new opt-in key in `swe/config.json` (named rule subset, timeout,
  fail-open/fail-closed mode).
- A bounded-inference helper in `swe/hooks/_lib.sh`: a `timeout N claude -p`
  call with tools/project-settings disabled, parsing a fixed result set
  (`PASS` or `FAIL <rule-id>`, restricted to the configured IDs); anything
  else treated as a model failure and handled per the configured fail mode.
- Wiring into `mcp-send-check.sh` and `artifact-check.sh` only (not
  `bash-check.sh`, which isn't an outbound action).
- Rule-eligibility flags in `swe/rules/plugin-rules.toml`.
- README and `agent-guide.md` updates — the "never spawns one" line would
  need to change from an absolute to a scoped, opt-in exception.
- A new `swe/tests/pre_action_inference_test.sh` stubbing `claude` on PATH
  to cover pass, fail, timeout, and malformed-answer cases.

This is not committed to; it depends entirely on Jim's answer below.

## Question posted to the issue

> Should swe drop its documented rule that hooks never spawn a model
> (`agent-guide.md`, "When the inference tier runs") and add a blocking
> pre-send `claude -p` check? If so, which named rules should it cover, and
> should it allow or block the action when the model times out or fails?

## Outcome

Escalated. `agent:working` swapped for `supervisor`. Waiting on Jim's
answer on the issue thread.
