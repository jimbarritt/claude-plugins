# Future: a model-backed check before the action, within fixed limits

Status: deferred. Discuss with Jim at a later date, not urgent.

## Origin

[Issue #16](https://github.com/jimbarritt/claude-plugins/issues/16),
escalated by the self-maintaining-repo Routine on 2026-10-02 (single pass,
no implementation attempted). Full reading, architecture check, and the
question posted to the issue are in
[tasks/issue-16-model-backed-check.md](issue-16-model-backed-check.md).
That file's record stands; this one exists so the topic surfaces as a
planning item instead of staying parked only on a `supervisor`-labelled
issue.

## The ask, in short

Today's inference tier (swe) only advises a check after the action has
already gone through. The issue asks whether swe should also support a
synchronous, blocking model check *before* an outbound message or artefact
publish, for a named subset of rules, under fixed limits (timeout, fail
mode, cost). That reverses a documented invariant
(`swe/docs/agent-guide.md`: hooks "never spawn" a model), which is why the
routine escalated instead of guessing.

## Research referenced by the issue

- [OpenAPPA](https://github.com/archestra-ai/OpenAPPA) — an open-source
  information-flow policy engine. Its annotators/authorities/sanitizers
  can be model-backed; the engine checks each model answer against
  declared permits before acting, under a timeout and concurrency limit.
- Archestra's own comparison of deterministic vs. inference-based checks,
  including swe and OpenAPPA side by side:
  https://github.com/jimbarritt/tsk/blob/main/docs/kb/orchestration-ecosystem/openappa.md
- The Jev classifier (TypeSafe AI), used by OpenAPPA's `jev` annotator as a
  bounded component in the same engine:
  https://github.com/jimbarritt/tsk/blob/main/docs/kb/typesafe-jev-classifier.md

`jimbarritt/tsk` is outside this session's repo scope, so neither link has
been read yet; read them first when this comes up for real discussion.

## Open questions (from the issue, still unanswered)

- Which rules need judgement and are worth the delay.
- Fail mode when the model times out or errors: allow or block.
- How a blocking pre-action call squares with the documented concern that
  a model call inside a hook "can stall a tool call".
- How the model's answer is restricted (e.g. a fixed pass/fail-plus-rule-ID
  result set, so the answer cannot widen what the check allows).
- A cost limit per action, and whether the existing repeat-pass throttle
  applies.

## Next step

Jim reads the two research links, then decides on the issue thread
whether to lift the no-spawn-a-model constraint and, if so, the rule
scope and fail mode. No code change until that answer lands.
