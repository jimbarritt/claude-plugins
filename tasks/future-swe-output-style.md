# Task: a Software English output style for the plugin

No GitHub issue filed yet. Implemented and committed to `main` at
`24fa005`, not yet pushed — Jim to confirm the push.

## What shipped

`software-english-lint/output-styles/software-english.md`: a condensed,
hand-written version of the Software English rules, with
`keep-coding-instructions: true` and `force-for-plugin: true`. Claude
Code applies it automatically whenever the plugin is enabled, sending
its instructions with every request for the session, the same way it
sends the system prompt.

`hooks/stop-check.sh`'s reply/transcript check now skips outright under
Claude Code (`is_claude_code()`), regardless of `hooks.stop.reply`: the
output style covers that ground instead. Copilot CLI, which has no
output-style mechanism, keeps the check exactly as before, still gated
by `hooks.stop.reply`.

Docs updated to match: `docs/agent-guide.md` (new "Output style"
section, naming two gaps it does not close: a subagent does not
inherit the parent's output style, and the style is an instruction, not
a check, so a rule the model still gets wrong still needs a downstream
hook to catch it), `README.md`, `.claude-plugin/plugin.json` (version
0.2.0 to 0.3.0). `output-styles/software-english.md` is added to
`.swe-ignore`, alongside `agent-guide.md`, since it cites banned words
and patterns as examples the linter cannot tell apart from a live
violation. `tests/hooks_test.sh` gained two cases proving the split:
Claude Code skips the reply check on a real violation, Copilot CLI
still blocks on the same input.

## Open questions, as answered

- **Replace the Stop hook's reply check, sit alongside it, or fold the
  two tasks together?** Replace it for Claude Code; keep it unchanged
  for Copilot CLI, which has no output-style equivalent. This was not
  in the original three options and came from checking the plugin's
  existing Copilot CLI support (`is_claude_code()`,
  `_extract_copilot_transcript_reply`) before writing any code.
- **`keep-coding-instructions: true`?** Yes, settled without
  discussion. Claude is still doing software engineering.
- **Content: condensed rules, or a pointer to fetch/read the spec?**
  Condensed, hand-written into the style file. Confirmed the mechanism
  first: Claude Code sends the style's instructions with every request,
  not once per session, so there is no freshness gap to trade off
  against.
- **Multiple plugins forcing a style?** None Jim runs today, so no
  load-order conflict.

## Related

[future-stop-reply-check.md](future-stop-reply-check.md): its concern
(a wasteful block-and-retry loop for a small mechanical fix) is now
resolved for Claude Code, since the reply check no longer runs there at
all. Still open for Copilot CLI, where the loop is unchanged.

## Next step

Confirm with Jim whether to push `main` (currently one commit ahead of
`origin/main`). After that, no further work queued on this task unless
Jim finds the condensed rules miss something in practice.
