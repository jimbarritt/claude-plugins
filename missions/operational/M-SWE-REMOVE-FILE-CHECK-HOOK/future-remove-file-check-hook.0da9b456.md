# Future task: remove the PostToolUse (file-check.sh) hook

No GitHub issue filed. Decided in the same conversation as
[issue #6](issue-6-stop-hook-delay.md) and
[future-remove-force-for-plugin.md](future-remove-force-for-plugin.md),
captured here as its own record since it wasn't previously tracked as
a task of its own.

## Ask

Jim, verbatim, after reviewing the Stop hook's purpose: "Ok let's drop
that hook too. Outoutnstyle is already doing something like this." —
remove `file-check.sh` (`PostToolUse` on `Write`\|`Edit`) entirely, on
the reasoning that the output style already shapes content as it's
written, whether that's a chat reply or a file, since it's a
system-prompt instruction, not tied to one output channel.

## Why this followed from the Stop hook's removal

`file-check.sh` deliberately skipped a tracked in-tree `.md` file,
deferring to the Stop hook's own diff, specifically to avoid a
duplicate report. Once the Stop hook was gone (see issue #6), that
deferral target no longer existed, so `file-check.sh` would have needed
to stop deferring and check tracked markdown itself to avoid a silent
gap. Rather than make that change, Jim reviewed whether the hook was
worth keeping at all and decided it was not: `/swe:lint-file` already
exists as the deliberate, on-demand way to check a file, and the
plugin's own direction this session has been toward less automatic
enforcement, more user-configured checking.

## Consequence named before executing

With `file-check.sh` gone, no file edit is checked automatically,
whether or not the output style is selected (see
`future-remove-force-for-plugin.md` for that separate, related
removal). A user who wants a file checked runs `/swe:lint-file`
themselves, e.g. before a commit. `bash-check.sh`, `artifact-check.sh`,
and `mcp-send-check.sh` are unaffected, since none of them depended on
`file-check.sh` or deferred to it.

## Status

Done. `file-check.sh` deleted, its `PostToolUse` registration removed
from `hooks.json`, `hooks.file` dropped from `config.json`. Shipped on
`main` at
[`cec8f1a`](https://github.com/jimbarritt/claude-plugins/commit/cec8f1a),
version 0.8.0, in the same commit as the Stop hook and
`force-for-plugin` removals. Full record in
[`issue-6-stop-hook-delay.md`](issue-6-stop-hook-delay.md)'s Status
section.
