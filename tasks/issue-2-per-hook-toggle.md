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

### 1. Two layers: a plugin default, and a project override under `.claude/`

Decided (see Discussion): both layers exist. The plugin's own
`config.json` gains a `hooks` block as the default for every project that
doesn't say otherwise. A project overrides it with a file under that
project's `.claude/` directory (path open, see Q2) — `.claude/` already
holds project-level Claude Code config, so this adds no new top-level
clutter to a consuming repo.

Plugin-root `config.json`:

```json
{
  "threshold_words": 60,
  "threshold_sentences": 4,
  "html_min_chars": 25,
  "fast_model": "claude-haiku-4-5-20251001",
  "model_call_timeout_seconds": 75,
  "hooks": {
    "stop": {
      "reply": true,
      "docs": true
    },
    "file": true,
    "bash": true,
    "artifact": true,
    "mcp-send": true
  }
}
```

Project `.claude/swe-lint.json`, only the keys a project wants to
override:

```json
{
  "hooks": {
    "stop": { "reply": false }
  }
}
```

Nested (decided at Q3): `stop` holds a `reply`/`docs` submap since it is
the only hook with sub-checks today; `file`, `bash`, `artifact`, and
`mcp-send` stay flat booleans, with room to nest any of them later if a
sub-check appears. Precedence: project value, if the key is present there,
else the plugin `config.json` value, else `true`. JSON throughout, so
`jq`, already required by every hook, reads both with no new dependency.

### 2. One helper in `_lib.sh`

Each hook passes its own `jq` path (`.hooks.stop.reply`, `.hooks.file`,
...), since the nested shape means the path differs per hook rather than
being a single flat key:

```sh
# Returns 1 when <jq-path> resolves to false: the project's
# .claude/swe-lint.json if it sets that path, else the plugin's own
# config.json. Any other case (missing file, missing path, bad JSON)
# resolves to true.
hook_enabled() {
  local jq_path="$1" cwd="$2"
  local project_file="$cwd/.claude/swe-lint.json"
  local val=""
  [ -n "$cwd" ] && [ -f "$project_file" ] && \
    val="$(jq -r "$jq_path // empty" "$project_file" 2>/dev/null)"
  if [ -z "$val" ]; then
    val="$(jq -r "$jq_path // empty" "$HERE/../config.json" 2>/dev/null)"
  fi
  [ "$val" != "false" ]
}
```

Each of `bash-check.sh`, `artifact-check.sh`, `mcp-send-check.sh`, and
`file-check.sh` adds one line after parsing `cwd`:

```sh
hook_enabled '.hooks.bash' "$CWD" || exit 0    # e.g. in bash-check.sh
```

`bash-check.sh`, `artifact-check.sh`, and `mcp-send-check.sh` do not read
`cwd` today; each gains the same `jq -r '.cwd // empty'` line the others
already have.

### 3. Split the Stop hook by flag, not by file

Keep one `stop-check.sh` and one `Stop` entry in `hooks.json`. Build `ARGS`
from the two flags:

- `stop.reply` on: add `--reply-file` and `--transcript` (when present).
- `stop.docs` on: add `--diff --added-only`.
- Both off: exit 0 before the worker starts.

One process, one `fetch-software-english-data.sh` call, one linter start
per turn, and the 2-second cap stays as is. A second script would double
each of those on every turn, for no gain: the linter already keeps the
sources separate internally (finding 4).

### 4. Close the coupling in `file-check.sh`

Change the tracked-`.md` skip from unconditional to: skip only when
`stop.docs` is enabled for this project. When `stop.docs` is off,
`file-check.sh` checks every `.md` it writes, tracked or not. No duplicate
report either way, and no gap.

Difference to note: `file-check.sh` runs per edit with `--run-inference`;
the Stop diff runs per turn, deterministic tier only. So a project that
turns `stop.docs` off and leaves `file` on gets a per-edit check with the
inference tier on its tracked markdown. That is a stricter check, not a
weaker one.

### 5. Documentation and version

- `README.md`: a new section, "Turn off a check for one project", with the
  JSON above and the config path per hook.
- `docs/agent-guide.md`: the hooks table gains a "Config key" column; a
  short paragraph under it states the file, the fail-open rule, and the
  `file-check.sh` takeover when `stop.docs` is off.
- `plugin.json`: bump to 0.2.0 (new user-facing config surface).

### Out of scope, unless Jim says otherwise

- A user-level override file (e.g. `~/.claude/software-english-lint/`).
- A `/swe-config` skill or `--show-config` flag to print effective config.
- Merging `.swe-ignore` into the new file.
- Per-rule or per-severity toggles.

## Questions for Jim

1. ~~**Config location.**~~ Decided: both layers. Plugin `config.json`
   holds the default `hooks` block; a project's `.claude/` file overrides
   it per key.
2. ~~**File name and path.**~~ Decided: `.claude/swe-lint.json`.
3. ~~**Key names.**~~ Decided: nested — `stop: { reply, docs }`, others flat.
4. ~~**`stop.docs` off.**~~ Decided: yes, `file-check.sh` takes over tracked
   markdown per edit.
5. ~~**Reply and transcript.**~~ Decided: one switch (`stop.reply`) for both.
6. **Version.** 0.2.0 (proposed) or 0.1.6?
7. **Tests.** No hook tests exist. Add a small shell test that feeds each
   hook a JSON input with and without the config file and asserts exit 0
   with empty stdout when disabled? Or leave testing manual?
8. **Issue thread.** Comment on #2 with a link to this plan once you
   approve it, or keep the discussion here until the fix lands?

## Discussion / decisions

- **Q1 (config location): both layers.** Jim does not want a file at every
  consuming repo's root by default. Decided: the plugin's own
  `config.json` carries the default `hooks` block (already global to the
  install); a project overrides individual keys via a file under that
  project's `.claude/` directory, since that directory is already the
  convention for project-level Claude Code config and adds no new
  top-level clutter.
- **Q2 (file name): `.claude/swe-lint.json`.** Matches the `.swe-` prefix
  `.swe-ignore` already uses.
- **Q3 (key names): nested.** Jim finds it more extensible. `stop` holds a
  `{ reply, docs }` submap; `file`, `bash`, `artifact`, `mcp-send` stay
  flat booleans, each free to nest later if it grows a sub-check. Each
  hook script now passes its own `jq` path to `hook_enabled` rather than a
  flat key.
- **Q4 (`stop.docs` off): `file-check.sh` takes over.** Confirmed.
- **Q5 (reply/transcript): one switch.** `stop.reply` covers both.

## Future work spun out of this task

Ideas raised while discussing Q4 and Q5, about when/how the reply and
inference checks run rather than the enable/disable surface this task
covers. Split out to separate tasks so they do not block finishing this
one:

- [future-inference-tier-rework.md](future-inference-tier-rework.md)
- [future-stop-reply-check.md](future-stop-reply-check.md)

## Next step

Jim answers the questions above. Then implement on `main` in
`software-english-lint/`.
