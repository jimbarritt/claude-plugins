# Claude output taxonomy

## Terms

- **D tier** — deterministic rules (`vocabulary-membership`, `banned-word`,
  `no-continuous-tense`, `anthropomorphism-fixed-list`, `abstract-location`).
  A Python script checks them. No model call.
- **I tier** — inference-based rules (`sentence-length`,
  `no-perfect-tense-for-behaviour`, `anthropomorphism-paraphrase`,
  `vacuous-classification-property`, `no-process-narration`,
  `document-type-template`). A model checks them.
- **Stop input** — the JSON a Stop hook receives. It holds
  `last_assistant_message`, `transcript_path` and `stop_hook_active`.

## Mechanism constraints

1. The current Stop hook lints only lines that `git diff --unified=0 HEAD`
   reports. Untracked new files do not appear in that diff. A new markdown
   file is not linted until it is staged or committed.
2. `last_assistant_message` holds only the final text block of the turn.
   Text the model writes between tool calls (progress updates) is not in it.
   That text is in the transcript at `transcript_path`.
3. All hooks that match one event run in parallel. A hook cannot read the
   result of another hook in the same event. A check that depends on the
   D-tier result must run in the same process as the D-tier check.
4. A `prompt` hook cannot read files. It sees only the Stop input and its
   prompt string. An `agent` hook can read files.
5. When a Stop hook blocks and the model produces a new reply, the next Stop
   input has `stop_hook_active: true`. A hook must read this flag or it can
   block without limit.
6. Commit messages and PR bodies pass through the `Bash` tool as arguments to
   `git commit` and `gh pr create`. No Stop hook sees them. A `PreToolUse`
   hook with matcher `Bash` sees the full command string before it runs.
7. The `Artifact` tool publishes a file from `file_path`. A `PreToolUse` hook
   with matcher `Artifact` sees that path before publication.

## Taxonomy

| # | Output kind | Where it exists | D | I | Notes |
|---|---|---|:-:|:-:|---|
| 1 | Chat reply, final text of the turn | `last_assistant_message`; not on disk | ✓ | ✓ | Runs on every Stop event. The I tier runs only when the threshold check passes. Not checked today. The Stop input holds the reply at no cost, and it is the largest volume of prose a person reads. |
| 2 | Chat text between tool calls (progress updates) | Transcript only | ✓ | ✗ | Read from the transcript for the current turn. Short lines; the D tier is enough. Not checked today. |
| 3 | Markdown files in the repo (docs, specs, READMEs, ADRs, plans) | Working tree; git diff | ✓ | ✓ | Today: D tier on added lines of tracked files only. Recommended: also cover untracked files — a real gap today. `document-type-template` runs only here. Persisted prose has the longest life. |
| 4 | Markdown files outside the repo (plan files, memory files, `~/.claude`) | Disk; not in any git diff of the project | ✓ | ✓ | Via `PostToolUse` on `Write` and `Edit` where `file_path` ends `.md`. The git diff cannot see these paths; the tool input holds the new text directly. Not checked today. |
| 5 | Code comments | Source files; git diff | ✓ | ✓ | Added comment lines, extracted per language. Same I-tier threshold as #3. Comments are prose that persists, and most projects' own conventions limit them to cases needing judgement to write well — the same class of judgement the I tier checks. A comment extractor is a bounded addition to the script. Not checked today. |
| 6 | Commit messages | Argument to `git commit` in a `Bash` call | ✓ | ✗ | Via `PreToolUse` on `Bash` matching `git commit`; extracts `-m` text and `-F` file content. The Stop hook never sees the message, and the message is short. Not checked today. |
| 7 | PR titles and bodies, issue and PR comments | Argument to `gh pr create`, `gh pr comment`, `gh issue` in a `Bash` call | ✓ | ✓ | Same `PreToolUse` hook as #6, matcher on `gh pr` and `gh issue`. A PR body is often long enough for I-tier rules to matter. Not checked today. |
| 8 | Artifacts (HTML or markdown page) | File at `file_path`; published on `Artifact` publish | ✓ | ✓ | Via `PreToolUse` on `Artifact` with `action` publish. Lint `.md` directly; extract text nodes from `.html` first. The page has an audience. Today: checked only if the file is a tracked `.md` that changed. |
| 9 | Outbound messages via MCP (`Slack`, `Gmail` send, `Drive` create) | Tool input | ✓ | ✓ | Via `PreToolUse` on each send tool. Same reader class as a PR body; decided — both tiers apply to all three. |
| 10 | Sub-agent final messages and teammate messages | Returned to the parent agent, not the user | ✗ | ✗ | The parent rewrites or relays the content. The parent's own reply is row #1, and gets checked there instead. |
| 11 | Tool-call-only turn, empty reply | `last_assistant_message` is empty | ✗ | ✗ | The D-tier script exits 0 at once; the I-tier threshold check fails. No prose to check. |
| 12 | Code: identifiers, syntax, string literals, log messages, CLI help text | Source files | ✗ | ✗ | Out of scope by the spec. String literals follow the codebase. See open question 7 for user-facing strings. |
| 13 | Quoted text: tool output, error messages, file contents, another person's words | Inside #1 and #3 as fences and blockquotes | ✗ | ✗ | Excluded by the spec. The script already skips fences and blockquote lines; apply the same skip to `last_assistant_message` and the transcript. |

