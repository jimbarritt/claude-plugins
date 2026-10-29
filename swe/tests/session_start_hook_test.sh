#!/usr/bin/env bash
# Covers install-commit-hook.sh's --session-start install/uninstall (the
# committed .claude/settings.json SessionStart entry and the
# .claude/hooks/swe-commit-hook.sh shim, claude-plugins#31), the
# plugin-root pointer refresh fix that --session-start needs to stay
# idempotent across plugin updates, and
# swe/session-start/swe-commit-hook.sh itself (plugin lookup order,
# fail-open behaviour).
#
# Deterministic and offline: every repository is a throwaway `git init`
# under a scratch directory, and CLAUDE_CONFIG_DIR always points under
# that scratch directory. Never touches the real $HOME or the network.
#
# Run: swe/tests/session_start_hook_test.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$HERE/.."
INSTALLER="$PLUGIN_ROOT/scripts/install-commit-hook.sh"
SHIM_SOURCE="$PLUGIN_ROOT/session-start/swe-commit-hook.sh"

PASS=0
FAIL=0

assert() {
  local desc="$1" ok="$2"
  if [ "$ok" -eq 0 ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $desc"
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

new_repo() {  # new_repo <name>
  local dir="$TMP/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init
  echo "$dir"
}

SS_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/swe-commit-hook.sh'
FOREIGN_GROUP='{"hooks":[{"type":"command","command":"tsk thread session-start --install-plugin claude-cli"}]}'

settings_has_cmd() {  # settings_has_cmd <file> -- exit 0 if our command is present
  jq -e --arg c "$SS_CMD" '(.hooks.SessionStart // []) | any(.[].hooks[]?; .command == $c)' "$1" >/dev/null 2>&1
}

# --- fresh repo, no .claude/ at all ----------------------------------------

REPO="$(new_repo fresh)"
OUT="$(cd "$REPO" && "$INSTALLER" --session-start . 2>&1)"
STATUS=$?
SETTINGS="$REPO/.claude/settings.json"
SHIM="$REPO/.claude/hooks/swe-commit-hook.sh"

assert "fresh repo: --session-start exits 0" "$([ "$STATUS" -eq 0 ]; echo $?)"
assert "fresh repo: settings.json was created" "$([ -f "$SETTINGS" ]; echo $?)"
jq empty "$SETTINGS" >/dev/null 2>&1
assert "fresh repo: settings.json is valid JSON" "$?"
settings_has_cmd "$SETTINGS"
assert "fresh repo: settings.json holds our SessionStart command" "$?"
GROUP_COUNT="$(jq '.hooks.SessionStart | length' "$SETTINGS")"
assert "fresh repo: exactly one SessionStart group" "$([ "$GROUP_COUNT" -eq 1 ]; echo $?)"
assert "fresh repo: the shim was installed" "$([ -x "$SHIM" ]; echo $?)"
bash -n "$SHIM" 2>/dev/null
assert "fresh repo: the installed shim passes bash -n" "$?"
grep -q "^# swe-session-start-version: " "$SHIM"
assert "fresh repo: the installed shim carries its version marker" "$?"

# --- a second run is a no-op (idempotent) ----------------------------------

BEFORE="$(cat "$SETTINGS")"
OUT="$(cd "$REPO" && "$INSTALLER" --session-start . 2>&1)"
AFTER="$(cat "$SETTINGS")"
case "$OUT" in
  *"already present"*) assert "second run reports the entry already present" 0 ;;
  *) assert "second run reports the entry already present" 1 ;;
esac
assert "second run leaves settings.json byte-identical" "$([ "$BEFORE" = "$AFTER" ]; echo $?)"

# --- an existing settings.json with a foreign group and other keys --------

