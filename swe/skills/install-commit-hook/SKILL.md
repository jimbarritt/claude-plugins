---
name: install-commit-hook
description: Install swe's git pre-commit check in the current repository, so a commit with staged markdown needs a recorded clean lint
argument-hint: "[uninstall] [repo-path]"
allowed-tools: Bash, Read
disable-model-invocation: false
---

# install-commit-hook

Install a git `pre-commit` hook in one repository. Once installed, a
commit that stages a markdown file is blocked unless that file's exact
staged content has a `clean` verdict recorded by `/swe:lint-file`.

## Step 1: Read the arguments

`$ARGUMENTS` is empty, a repository path, the word `uninstall`, or
`uninstall` followed by a path. An empty argument means the current
project.

## Step 2: Run the installer

```
"$CLAUDE_PLUGIN_ROOT/scripts/install-commit-hook.sh" [--uninstall] [<repo-path>]
```

Exit 0 means the hook is in place (installed, updated, already current,
or removed for `--uninstall`). Exit 1 means nothing was changed: the
path is not a git repository, or a `pre-commit` hook and a
`pre-commit.local` file both already exist there, which the installer
never overwrites. Report the script's own lines as it printed them.

## Step 3: Report what the check does

State, in a few short lines: which file it installed and where; that a
staged markdown file then needs a `clean` record from `/swe:lint-file`
for its exact staged content; and that `.git/` is never cloned, so each
clone of this repository needs this command run again.

If the installer reported that it chained an existing hook, name the
file it moved (`pre-commit.local`) and say that hook still runs first,
unchanged.

## Step 4: Record the check's escape hatch

Say once, plainly: `git commit --no-verify` bypasses the check, and the
block message repeats that. Do not use it to work around a block
without saying so.
