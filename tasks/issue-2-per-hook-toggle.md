# Issue #2: software-english-lint per-hook enable/disable

Issue: https://github.com/jimbarritt/claude-plugins/issues/2

## Summary

`hooks/hooks.json` in the `software-english-lint` plugin registers five
hooks (`Stop`, `PostToolUse` on Write|Edit, and three `PreToolUse` hooks for
Bash/Artifact/MCP-send) with no per-hook toggle in `config.json`. Installing
the plugin turns all five on, uniformly blocking.

A coupling makes a simple toggle insufficient: `hooks/stop-check.sh` does
two things in one pass — a chat-reply check and a tracked-markdown-diff
check. `hooks/file-check.sh` (`PostToolUse` on Write|Edit) deliberately
skips tracked `.md` files, deferring to the Stop hook's diff. So disabling
the Stop hook today removes both checks, not just the reply one.

## Ask (from the issue)

- Config-level enable/disable for each of the five hooks, independently.
- Within the Stop hook, independent control over the reply check and the
  tracked-markdown-diff check.

## Status

Not started. Discussion and design to follow in this file.

## Discussion / decisions

(none yet)

## Next step

(none yet)
