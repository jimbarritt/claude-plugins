# Report: claude-plugins#33 — bash hook lints a quoted example inside a heredoc

## Outcome

Fixed and released. Commit `c13b28c` on `main`, `swe` bumped to
`0.26.2`, released as tag `swe-v0.26.2` via `release-plugin.yml` run
[#62](https://github.com/jimbarritt/claude-plugins/actions/runs/42271618319)
(success). Issue closed by the commit's `closes #33`; `agent:working`
removed, `auto-fix-candidate` left in place.

## What changed

The issue claimed two consequences. Investigation found each one had a
different cause than the issue's own fix direction assumed:

1. **Write-then-send (consequence 2): already fixed**, by claude-plugins#30
   (closed 2026-10-29). `bash-check.sh` already declines to read a
   `-F`/`--body-file`/`--file` target whose basename appears earlier in
   the same command. No code change needed; the issue comment explains
   this and a fixture locks the case in alongside the new ones.

2. **Quoted example blocks the report (consequence 1): real, but not a
   blockquote/fenced-code gap.** `software_english_lint.py`'s
   `prose_lines()` already skips markdown blockquote lines and fenced
   code blocks for every text source, including the bash hook's `--text`
   path, and has done so since before this issue was filed (confirmed
   against git history). The issue's own suggested fix — skip
   blockquote/fence — would have done nothing new.

   The actual cause: `bash-check.sh`'s invocation-split regex
   (`(?:^|[;&|]) *(?=git commit|gh pr|gh issue)` with `/m`) matched
   `git`/`gh` at the start of *any* line, heredoc bodies included. A
   command that first writes a body file containing a quoted
   `git commit`/`gh pr`/`gh issue` example — exactly what filing a
   report about a new banned word requires — then makes the real call,
   had its invocation located at the quoted example inside the heredoc,
   not at the real call. Reproduced directly against the hook before
   any change: a clean real call was denied with "1 Software English
   error(s)" because of the quoted example alone.

## Fix

`swe/hooks/bash-check.sh`: before the invocation split, build a
heredoc-blanked scan copy of the command (every heredoc body's own
characters replaced with spaces, newlines kept so offsets still line
up), and locate the split on that copy instead of the raw command. The
heredoc header line (which may itself name the file the `#30` check
needs to see) is never blanked, only the body between it and its
terminator. A `<<<` here-string is excluded by a negative lookbehind, so
it is never mistaken for a heredoc. Handles `<<`/`<<-` with an unquoted,
single- or double-quoted tag; a backslash-escaped tag (`<<\EOF`) is a
known, documented gap, consistent with this file's other documented
limitations.

Also added one sentence to the advisory inference prompt in
`bash-check.sh`, `mcp-send-check.sh`, and `artifact-check.sh`, telling
the dispatched subagent to skip quoted/fenced material the same way the
deterministic tier does — the inference tier was handed the raw,
unfiltered text with no such instruction.

## Tests

Added to `swe/tests/bash_check_test.sh`:

- a heredoc-written body file containing a quoted faulty `git commit`
  example, followed by a clean real `--body-file` call: `silent` (was
  incorrectly `denied` before the fix — confirmed by reverting the hook
  and re-running);
- the same, but with a real fault in `--title`: still correctly
  `denied` (the fix does not swallow a real fault);
- a `<<<` here-string before a real call: the real call is still
  checked correctly either way (safety check on the negative
  lookbehind).

Also fixed two pre-existing `banned-word` findings in
`swe/tests/bash_check_test.sh` ("actually", "gate"), plus one each in
new comment text in `bash-check.sh` and `bash_check_test.sh` itself:
all were "the real" split across a line wrap, which the deterministic
tier's per-line check could not catch but the `--force-inference`
worklist's joined-paragraph view did.
`swe/docs/agent-guide.md`'s limitations section updated to document the
fix and the two gaps it does not touch (a commit/PR body piped through
`-F - <<EOF`, and a multi-line inline `-m`/`--title`/`--body` value,
which the line-based inline extractor never matches at all).

Full `swe` test suite (20 files) passed; `scripts/check-unshipped.sh`
confirmed the release.

## Found along the way

A plugin's own test and hook comments can carry a `banned-word` fault
across a line wrap that the deterministic tier's per-line check never
sees; only the `--force-inference` worklist's joined-paragraph text
shows it. Caught three such instances while linting this change's own
touched files.