REPO="$(new_repo foreign-group)"
mkdir -p "$REPO/.claude"
SETTINGS="$REPO/.claude/settings.json"
cat > "$SETTINGS" <<EOF
{
  "hooks": {"SessionStart": [$FOREIGN_GROUP]},
  "enabledPlugins": {"tsk@jimbarritt-claude-plugins": true}
}
EOF
BEFORE_FOREIGN="$(jq -S '.hooks.SessionStart[0], .enabledPlugins' "$SETTINGS")"
(cd "$REPO" && "$INSTALLER" --session-start . >/dev/null 2>&1)
AFTER_FOREIGN_GROUP="$(jq -S '.hooks.SessionStart[0]' "$SETTINGS")"
AFTER_ENABLED="$(jq -S '.enabledPlugins' "$SETTINGS")"
EXPECT_FOREIGN_GROUP="$(jq -S '.' <<< "$FOREIGN_GROUP")"
assert "foreign group is unchanged" "$([ "$AFTER_FOREIGN_GROUP" = "$EXPECT_FOREIGN_GROUP" ]; echo $?)"
EXPECT_ENABLED="$(jq -S '.' <<< '{"tsk@jimbarritt-claude-plugins": true}')"
assert "other top-level keys (enabledPlugins) are kept" "$([ "$AFTER_ENABLED" = "$EXPECT_ENABLED" ]; echo $?)"
GROUP_COUNT="$(jq '.hooks.SessionStart | length' "$SETTINGS")"
assert "our group is appended as its own element (now two groups)" "$([ "$GROUP_COUNT" -eq 2 ]; echo $?)"
settings_has_cmd "$SETTINGS"
assert "our command is present alongside the foreign one" "$?"

# --- invalid JSON is refused, untouched ------------------------------------

REPO="$(new_repo bad-json)"
mkdir -p "$REPO/.claude"
SETTINGS="$REPO/.claude/settings.json"
printf '{not valid json' > "$SETTINGS"
BEFORE="$(cat "$SETTINGS")"
(cd "$REPO" && "$INSTALLER" --session-start . >/dev/null 2>&1)
STATUS=$?
AFTER="$(cat "$SETTINGS")"
assert "invalid JSON: --session-start exits non-zero" "$([ "$STATUS" -ne 0 ]; echo $?)"
assert "invalid JSON: settings.json is left untouched" "$([ "$BEFORE" = "$AFTER" ]; echo $?)"

# --- a foreign, unmarked shim file is refused -------------------------------

REPO="$(new_repo foreign-shim)"
mkdir -p "$REPO/.claude/hooks"
SHIM="$REPO/.claude/hooks/swe-commit-hook.sh"
printf '#!/bin/sh\necho foreign\n' > "$SHIM"
BEFORE_SHIM="$(cat "$SHIM")"
SETTINGS="$REPO/.claude/settings.json"
(cd "$REPO" && "$INSTALLER" --session-start . >/dev/null 2>&1)
STATUS=$?
assert "foreign shim: --session-start exits non-zero" "$([ "$STATUS" -ne 0 ]; echo $?)"
assert "foreign shim: the file is left untouched" "$([ "$(cat "$SHIM")" = "$BEFORE_SHIM" ]; echo $?)"
assert "foreign shim: settings.json was not created" "$([ ! -e "$SETTINGS" ]; echo $?)"

# --- --uninstall --session-start removes only our group and the shim ------

REPO="$(new_repo uninstall-session-start)"
mkdir -p "$REPO/.claude"
SETTINGS="$REPO/.claude/settings.json"
cat > "$SETTINGS" <<EOF
{"hooks": {"SessionStart": [$FOREIGN_GROUP]}}
EOF
(cd "$REPO" && "$INSTALLER" --session-start . >/dev/null 2>&1)
SHIM="$REPO/.claude/hooks/swe-commit-hook.sh"
assert "setup: shim exists before uninstall" "$([ -f "$SHIM" ]; echo $?)"
(cd "$REPO" && "$INSTALLER" --uninstall --session-start . >/dev/null 2>&1)
settings_has_cmd "$SETTINGS"
assert "uninstall: our command is gone" "$([ $? -ne 0 ]; echo $?)"
FOREIGN_STILL="$(jq -e --arg c 'tsk thread session-start --install-plugin claude-cli' '(.hooks.SessionStart // []) | any(.[].hooks[]?; .command == $c)' "$SETTINGS" >/dev/null 2>&1; echo $?)"
assert "uninstall: the foreign group stays" "$([ "$FOREIGN_STILL" -eq 0 ]; echo $?)"
assert "uninstall: the shim file is removed" "$([ ! -e "$SHIM" ]; echo $?)"

