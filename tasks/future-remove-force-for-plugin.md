# Future task: remove force-for-plugin, let the user choose the output style manually

No GitHub issue filed yet (Jim mentioned filing one in another session;
none had landed as of the last check). Raised by Jim in conversation.

## Ask

Jim, verbatim: "I think that we should let the user manually choose the
style" — remove `force-for-plugin: true` from
`swe/output-styles/software-english.md`, so installing the plugin no
longer forces the Software English output style on automatically. A
user opts in via `/output-style` themselves, same as any other
installed style.

## Why this is not a one-line flip

`swe/hooks/stop-check.sh`'s own header comment states the current
design directly:

> Under Claude Code, the reply/transcript check always skips,
> regardless of `hooks.stop.reply`: the plugin's own output style
> (`output-styles/software-english.md`, `force-for-plugin: true`) puts
> the same rules in the system prompt instead, so a reactive
> block-and-retry on the reply is no longer the first line of defence
> there.

That skip is unconditional under Claude Code today: `is_claude_code()`
true means `REPLY_ENABLED=false`, full stop, regardless of
`hooks.stop.reply`'s own setting. It assumes the output style is always
active, because today it always is (forced). If the style becomes
opt-in, a user who installs the plugin but never runs `/output-style`
to select it gets **no reply-level enforcement at all**: not the
forced system-prompt shaping, and not the reactive Stop-hook check
either, since that check still unconditionally skips under Claude Code
regardless of whether the style was actually selected. File edits,
commits, artefacts, and outbound messages stay checked regardless
(those hooks do not depend on the output style at all) — only the chat
reply itself is affected.

## Open question, not yet answered

Raised to Jim, not yet resolved: once the style stops being forced,
should `stop-check.sh`'s reactive reply check come back as the default
behaviour for Claude Code (i.e. `REPLY_ENABLED` follows
`hooks.stop.reply` under Claude Code too, the same way it already does
under Copilot CLI), or is the resulting gap acceptable, since a user
who wants the reply checked can just select the style themselves?

Claude Code hooks are not told which output style is currently active,
so `stop-check.sh` cannot detect "the user selected it anyway" and
skip only in that case — the choice is binary: always run the reactive
check under Claude Code once forcing stops, or accept that an
unselected style means an unchecked reply.

## Status

Idea captured, not scoped, not started. Blocked on the open question
above before this can move to an implementation plan.
