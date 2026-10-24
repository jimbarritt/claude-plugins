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

## Open question, resolved by a different decision

The question below became moot, not answered on its own terms: while
discussing [issue #6](issue-6-stop-hook-delay.md) (the Stop hook's ~2s
cost), Jim asked to review the hook's whole purpose, decided it was
overbuilt, and removed it entirely — the same hook this question's own
"reactive check" fallback would have needed. With no Stop hook left to
bring back, the choice this question posed no longer exists: there is
no reactive fallback, full stop. Removing `force-for-plugin` just means
reply checking is opt-in, with no hook-based safety net either way.
Jim's framing when adding this to the same batch: "we went overboard
there before we knew about the output style."

Original question, for the record: once the style stopped being
forced, should `stop-check.sh`'s reactive reply check have come back as
the default under Claude Code (matching Copilot CLI's own behaviour),
or was the resulting gap acceptable? Superseded before it needed an
answer.

## Status

Done. `force-for-plugin: true` removed from
`swe/output-styles/software-english.md` in the same pass as removing
the Stop and PostToolUse hooks. Shipped on `main` at
[`cec8f1a`](https://github.com/jimbarritt/claude-plugins/commit/cec8f1a),
version 0.8.0. Full record in
[`issue-6-stop-hook-delay.md`](issue-6-stop-hook-delay.md)'s Status
section.
