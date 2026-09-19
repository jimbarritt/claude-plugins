# Issue #2: software-english-lint per-hook enable/disable

Issue: https://github.com/jimbarritt/claude-plugins/issues/2

## Summary

`hooks/hooks.json` in the `software-english-lint` plugin registers five
hooks (`Stop`, `PostToolUse` on Write|Edit, and three `PreToolUse` hooks for
Bash/Artifact/MCP-send) with no per-hook toggle in `config.json`. Installing
the plugin turns all five on, uniformly blocking.

A coupling makes a simple toggle insufficient: `hooks/stop-check.sh` does
two things in one pass: a chat-reply check and a tracked-markdown-diff
check. `hooks/file-check.sh` (`PostToolUse` on Write|Edit) deliberately
skips tracked `.md` files, deferring to the Stop hook's diff. So disabling
the Stop hook today removes both checks, not just the reply one.

## Ask (from the issue)

- Config-level enable/disable for each of the five hooks, independently.
- Within the Stop hook, independent control over the reply check and the
  tracked-markdown-diff check.

## Status

Proposal written. Awaiting Jim's review and answers to the questions below.

## Findings from reading the code

These constrain the design.

1. `config.json` lives at the plugin root and is read only by
   `scripts/software_english_lint.py` (`load_config()`). The plugin
   installs once into `~/.claude/` and runs in every project. A toggle in
   that file is therefore global to the user, not per project. The issue
   asks for a per-consuming-repo choice, so the toggle needs a per-project
   home.
2. The only per-project input today is `<cwd>/.swe-ignore`, read by the
   linter via `--cwd`. Every hook receives `cwd` in its JSON input (Stop,
   PreToolUse, PostToolUse all carry it), so each hook script can locate a
   project-level file with no new plumbing.
3. `hooks.json` is static. Claude Code offers no conditional registration,
   so "disable a hook" means the script starts, reads the toggle, and exits
   0 early with no output. `_lib.sh` already documents that exit 0 with no
   stdout is a no-op in both Claude Code and Copilot CLI.
4. In `stop-check.sh`, the reply check and the doc check are already
   separate linter sources in one invocation: `--reply-file` and
   `--transcript` give the conversational sources; `--diff --added-only`
   gives the changed-markdown sources. The split point is the `ARGS` array
   on line 37, not the linter itself.
5. `file-check.sh` skips a tracked in-tree `.md` file (lines 29-37) to avoid
   a duplicate report with the Stop hook's diff. If the Stop doc check is
   off, that skip leaves tracked markdown unchecked by anything.
6. The `one-point-at-a-time` plugin rule and the transcript check are both
   conversational. They go with the reply check, not the doc check.
7. No test harness exists for the hooks. Versions bump by hand in
   `plugin.json` (currently 0.1.5).

## Proposal

### 1. A per-project config file, read by every hook

Add `<project-root>/.swe-lint.json` (name open, see Q2). JSON, so `jq`,
already required by every hook, reads it with no new dependency. Absent
file, absent key, or unreadable `cwd`: the hook runs (fail open to
"enabled", matching current behaviour).

```json
{
  "hooks": {
    "stop-reply": true,
    "stop-docs": true,
    "file": true,
    "bash": true,
    "artifact": true,
    "mcp-send": true
  }
}
```

Six keys, not five: the Stop hook splits into two named checks. Only
`false` disables; any other value or a missing key means enabled.

### 2. One helper in `_lib.sh`

```sh
# Returns 1 when <cwd>/.swe-lint.json sets hooks.<key> to false.
# Any other case (no cwd, no file, no key, bad JSON) returns 0.
hook_enabled() {
  local key="$1" cwd="$2"
  [ -n "$cwd" ] && [ -f "$cwd/.swe-lint.json" ] || return 0
  [ "$(jq -r --arg k "$key" '.hooks[$k] // empty' "$cwd/.swe-lint.json" 2>/dev/null)" != "false" ]
}
```

Each of `bash-check.sh`, `artifact-check.sh`, `mcp-send-check.sh`, and
`file-check.sh` adds one line after parsing `cwd`:

```sh
hook_enabled <key> "$CWD" || exit 0
```

`bash-check.sh`, `artifact-check.sh`, and `mcp-send-check.sh` do not read
`cwd` today; each gains the same `jq -r '.cwd // empty'` line the others
already have.

### 3. Split the Stop hook by flag, not by file

Keep one `stop-check.sh` and one `Stop` entry in `hooks.json`. Build `ARGS`
from the two flags:

- `stop-reply` on: add `--reply-file` and `--transcript` (when present).
- `stop-docs` on: add `--diff --added-only`.
- Both off: exit 0 before the worker starts.

One process, one `fetch-software-english-data.sh` call, one linter start
per turn, and the 2-second cap stays as is. A second script would double
each of those on every turn, for no gain: the linter already keeps the
sources separate internally (finding 4).

### 4. Close the coupling in `file-check.sh`

Change the tracked-`.md` skip from unconditional to: skip only when
`stop-docs` is enabled for this project. When `stop-docs` is off,
`file-check.sh` checks every `.md` it writes, tracked or not. No duplicate
report either way, and no gap.

Difference to note: `file-check.sh` runs per edit with `--run-inference`;
the Stop diff runs per turn, deterministic tier only. So a project that
turns `stop-docs` off and leaves `file` on gets a per-edit check with the
inference tier on its tracked markdown. That is a stricter check, not a
weaker one.

### 5. Documentation and version

- `README.md`: a new section, "Turn off a check for one project", with the
  JSON above and the six key names.
- `docs/agent-guide.md`: the hooks table gains a "Config key" column; a
  short paragraph under it states the file, the fail-open rule, and the
  `file-check.sh` takeover when `stop-docs` is off.
- `plugin.json`: bump to 0.2.0 (new user-facing config surface).

### Out of scope, unless Jim says otherwise

- A user-level override file (e.g. `~/.claude/software-english-lint/`).
- A `/swe-config` skill or `--show-config` flag to print effective config.
- Merging `.swe-ignore` into the new file.
- Per-rule or per-severity toggles.

## Questions for Jim

1. **Config location.** Per-project file at the project root (proposed),
   or a plugin-root `config.json` entry (global to your install), or both
   with project overriding plugin? The issue reads as per-project; confirm.
2. **File name.** `.swe-lint.json` (proposed), `.swe-config.json`,
   `.software-english.json`, or something else? `.swe-ignore` already
   sets the `.swe-` prefix.
3. **Key names.** Flat `stop-reply`, `stop-docs`, `file`, `bash`,
   `artifact`, `mcp-send` (proposed, matching script stems), or nested
   `stop: { reply, docs }`?
4. **`stop-docs` off.** Should `file-check.sh` take over tracked markdown
   per edit (proposed), or should tracked markdown go unchecked in that
   case?
5. **Reply and transcript.** One switch for both conversational sources
   (proposed), or two?
6. **Version.** 0.2.0 (proposed) or 0.1.6?
7. **Tests.** No hook tests exist. Add a small shell test that feeds each
   hook a JSON input with and without the config file and asserts exit 0
   with empty stdout when disabled? Or leave testing manual?
8. **Issue thread.** Comment on #2 with a link to this plan once you
   approve it, or keep the discussion here until the fix lands?

## Discussion / decisions

(none yet)

## Next step

Jim answers the questions above. Then implement on `main` in
`software-english-lint/`.
