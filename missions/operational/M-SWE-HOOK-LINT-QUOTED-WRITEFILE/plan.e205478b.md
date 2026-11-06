# Plan: claude-plugins#33 — bash hook lints a quoted example inside a heredoc, and reads a stale body file

## The ask (verbatim)

Title: "bash hook: lint skips quoted examples, and reads a body file before the same command writes it"

> The PreToolUse bash hook lints the body of `git commit`, `gh pr` and `gh issue` commands, including the content of `--body-file`, `-F` and `--file`.
>
> Two consequences, both of them reached today.
>
> **A report about a word rule cannot be filed.** An issue proposing a new banned word has to show that word in an example sentence. Once the rule exists, the hook blocks the call and names the example as the fault. The only ways through are to disable the hook, or to write around the word. Writing around it removes the evidence a maintainer needs.
>
> **A write-then-send command is linted against the old file.** One command that writes a body file and then sends it is checked before the write. The report then names faults that the pending write already fixes. The block stops the write as well, so the correction never happens. The text has to be written by a separate call first.
>
> Fix directions:
>
> - Do not lint text inside a blockquote or a fenced code block, which is where a quoted example belongs.
> - Lint the body file after any write to that path in the same command. Or decline to lint when the command writes the path it sends.

## Reading

Two consequences were claimed; investigation found one already fixed and the other real but not where the issue's own fix direction points.

1. **Write-then-send (consequence 2): already fixed.** claude-plugins#30 (closed 2026-10-29) added exactly the "decline to lint when the command writes the path it sends" behaviour: `swe/hooks/bash-check.sh` skips reading a `-F`/`--body-file`/`--file` target whose basename appears earlier in the same command. `swe/tests/bash_check_test.sh` already has fixtures for the sed/python3/heredoc write-then-`-F` cases, and they pass today. No code change needed for this half; only the issue comment needs to say so.

2. **Quoted example blocks the report (consequence 1): real, but blockquote/fence skip is not the cause.** `software_english_lint.py`'s `prose_lines()` already skips markdown blockquote lines and fenced code blocks for every text source, including the bash hook's `--text` path — confirmed by direct reproduction, and this predates #33 (present since well before Oct 19). The issue's suggested fix (skip blockquote/fence) is therefore already in place for the *file-body* path and would do nothing new.

   The actual bug: `bash-check.sh`'s invocation-split regex (`(?:^|[;&|]) *(?=git commit|gh pr|gh issue)` with `/m`) matches `^` at the start of *any* line, including a line inside a heredoc body. A command that first writes a body file containing a fenced or quoted `git commit -m "..."` example (exactly what filing a word-rule issue requires), then makes the real `gh issue create --body-file ...` call, gets its `INVOCATION` split at the quoted example line inside the heredoc, not at the real call. The quoted example is then read as the real command's own `-m` text and linted/blocked directly — reproduced directly against the real hook:

   ```
   cat > body5.md <<'EOF'
   The hook blocks this example:

   ```
   git commit -m "The service wants a token."
   ```
   EOF
   gh issue create --title "Ban a word" --body-file body5.md
   ```

   denies with "1 Software English error(s)" even though the real call (`--title "Ban a word" --body-file body5.md`, with body5.md never read because it's written in the same command and would in any case be clean) has no fault. This is consequence 1 exactly: the report is blocked and the example is named as the fault.

3. **Inference tier (advisory only, never denies):** `bash-check.sh` and `mcp-send-check.sh` hand the raw, unfiltered `$TEXT` to the dispatched subagent with no instruction to disregard quoted/fenced material. Not a blocking bug, but worth a one-line prompt fix alongside the real one.

4. **Other hooks:** `artifact-check.sh` lints a file through `prose_lines()` directly, no shell parsing, so it has no equivalent deterministic bug — optional prompt note only. `mcp-send-check.sh` reads a JSON field, no shell parsing either, but gets the same prompt note as the other advisory path.

## Plan

1. `swe/hooks/bash-check.sh`: before splitting `$COMMAND` into `PRE`/`INVOCATION`, build a `SCAN` copy with every heredoc body's characters (not its newlines) blanked to spaces, so a quoted `git commit`/`gh pr`/`gh issue` line inside a heredoc body can never be mistaken for the split point. A `<<<` here-string must not be treated as a heredoc. Run the split regex against `SCAN` to find the offset; take `PRE` from the original `$COMMAND` (must stay unblanked — the #30 fix needs to see a basename inside a heredoc header/body); take `INVOCATION` from `SCAN` (so `-F`/inline-value extraction never sees heredoc content as if it were the real call's own flags).
2. `swe/hooks/bash-check.sh` and `swe/hooks/mcp-send-check.sh`: add one sentence to the `advise_inference` prompt text telling the model that a blockquote line, a fenced or indented code block, and a code span hold quoted material the deterministic tier already skips, so it should report no finding inside one.
3. Add fixtures to `swe/tests/bash_check_test.sh` (existing `run_hook`/`denies`/`passes`/`silent` style):
   - heredoc-written body file containing a fenced faulty example, then a clean real `--body-file` call: expect `passes`, not denied (fails before the fix);
   - `git commit -m "$(cat <<'EOF' ... EOF)"` with a faulty example line inside the heredoc body: expect `silent` (fails before the fix);
   - the #30 regression still holds with a heredoc example present alongside a real faulty `--title`: expect `denies`;
   - a `<<<` here-string earlier in the command is not mistaken for a heredoc, and a real faulty `-m` after it still `denies`.
4. Update the bash-check limitations paragraph in `swe/docs/agent-guide.md` (bash hook section): heredoc bodies are now excluded when locating the git/gh call and its flags (claude-plugins#33); the existing gap — a multi-line inline `-m`/`--body` value is never linted at all, because the inline extractor is line-based — stays as is and is now documented, not changed.
5. Bump `swe/.claude-plugin/plugin.json` version (patch).
6. Run `swe/tests/bash_check_test.sh` and the rest of the `swe` test suite; run `scripts/check-unshipped.sh`.
7. Commit with `closes #33`; comment on the issue explaining: consequence 2 was already fixed by #30; the blockquote/fence skip already applied to the file-body path; the real block came from a quoted git/gh command line inside a heredoc body being mistaken for the real invocation, now fixed; the advisory inference prompt now tells the model to skip quoted material.

## Critical files

- `swe/hooks/bash-check.sh`
- `swe/tests/bash_check_test.sh`
- `swe/hooks/mcp-send-check.sh`
- `swe/docs/agent-guide.md`
- `swe/scripts/software_english_lint.py` (read only — `prose_lines()`/`FENCE`, no change needed)
