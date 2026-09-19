# Future task: on-demand lint command for a named file

No GitHub issue filed yet. Raised by Jim in conversation, alongside the
`future-inference-tier-rework.md` task (which is about when the inference
tier runs automatically). This task is about an explicit, manual trigger
Jim can invoke at will, independent of that automatic-trigger work.

## Ask

Jim, verbatim: add a command that runs a full lint — deterministic and
inference — on any named file, invokable at will. The inference stage
must actually run, not be skipped.

## Design decision

The linter's `--run-inference` flag gates the inference tier on the
deterministic tier being clean (`error_total == 0`) and the prose passing
a length threshold. That gate exists for the automatic hooks (avoid a
model call when there is nothing but pattern-level errors to fix first),
but it defeats the point of a manual "run everything on this file" command.

Asked Jim: force inference always, or keep the existing gate. Answer:
force it always. The command must not rely on the deterministic tier
being clean or the prose threshold passing — it runs both tiers
unconditionally.

## Implementation

- New Claude Code plugin command (`commands/<name>.md`) in
  `software-english-lint`.
- Needs a linter code path that runs inference unconditionally on a named
  file, distinct from `--run-inference`'s gated behaviour (which stays
  unchanged for the hooks — `file-check.sh`, `bash-check.sh`,
  `artifact-check.sh`, `mcp-send-check.sh`). Likely a new flag, e.g.
  `--force-inference`, rather than changing `--run-inference`'s semantics.
- Confirmed separately: the inference tier already shells out to a
  separate `claude -p --safe-mode` subprocess (`run_inference()` in
  `software_english_lint.py`) regardless of what invokes the linter, so
  this is unaffected by whether the command itself runs in-session.

## Status

In progress — being implemented now.