REPO="$(new_repo uninstall-session-start-only-ours)"
mkdir -p "$REPO/.claude"
(cd "$REPO" && "$INSTALLER" --session-start . >/dev/null 2>&1)
SETTINGS="$REPO/.claude/settings.json"
(cd "$REPO" && "$INSTALLER" --uninstall --session-start . >/dev/null 2>&1)
HAS_HOOKS="$(jq 'has("hooks")' "$SETTINGS")"
assert "uninstall: with no foreign group left, hooks key is removed entirely" "$([ "$HAS_HOOKS" = "false" ]; echo $?)"

# --- --uninstall without --session-start keeps the committed entry, warns -

REPO="$(new_repo uninstall-without-session-start-flag)"
mkdir -p "$REPO/.claude"
(cd "$REPO" && "$INSTALLER" --session-start . >/dev/null 2>&1)
SETTINGS="$REPO/.claude/settings.json"
BEFORE="$(cat "$SETTINGS")"
OUT="$(cd "$REPO" && "$INSTALLER" --uninstall . 2>&1)"
AFTER="$(cat "$SETTINGS")"
assert "plain --uninstall leaves the committed session-start entry in place" "$([ "$BEFORE" = "$AFTER" ]; echo $?)"
case "$OUT" in
  *"still in"*"reinstall"*) assert "plain --uninstall warns that the entry will reinstall the hook" 0 ;;
  *) assert "plain --uninstall warns that the entry will reinstall the hook" 1 ;;
esac

# --- plugin-root pointer refresh on an already-current re-run --------------
# install-commit-hook.sh's own hook-version no-op path used to return
# before writing <git-common-dir>/swe/plugin-root, so a clone that relies
# on the session-start entry could keep a stale pointer across a plugin
# update that does not bump the git hook's own version.

REPO="$(new_repo pointer-refresh)"
(cd "$REPO" && CLAUDE_PLUGIN_ROOT=/fake/root/A "$INSTALLER" . >/dev/null 2>&1)
POINTER_A="$(cat "$REPO/.git/swe/plugin-root")"
assert "pointer refresh: first install writes root A" "$([ "$POINTER_A" = "/fake/root/A" ]; echo $?)"
HOOK_BEFORE="$(cat "$REPO/.git/hooks/pre-commit")"
(cd "$REPO" && CLAUDE_PLUGIN_ROOT=/fake/root/B "$INSTALLER" . >/dev/null 2>&1)
POINTER_B="$(cat "$REPO/.git/swe/plugin-root")"
HOOK_AFTER="$(cat "$REPO/.git/hooks/pre-commit")"
assert "pointer refresh: a same-version re-run still updates the pointer to root B" "$([ "$POINTER_B" = "/fake/root/B" ]; echo $?)"
assert "pointer refresh: the hook file itself is unchanged" "$([ "$HOOK_BEFORE" = "$HOOK_AFTER" ]; echo $?)"

# ============================================================================
# swe/session-start/swe-commit-hook.sh (the shim) itself
# ============================================================================

# --- SWE_PLUGIN_ROOT override installs the git hook, silent on a repeat ----

REPO="$(new_repo shim-override)"
OUT="$(CLAUDE_PROJECT_DIR="$REPO" SWE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$SHIM_SOURCE" 2>&1)"
STATUS=$?
assert "shim with SWE_PLUGIN_ROOT: exits 0" "$([ "$STATUS" -eq 0 ]; echo $?)"
assert "shim with SWE_PLUGIN_ROOT: installs the git hook" "$([ -x "$REPO/.git/hooks/pre-commit" ]; echo $?)"
OUT2="$(CLAUDE_PROJECT_DIR="$REPO" SWE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$SHIM_SOURCE" 2>&1)"
STATUS2=$?
assert "shim second run: exits 0" "$([ "$STATUS2" -eq 0 ]; echo $?)"
assert "shim second run: prints nothing (already installed, no-op)" "$([ -z "$OUT2" ]; echo $?)"

# --- installed_plugins.json lookup, preferring a project-path match -------

