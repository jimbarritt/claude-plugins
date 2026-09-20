# State

Last updated: 2026-09-19

## In progress

None.

## Next

Three open-issue tasks, scoped and ready, awaiting Jim's go-ahead to
execute (he asked to review before executing, and separately wants
these run autonomously once approved, not one-by-one with a check-in
between each):

1. [tasks/issue-6-stop-hook-delay.md](tasks/issue-6-stop-hook-delay.md):
   `stop-check.sh` costs ~2s on every turn under Claude Code. Strong,
   code-read (not yet instrumented) hypothesis: the trailing `wait
   "$WATCHER"` blocks on the 2-second watchdog subshell's own `sleep 2`
   even after the real check finishes in under 100ms, since `kill`
   sent to a subshell blocked in a child syscall does not preempt it.
   Proposed fix: drop that final `wait`. Verify by instrumenting/
   remeasuring before and after, per the issue's own suggestion.
2. [tasks/issue-4-feedback-tooling-gaps.md](tasks/issue-4-feedback-tooling-gaps.md):
   `/swe:send-feedback`'s 2+-entry clustering threshold, and
   `/swe:feedback` having no verdict for feedback about the tooling
   itself (forced into `wrong-fix`/`rule_id: unknown`, which then
   false-clusters with unrelated `unknown` entries). Proposed: a new
   `feature-request` verdict with its own `rule_id: null` (not
   `"unknown"`, so it cannot collide), and any entry with no real
   cluster surfaces individually instead of waiting for a sibling. One
   open question left in the task file: whether same-topic
   `feature-request` entries should ever cluster with each other.
3. [tasks/issue-5-gh-session-scope-friction.md](tasks/issue-5-gh-session-scope-friction.md):
   `gh issue create` is refused until the target repo is attached to
   the session's GitHub scope. Not a claude-plugins code fix (harness
   behaviour, flagged for escalation elsewhere per the issue itself);
   the only actionable scope here is a one-line note in
   `send-feedback/SKILL.md` near the `gh issue create` call, so a
   future run recognises the denial and knows the fix (`add_repo`,
   then retry).

Checked: none of #4/#5/#6 carry the `auto-fix-candidate` label the
`send-feedback/SKILL.md` mentions (a separate harness elsewhere reads
issues by that label) — these three are plain, unlabelled issues, not
already wired into that other mechanism.

4. [tasks/future-remove-force-for-plugin.md](tasks/future-remove-force-for-plugin.md):
   drop `force-for-plugin: true` from the output style, so a user
   selects it manually instead of the plugin forcing it on. Blocked on
   one open question before this can be scoped further: `stop-check.sh`
   unconditionally skips its reactive reply check under Claude Code
   today, on the assumption the forced style always covers the reply
   instead. Once forcing stops, does that reactive check come back as
   the default under Claude Code too (matching Copilot CLI's own
   behaviour), or is an unchecked reply for anyone who doesn't select
   the style an acceptable gap? Claude Code hooks cannot see which
   output style is active, so this is a binary choice, not something
   the hook can detect and branch on itself.

After these: [tasks/future-lint-document-profiles.md](tasks/future-lint-document-profiles.md)
(idea only, not scoped — needs a follow-up conversation on the doc-type
list and what "layered"/"filtered" rules means), then
[tasks/future-stop-reply-check.md](tasks/future-stop-reply-check.md)
(resolved for Claude Code already; still open for Copilot CLI).

## Recently done

