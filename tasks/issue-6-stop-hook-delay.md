# Issue #6: Stop hook costs ~2s on every turn under Claude Code

Issue: https://github.com/jimbarritt/claude-plugins/issues/6

## Summary

`stop-check.sh` costs ~2037ms on every conversational turn under Claude
Code, measured from the transcript's own `hookInfos[].durationMs`, even
on a plain reply with nothing to check (no file edited, clean working
tree). Reproduced with a headless latency harness
([`jimbarritt/tsk#ops/local/run-latency-harness.py`](https://github.com/jimbarritt/tsk/blob/main/ops/local/run-latency-harness.py)),
and separately in a clean, ordinary git repo. The two real sub-steps
(`fetch-software-english-data.sh`, `software_english_lint.py --diff
--added-only --quiet-vocab`) take under 100ms combined when run
directly. The 2-second cost looks like it belongs to the hook's own
process orchestration, not the check content.

## Ask (from the issue)

Instrument `stop-check.sh` itself to find which stage inside the hook
(not the linter) accounts for the ~2000ms, then fix it.

## Findings from reading the code

`stop-check.sh`'s tail end (lines 59-86):

```sh
(
  cd "$CWD" || exit 0
  "$HERE/../scripts/fetch-software-english-data.sh" >/dev/null 2>&1
  ARGS=(...)
  "$LINTER" "${ARGS[@]}" > "$OUT_FILE" 2>&1
  echo $? > "$STATUS_FILE"
) &
WORKER=$!

(
  sleep 2
  pkill -9 -P "$WORKER" 2>/dev/null
  kill -9 "$WORKER" 2>/dev/null
) &
WATCHER=$!

wait "$WORKER" 2>/dev/null
kill "$WATCHER" 2>/dev/null
wait "$WATCHER" 2>/dev/null
```

A strong candidate root cause: `kill "$WATCHER"` sends `SIGTERM` to the
watchdog subshell's own PID, not to the `sleep 2` process running
inside it (a separate child PID). Bash does not preempt a subshell
that is blocked inside a child process's own syscall: the signal is
only actionable once that child (`sleep 2`) returns control to the
subshell, i.e. once the full 2 seconds elapse regardless of when `kill`
was sent. So `wait "$WORKER"` returns almost immediately (the real
check finishes in well under 100ms), but the following `wait
"$WATCHER"` then blocks for essentially the rest of the 2-second sleep,
every single time, independent of what the check actually did. This
matches the observation precisely: a near-constant cost close to the
hard cap, not a small multiple of the real work.

Not yet verified by instrumentation or a direct before/after
measurement, only by reading the script. Worth confirming with a
`date +%s%N` timestamp before/after each `wait` before committing to
the fix, per the issue's own suggested next step, but the mechanism
above is a specific, testable hypothesis rather than a guess at "it's
somewhere in there."

## Proposed fix

Drop the final `wait "$WATCHER"`. Keep `kill "$WATCHER"` (best-effort
cancellation of the watchdog once the real work is done), but do not
block the hook's own exit on that subshell actually terminating: once
`WORKER` finishes, there is nothing left for the watchdog to protect
against, and letting it finish its `sleep 2` (or die once killed,
whichever comes first) in the background, unreaped, costs nothing the
hook itself needs to wait on. Re-measure with the same latency harness
after the change to confirm the ~2000ms cost is gone, not just reasoned
away.

## Status

Not started. Task file only; no code changed yet.

## Next step

Instrument first (confirm the hypothesis against real timestamps), then
apply the fix above, then re-run the latency harness and
`tests/hooks_test.sh` before shipping. Version bump on ship (current:
0.7.0).