REPO="$(new_repo shim-installed-plugins)"
FAKE_CONFIG="$TMP/fake-config-installed"
mkdir -p "$FAKE_CONFIG/plugins/cache/someorg/swe/0.23.1"
cp -r "$PLUGIN_ROOT/scripts" "$FAKE_CONFIG/plugins/cache/someorg/swe/0.23.1/"
cp -r "$PLUGIN_ROOT/git-hooks" "$FAKE_CONFIG/plugins/cache/someorg/swe/0.23.1/"
cat > "$FAKE_CONFIG/plugins/installed_plugins.json" <<EOF
{"version": 2, "plugins": {"swe@someorg": [
  {"scope": "project", "installPath": "$FAKE_CONFIG/plugins/cache/someorg/swe/0.23.1", "projectPath": "$REPO"}
]}}
EOF
OUT="$(CLAUDE_PROJECT_DIR="$REPO" CLAUDE_CONFIG_DIR="$FAKE_CONFIG" bash "$SHIM_SOURCE" 2>&1)"
assert "shim via installed_plugins.json (project match): installs the git hook" "$([ -x "$REPO/.git/hooks/pre-commit" ]; echo $?)"

# --- cache-glob fallback, newest version wins ------------------------------

REPO="$(new_repo shim-cache-fallback)"
FAKE_CONFIG="$TMP/fake-config-cache"
mkdir -p "$FAKE_CONFIG/plugins/cache/someorg/swe/0.20.0" "$FAKE_CONFIG/plugins/cache/someorg/swe/0.23.1"
for v in 0.20.0 0.23.1; do
  cp -r "$PLUGIN_ROOT/scripts" "$FAKE_CONFIG/plugins/cache/someorg/swe/$v/"
  cp -r "$PLUGIN_ROOT/git-hooks" "$FAKE_CONFIG/plugins/cache/someorg/swe/$v/"
done
OUT="$(CLAUDE_PROJECT_DIR="$REPO" CLAUDE_CONFIG_DIR="$FAKE_CONFIG" bash "$SHIM_SOURCE" 2>&1)"
assert "shim via cache-glob fallback (no installed_plugins.json entry): installs the git hook" "$([ -x "$REPO/.git/hooks/pre-commit" ]; echo $?)"

# --- no plugin found anywhere: fail-open, one stderr line ------------------

REPO="$(new_repo shim-not-found)"
EMPTY_CONFIG="$TMP/empty-config"
mkdir -p "$EMPTY_CONFIG"
OUT="$(CLAUDE_PROJECT_DIR="$REPO" CLAUDE_CONFIG_DIR="$EMPTY_CONFIG" bash "$SHIM_SOURCE" 2>&1)"
STATUS=$?
assert "shim, no plugin found: exits 0 (fail-open)" "$([ "$STATUS" -eq 0 ]; echo $?)"
case "$OUT" in
  *"not installed"*) assert "shim, no plugin found: names the reason" 0 ;;
  *) assert "shim, no plugin found: names the reason" 1 ;;
esac
assert "shim, no plugin found: nothing was installed" "$([ ! -e "$REPO/.git/hooks/pre-commit" ]; echo $?)"

# --- outside a git repository: exit 0, silent -------------------------------

OUTSIDE="$TMP/not-a-git-repo"
mkdir -p "$OUTSIDE"
OUT="$(CLAUDE_PROJECT_DIR="$OUTSIDE" SWE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$SHIM_SOURCE" 2>&1)"
STATUS=$?
assert "shim outside a git repo: exits 0" "$([ "$STATUS" -eq 0 ]; echo $?)"
assert "shim outside a git repo: silent" "$([ -z "$OUT" ]; echo $?)"

# --- the installer itself refuses (foreign pre-commit + pre-commit.local): -
# the shim fails open and names the problem on stderr.

REPO="$(new_repo shim-installer-refuses)"
cat > "$REPO/.git/hooks/pre-commit" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$REPO/.git/hooks/pre-commit"
echo "placeholder" > "$REPO/.git/hooks/pre-commit.local"
OUT="$(CLAUDE_PROJECT_DIR="$REPO" SWE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$SHIM_SOURCE" 2>&1)"
STATUS=$?
assert "shim, installer refuses: still exits 0 (fail-open)" "$([ "$STATUS" -eq 0 ]; echo $?)"
case "$OUT" in
  *"Not overwriting either"*) assert "shim, installer refuses: names the installer's own refusal" 0 ;;
  *) assert "shim, installer refuses: names the installer's own refusal" 1 ;;
esac

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