- The inference-tier mechanics discussion resolved by removing the
  subprocess entirely, at Jim's direction, once he pointed out
  `software_english_lint.py` should never spawn a process at all
  (everything here already runs inside a skill or a hook-dispatched
  subagent, which already has a model attached). `run_inference()`,
  `build_inference_prompt()`, and the `claude -p --safe-mode` call are
  gone; `--advise-inference`/`--force-inference` now both print a
  fenced `===INFERENCE_ADVISED===` rules block instead of running
  anything, gated for the former, unconditional for the latter. Every
  caller (the four hooks' dispatched subagent, `/swe:lint-file`'s own
  session) judges the prose against those rules directly, in its own
  context, deliberately not isolated from it the way `--safe-mode` used
  to be. `bash-check.sh`/`mcp-send-check.sh` no longer need a scratch
  file, since the checked text goes straight into the advisory message.
  `config.json`'s `fast_model`/`model_call_timeout_seconds` are gone
  too, dead once there was no subprocess to configure.
  `send-feedback/SKILL.md`'s stalled-call pattern detection is gone,
  since there is no longer a call to stall. Caught and fixed several
  deterministic-tier findings (em dashes, a banned word, two overlong
  frontmatter descriptions) in files this touched, by actually running
  the full lint over them rather than assuming they were clean. Version
  bumped to 0.7.0. Shipped on `main` at
  [`bd9edac`](https://github.com/jimbarritt/claude-plugins/commit/bd9edac).
- Small follow-ups after the inference-tier rework shipped: the output
  style's picker description revised twice more at Jim's direction
  (added the spec URL, then made it a real clickable `https://` link);
  `swe/README.md` brought current with the rework (subagent-dispatch
  mechanism named explicitly, a stale duplicate closing line cut) and
  then actually run through the plugin's own full lint as asked — caught
  four em dashes that edit itself introduced (fixed) and one
  `banned-word` false positive on "Drive" in "Slack/Gmail/Drive" (the
  product name, not the verb; logged via `/swe:feedback`, text left as
  is). Shipped on `main` at
  [`4a75dfe`](https://github.com/jimbarritt/claude-plugins/commit/4a75dfe),
  [`a53b53d`](https://github.com/jimbarritt/claude-plugins/commit/a53b53d),
  [`bed5dec`](https://github.com/jimbarritt/claude-plugins/commit/bed5dec),
  [`b3b1732`](https://github.com/jimbarritt/claude-plugins/commit/b3b1732).
- [tasks/future-inference-tier-rework.md](tasks/future-inference-tier-rework.md):
  both ideas shipped together. Idea 1: the four non-`Stop` hooks no
  longer call `claude -p --safe-mode` themselves; each calls the
  linter with a new `--advise-inference` flag, which only decides
  whether a fresh pass is worth dispatching, and the hook turns that
  into a non-blocking advisory hook response telling Claude to
  dispatch a subagent to run the real check and report back. Idea 2:
  a single named file is throttled by growth since its last recorded
  `--force-inference` pass (`~/.claude/swe/inference-state.json`), not
  a flat per-edit threshold, so a file with known outstanding findings
  is not re-advised on every follow-up fix. Also fixed the output
  style's picker description (Jim's second ask this session). Both
  existing test suites pass; a new
  `tests/inference_eligible_test.sh` covers the throttle directly.
  Shipped on `main` at
  [`3108620`](https://github.com/jimbarritt/claude-plugins/commit/3108620).
- [tasks/future-plugin-rename.md](tasks/future-plugin-rename.md): renamed
  the plugin `software-english-lint` -> `swe` and dropped the `swe-`
  prefix from each command, so the picker shows `swe:feedback` instead
  of `software-english-lint:swe-feedback`. Full scope from the task
  file applied, including the directory rename, the three skill
  directory renames, the local state paths under `~/.claude/`, and
  every cross-reference in the docs. Both test suites pass. Shipped on
  `main` at
  [`b27f7e5`](https://github.com/jimbarritt/claude-plugins/commit/b27f7e5).
- [tasks/future-lint-command.md](tasks/future-lint-command.md): a new
  `/swe-lint-file` command runs a full lint (deterministic tier plus a
  forced, ungated inference tier) on a named file, on demand. Added
  `--force-inference` to the linter for it; `--run-inference`'s gate,
  used by the four hooks, is unchanged. Shipped on `main` at
  [`b06d0fc`](https://github.com/jimbarritt/claude-plugins/commit/b06d0fc).
- [tasks/issue-3-data-fetch-crash.md](tasks/issue-3-data-fetch-crash.md)
  ([issue #3](https://github.com/jimbarritt/claude-plugins/issues/3)):
  a cloud session's egress policy blocked the plugin's raw-HTTPS data
  fetch, and the linter crashed instead of failing open, which blocked
  every turn. Fixed (git-clone-based fetch, plus a real fail-open path
  in the linter) and shipped on `main` at
  [`6f08705`](https://github.com/jimbarritt/claude-plugins/commit/6f08705),
  closing the issue automatically. Diagnosed and fixed in one pass, no
  design discussion needed.
- [tasks/future-swe-output-style.md](tasks/future-swe-output-style.md):
  a plugin output style, forced on with `force-for-plugin: true`, puts
  Software English's rules directly in the system prompt. Claude
  Code's `stop-check.sh` reply/transcript check now skips outright;
  Copilot CLI, which has no output-style mechanism, keeps it unchanged.
  Shipped on `main`, pushed.
- [Issue #2](https://github.com/jimbarritt/claude-plugins/issues/2):
  `software-english-lint` per-hook enable/disable. Shipped on `main` at
  [`36391c4`](https://github.com/jimbarritt/claude-plugins/commit/36391c4),
  which closed the issue automatically. See
  [tasks/issue-2-per-hook-toggle.md](tasks/issue-2-per-hook-toggle.md)
  for the full record, including a jq gotcha the new unit test caught.

See [tasks/index.md](tasks/index.md) for the full task list.

## Repos in scope

- `jimbarritt/claude-plugins` - primary repo for this work.
- `jimbarritt/software-english` - upstream spec repo, changed when a
  plugins-repo task needs a spec change.
