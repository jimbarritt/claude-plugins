#!/usr/bin/env bash
# Covers swe/scripts/install-docs-hook.sh (tsk detection, the three install
# places, foreign-file refusal, uninstall) and swe/tsk-hooks/pre-docs-commit.sh
# itself (the deterministic-tier check, the Markdown filter, and finding the
# plugin's linter at run time via SWE_PLUGIN_ROOT or the git-common-dir
# pointer install-docs-hook.sh writes).
#
# Deterministic and offline: a fake `tsk` on PATH stands in for the real
# binary (claude-plugins#22's acceptance needs tsk 0.26.1, not assumed
# present here), and every repository is a throwaway `git init` under a
# scratch directory. Never touches the real $HOME or the network.
#
# Run: swe/tests/docs_hook_test.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$HERE/.."
INSTALLER="$PLUGIN_ROOT/scripts/install-docs-hook.sh"
HOOK_SOURCE="$PLUGIN_ROOT/tsk-hooks/pre-docs-commit.sh"

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

# --- a fake tsk, faithful enough to drive install-docs-hook.sh's own calls -
# (tsk --version, tsk ledger path, tsk ledger fetch, tsk config docs-hook),
# matching the real 0.26.1 behaviour this task verified by hand: a clone id
# lives at <git-common-dir>/tsk-clone-id, the clone's hook directory is a
# sibling of its ledger-db directory, and config docs-hook's precedence is
# TSK_DOCS_HOOK, then clone, then user, then repo.
FAKEBIN="$TMP/fakebin"
mkdir -p "$FAKEBIN"
export FAKE_TSK_STATE_DIR="$TMP/state"
cat > "$FAKEBIN/tsk" <<'FAKETSK'
#!/usr/bin/env bash
set -uo pipefail

clone_id_file() {
  local gcd
  gcd="$(git rev-parse --git-common-dir 2>/dev/null)" || return 1
  case "$gcd" in
    /*) ;;
    *) gcd="$PWD/$gcd" ;;
  esac
  printf '%s/tsk-clone-id' "$gcd"
}

case "${1:-}" in
  --version)
    echo "tsk ${FAKE_TSK_VERSION:-0.26.1}"
    exit 0
    ;;
esac

if [ "${1:-}" = "ledger" ] && [ "${2:-}" = "path" ]; then
  f="$(clone_id_file)" || { echo "error: not a git repository" >&2; exit 1; }
  if [ ! -s "$f" ]; then
    echo "error: this clone has no clone id yet ($f is absent or empty)." >&2
    echo "       Run tsk ledger fetch, which mints it." >&2
    exit 1
  fi
  echo "$FAKE_TSK_STATE_DIR/repos/$(cat "$f")/ledger-db"
  exit 0
fi

if [ "${1:-}" = "ledger" ] && [ "${2:-}" = "fetch" ]; then
  f="$(clone_id_file)" || { echo "error: not a git repository" >&2; exit 1; }
  if [ ! -s "$f" ]; then
    top="$(git rev-parse --show-toplevel)"
    printf '%s-%s' "$(basename "$top")" "$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')" > "$f"
  fi
  mkdir -p "$FAKE_TSK_STATE_DIR/repos/$(cat "$f")/ledger-db"
  echo "$FAKE_TSK_STATE_DIR/repos/$(cat "$f")/ledger-db"
  exit 0
fi

if [ "${1:-}" = "config" ] && [ "${2:-}" = "docs-hook" ]; then
  if [ -n "${TSK_DOCS_HOOK:-}" ] && [ -x "${TSK_DOCS_HOOK:-}" ]; then
    echo "docs hook: $TSK_DOCS_HOOK"
    echo "source: env (TSK_DOCS_HOOK)"
    exit 0
  fi
  f="$(clone_id_file 2>/dev/null)" || f=""
  if [ -n "$f" ] && [ -s "$f" ]; then
    cand="$FAKE_TSK_STATE_DIR/repos/$(cat "$f")/hooks/pre-docs-commit"
    if [ -x "$cand" ]; then
      echo "docs hook: $cand"
      echo "source: clone (<state>/repos/<clone-id>/hooks/pre-docs-commit)"
      exit 0
    fi
  fi
  cand="${XDG_CONFIG_HOME:-$HOME/.config}/tsk/hooks/pre-docs-commit"
  if [ -x "$cand" ]; then
    echo "docs hook: $cand"
    echo "source: user (<config>/tsk/hooks/pre-docs-commit)"
    exit 0
  fi
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || top=""
  if [ -n "$top" ]; then
    cand="$top/.tsk/hooks/pre-docs-commit"
    if [ -x "$cand" ]; then
      echo "docs hook: $cand"
      echo "source: repo (.tsk/hooks/pre-docs-commit)"
      exit 0
    fi
  fi
  echo "docs hook: none"
  exit 0
fi

exit 0
FAKETSK
chmod +x "$FAKEBIN/tsk"

export PATH="$FAKEBIN:$PATH"
export HOME="$TMP/home"
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$HOME"

new_repo() {  # new_repo <name>
  local dir="$TMP/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init
  echo "$dir"
}

# --- fixture plugin: scripts/ + config.json + a minimal rule catalogue ----
# Mirrors commit_check_test.sh's own fixture: every rule id check_line()
# indexes directly must be present, and the word lists stay empty so
# nothing in the scratch Markdown below trips them by accident.
FIXTURE="$TMP/plugin"
mkdir -p "$FIXTURE"
cp -r "$PLUGIN_ROOT/scripts" "$FIXTURE/scripts"
cp "$PLUGIN_ROOT/config.json" "$FIXTURE/config.json"
mkdir -p "$FIXTURE/data"
cat > "$FIXTURE/data/core-rules.toml" <<'TOML'
[exemptions]
skip_line_marker = "swe:ignore"

[[rules]]
id = "banned-word"
severity = "error"

[[rules]]
id = "no-em-dash"
character = "—"
severity = "error"

[[rules]]
id = "sentence-length"
max_words = 200
severity = "warning"

[[rules]]
id = "no-continuous-tense"
pattern = "\\b(is|are|was|were)\\s+(\\w+ing)\\b"
stoplist = []
severity = "warning"

[[rules]]
id = "no-perfect-tense-for-behaviour"
pattern = "\\b(has|have|had)\\s+(\\w+ed)\\b"
stoplist = []
severity = "warning"

[[rules]]
id = "anthropomorphism-fixed-list"
lookback_words = 3
word_list = []
severity = "warning"

[[rules]]
id = "abstract-location"
lookback_words = 3
word_list = []
severity = "warning"

[[rules]]
id = "vocabulary-membership"
severity = "warning"
TOML

# ============================================================================
# Detection
# ============================================================================

REPO="$(new_repo detect)"

DETECT_OUT="$(FAKE_TSK_VERSION=0.26.1 "$INSTALLER" --detect "$REPO")"
case "$DETECT_OUT" in
  "tsk"$'\t'"ok"$'\t'"0.26.1"*) assert "0.26.1 detects as ok" 0 ;;
  *) assert "0.26.1 detects as ok" 1 ;;
esac

DETECT_OUT="$(FAKE_TSK_VERSION=0.27.0 "$INSTALLER" --detect "$REPO")"
case "$DETECT_OUT" in
  "tsk"$'\t'"ok"$'\t'"0.27.0"*) assert "0.27.0 (newer minor) detects as ok" 0 ;;
  *) assert "0.27.0 (newer minor) detects as ok" 1 ;;
esac

DETECT_OUT="$(FAKE_TSK_VERSION=1.0.0 "$INSTALLER" --detect "$REPO")"
case "$DETECT_OUT" in
  "tsk"$'\t'"ok"$'\t'"1.0.0"*) assert "1.0.0 (newer major) detects as ok" 0 ;;
  *) assert "1.0.0 (newer major) detects as ok" 1 ;;
esac

DETECT_OUT="$(FAKE_TSK_VERSION=0.26.0 "$INSTALLER" --detect "$REPO")"
case "$DETECT_OUT" in
  "tsk"$'\t'"too-old"$'\t'"0.26.0") assert "0.26.0 detects as too-old" 0 ;;
  *) assert "0.26.0 detects as too-old" 1 ;;
esac

DETECT_OUT="$(FAKE_TSK_VERSION=0.25.9 "$INSTALLER" --detect "$REPO")"
case "$DETECT_OUT" in
  "tsk"$'\t'"too-old"$'\t'"0.25.9") assert "0.25.9 detects as too-old" 0 ;;
  *) assert "0.25.9 detects as too-old" 1 ;;
esac

EMPTYBIN="$TMP/emptybin"
mkdir -p "$EMPTYBIN"
DETECT_OUT="$(PATH="$EMPTYBIN:/usr/bin:/bin" "$INSTALLER" --detect "$REPO")"
assert "tsk absent from PATH detects as absent" "$([ "$DETECT_OUT" = $'tsk\tabsent' ]; echo $?)"

cat > "$FAKEBIN/tsk" <<'EOF'
#!/usr/bin/env bash
echo "garbage, no version here"
exit 0
EOF
chmod +x "$FAKEBIN/tsk"
DETECT_OUT="$("$INSTALLER" --detect "$REPO")"
case "$DETECT_OUT" in
  "tsk"$'\t'"unknown-version"*) assert "an unparseable --version detects as unknown-version" 0 ;;
  *) assert "an unparseable --version detects as unknown-version" 1 ;;
esac

# restore the real fake tsk (the garbage overwrite above replaced the file)
cat > "$FAKEBIN/tsk" <<'FAKETSK'
#!/usr/bin/env bash
set -uo pipefail

clone_id_file() {
  local gcd
  gcd="$(git rev-parse --git-common-dir 2>/dev/null)" || return 1
  case "$gcd" in
    /*) ;;
    *) gcd="$PWD/$gcd" ;;
  esac
  printf '%s/tsk-clone-id' "$gcd"
}

case "${1:-}" in
  --version)
    echo "tsk ${FAKE_TSK_VERSION:-0.26.1}"
    exit 0
    ;;
esac

if [ "${1:-}" = "ledger" ] && [ "${2:-}" = "path" ]; then
  f="$(clone_id_file)" || { echo "error: not a git repository" >&2; exit 1; }
  if [ ! -s "$f" ]; then
    echo "error: this clone has no clone id yet ($f is absent or empty)." >&2
    echo "       Run tsk ledger fetch, which mints it." >&2
    exit 1
  fi
  echo "$FAKE_TSK_STATE_DIR/repos/$(cat "$f")/ledger-db"
  exit 0
fi

if [ "${1:-}" = "ledger" ] && [ "${2:-}" = "fetch" ]; then
  f="$(clone_id_file)" || { echo "error: not a git repository" >&2; exit 1; }
  if [ ! -s "$f" ]; then
    top="$(git rev-parse --show-toplevel)"
    printf '%s-%s' "$(basename "$top")" "$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')" > "$f"
  fi
  mkdir -p "$FAKE_TSK_STATE_DIR/repos/$(cat "$f")/ledger-db"
  echo "$FAKE_TSK_STATE_DIR/repos/$(cat "$f")/ledger-db"
  exit 0
fi

if [ "${1:-}" = "config" ] && [ "${2:-}" = "docs-hook" ]; then
  if [ -n "${TSK_DOCS_HOOK:-}" ] && [ -x "${TSK_DOCS_HOOK:-}" ]; then
    echo "docs hook: $TSK_DOCS_HOOK"
    echo "source: env (TSK_DOCS_HOOK)"
    exit 0
  fi
  f="$(clone_id_file 2>/dev/null)" || f=""
  if [ -n "$f" ] && [ -s "$f" ]; then
    cand="$FAKE_TSK_STATE_DIR/repos/$(cat "$f")/hooks/pre-docs-commit"
    if [ -x "$cand" ]; then
      echo "docs hook: $cand"
      echo "source: clone (<state>/repos/<clone-id>/hooks/pre-docs-commit)"
      exit 0
    fi
  fi
  cand="${XDG_CONFIG_HOME:-$HOME/.config}/tsk/hooks/pre-docs-commit"
  if [ -x "$cand" ]; then
    echo "docs hook: $cand"
    echo "source: user (<config>/tsk/hooks/pre-docs-commit)"
    exit 0
  fi
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || top=""
  if [ -n "$top" ]; then
    cand="$top/.tsk/hooks/pre-docs-commit"
    if [ -x "$cand" ]; then
      echo "docs hook: $cand"
      echo "source: repo (.tsk/hooks/pre-docs-commit)"
      exit 0
    fi
  fi
  echo "docs hook: none"
  exit 0
fi

exit 0
FAKETSK
chmod +x "$FAKEBIN/tsk"

FAKE_TSK_VERSION=0.26.0 "$INSTALLER" --place user "$REPO" >/dev/null 2>&1
assert "--place with too-old tsk exits 3" "$([ $? -eq 3 ]; echo $?)"
PATH="$EMPTYBIN:/usr/bin:/bin" "$INSTALLER" --place user "$REPO" >/dev/null 2>&1
assert "--place with tsk absent exits 3" "$([ $? -eq 3 ]; echo $?)"
rm -f "$HOME/.config/tsk/hooks/pre-docs-commit" 2>/dev/null || true

# ============================================================================
# Install at the user place: fresh, idempotent re-install
# ============================================================================

REPO="$(new_repo user-install)"
USER_HOOK="$HOME/.config/tsk/hooks/pre-docs-commit"

OUT="$(SWE_PLUGIN_ROOT="$FIXTURE" CLAUDE_PLUGIN_ROOT="$FIXTURE" "$INSTALLER" --place user "$REPO")"
STATUS=$?
assert "fresh user install exits 0" "$([ "$STATUS" -eq 0 ]; echo $?)"
assert "the user hook is executable" "$([ -x "$USER_HOOK" ]; echo $?)"
bash -n "$USER_HOOK" 2>/dev/null
assert "the installed user hook passes bash -n" "$([ $? -eq 0 ]; echo $?)"
assert "the user hook carries the marker line" "$(grep -q '^# swe-docs-hook-version: ' "$USER_HOOK"; echo $?)"
case "$OUT" in
  *"tsk config docs-hook reports"*) assert "install output shows tsk config docs-hook" 0 ;;
  *) assert "install output shows tsk config docs-hook" 1 ;;
esac
assert "install writes this repo's plugin-root pointer" "$([ -f "$REPO/.git/swe/plugin-root" ]; echo $?)"
assert "the pointer names the fixture plugin root" "$([ "$(cat "$REPO/.git/swe/plugin-root")" = "$FIXTURE" ]; echo $?)"

BEFORE="$(cat "$USER_HOOK")"
OUT="$(CLAUDE_PLUGIN_ROOT="$FIXTURE" "$INSTALLER" --place user "$REPO")"
AFTER="$(cat "$USER_HOOK")"
case "$OUT" in
  *"already installed"*) assert "re-install reports already installed" 0 ;;
  *) assert "re-install reports already installed" 1 ;;
esac
assert "re-install leaves the hook byte-identical" "$([ "$BEFORE" = "$AFTER" ]; echo $?)"

# --- a foreign file is never overwritten or removed ------------------------

rm -f "$USER_HOOK"
cat > "$USER_HOOK" <<'EOF'
#!/bin/sh
echo FOREIGN
exit 0
EOF
chmod +x "$USER_HOOK"
FOREIGN_BEFORE="$(cat "$USER_HOOK")"
"$INSTALLER" --place user "$REPO" >/dev/null 2>/dev/null
assert "a foreign file at the place: --place exits 1" "$([ $? -eq 1 ]; echo $?)"
assert "the foreign file is left byte-identical" "$([ "$(cat "$USER_HOOK")" = "$FOREIGN_BEFORE" ]; echo $?)"
"$INSTALLER" --place user --uninstall "$REPO" >/dev/null 2>/dev/null
assert "uninstall on a foreign file exits 1" "$([ $? -eq 1 ]; echo $?)"
assert "uninstall leaves the foreign file in place" "$([ -f "$USER_HOOK" ]; echo $?)"
rm -f "$USER_HOOK"

# ============================================================================
# The repo place
# ============================================================================

REPO="$(new_repo repo-install)"
OUT="$(CLAUDE_PLUGIN_ROOT="$FIXTURE" "$INSTALLER" --place repo "$REPO")"
REPO_HOOK="$REPO/.tsk/hooks/pre-docs-commit"
assert "the repo hook lands at <toplevel>/.tsk/hooks/pre-docs-commit" "$([ -x "$REPO_HOOK" ]; echo $?)"
case "$OUT" in
  *"is not committed yet"*) assert "the repo place reminds to commit it" 0 ;;
  *) assert "the repo place reminds to commit it" 1 ;;
esac

# ============================================================================
# The clone place
# ============================================================================

REPO="$(new_repo clone-install)"

# No clone id yet: the clone place is unavailable.
DETECT_OUT="$("$INSTALLER" --detect "$REPO")"
case "$DETECT_OUT" in
  *"place"$'\t'"clone"$'\t'"-"$'\t'"unavailable"*) assert "with no clone id, the clone place is unavailable" 0 ;;
  *) assert "with no clone id, the clone place is unavailable" 1 ;;
esac
"$INSTALLER" --place clone "$REPO" >/dev/null 2>/dev/null
assert "--place clone with no clone id exits 1" "$([ $? -eq 1 ]; echo $?)"

# Mint a clone id the same way tsk ledger fetch does, then install there.
(cd "$REPO" && tsk ledger fetch >/dev/null 2>&1)
CLONE_ID="$(cat "$REPO/.git/tsk-clone-id")"
EXPECT_CLONE_HOOK="$FAKE_TSK_STATE_DIR/repos/$CLONE_ID/hooks/pre-docs-commit"

DETECT_OUT="$("$INSTALLER" --detect "$REPO")"
case "$DETECT_OUT" in
  *"place"$'\t'"clone"$'\t'"$EXPECT_CLONE_HOOK"$'\t'"absent"*)
    assert "with a clone id, the clone place path matches <state>/repos/<id>/hooks/pre-docs-commit" 0 ;;
  *) assert "with a clone id, the clone place path matches <state>/repos/<id>/hooks/pre-docs-commit" 1 ;;
esac

OUT="$(CLAUDE_PLUGIN_ROOT="$FIXTURE" "$INSTALLER" --place clone "$REPO")"
assert "the clone hook installs at the derived path" "$([ -x "$EXPECT_CLONE_HOOK" ]; echo $?)"
DETECT_OUT="$("$INSTALLER" --detect "$REPO")"
case "$DETECT_OUT" in
  *"place"$'\t'"clone"$'\t'"$EXPECT_CLONE_HOOK"$'\t'"swe 1"*)
    assert "after install, the clone place reports installed (swe 1)" 0 ;;
  *) assert "after install, the clone place reports installed (swe 1)" 1 ;;
esac

OUT="$("$INSTALLER" --place clone --uninstall "$REPO")"
assert "uninstall removes the swe-written clone hook" "$([ ! -e "$EXPECT_CLONE_HOOK" ]; echo $?)"

# ============================================================================
# The hook itself: deterministic-tier checking of Markdown arguments
# ============================================================================

DOCS_WORKTREE="$TMP/docs-worktree"
mkdir -p "$DOCS_WORKTREE"

printf '# a doc\n\nhas an em dash \xe2\x80\x94 right here\n' > "$DOCS_WORKTREE/a.md"
OUT="$(SWE_PLUGIN_ROOT="$FIXTURE" TSK_DOCS_WORKTREE="$DOCS_WORKTREE" "$HOOK_SOURCE" a.md 2>&1)"
STATUS=$?
assert "an em-dash document exits 1" "$([ "$STATUS" -eq 1 ]; echo $?)"
case "$OUT" in
  *"[no-em-dash]"*) assert "the failure output names the finding" 0 ;;
  *) assert "the failure output names the finding" 1 ;;
esac

printf '# a doc\n\nno dash here\n' > "$DOCS_WORKTREE/a.md"
OUT="$(SWE_PLUGIN_ROOT="$FIXTURE" TSK_DOCS_WORKTREE="$DOCS_WORKTREE" "$HOOK_SOURCE" a.md 2>&1)"
STATUS=$?
assert "the same path, fixed, exits 0" "$([ "$STATUS" -eq 0 ]; echo $?)"
case "$OUT" in
  *"documents check passed"*) assert "the fixed pass prints the passed line" 0 ;;
  *) assert "the fixed pass prints the passed line" 1 ;;
esac

echo "not markdown" > "$DOCS_WORKTREE/b.txt"
OUT="$(SWE_PLUGIN_ROOT="$FIXTURE" TSK_DOCS_WORKTREE="$DOCS_WORKTREE" "$HOOK_SOURCE" b.txt 2>&1)"
STATUS=$?
assert "a non-Markdown path exits 0" "$([ "$STATUS" -eq 0 ]; echo $?)"
assert "a non-Markdown path prints nothing" "$([ -z "$OUT" ]; echo $?)"

OUT="$(SWE_PLUGIN_ROOT="$FIXTURE" TSK_DOCS_WORKTREE="$DOCS_WORKTREE" "$HOOK_SOURCE" deleted.md 2>&1)"
STATUS=$?
assert "a path that does not exist exits 0" "$([ "$STATUS" -eq 0 ]; echo $?)"
assert "a path that does not exist prints nothing" "$([ -z "$OUT" ]; echo $?)"

OUT="$(SWE_PLUGIN_ROOT="$FIXTURE" TSK_DOCS_WORKTREE="$DOCS_WORKTREE" "$HOOK_SOURCE" 2>&1)"
assert "no arguments at all exits 0" "$([ $? -eq 0 ]; echo $?)"

# --- plugin-root discovery: SWE_PLUGIN_ROOT, then the git-common-dir pointer

printf '# a doc\n\nhas an em dash \xe2\x80\x94 right here\n' > "$DOCS_WORKTREE/a.md"

REPO="$(new_repo discovery)"
CLAUDE_PLUGIN_ROOT="$FIXTURE" "$INSTALLER" --place repo "$REPO" >/dev/null
POINTED_WORKTREE="$TMP/pointed-worktree"
git -C "$REPO" worktree add -q --detach "$POINTED_WORKTREE" >/dev/null 2>&1
printf '# a doc\n\nhas an em dash \xe2\x80\x94 right here\n' > "$POINTED_WORKTREE/a.md"

OUT="$(cd "$POINTED_WORKTREE" && env -u SWE_PLUGIN_ROOT TSK_DOCS_WORKTREE="$POINTED_WORKTREE" "$HOOK_SOURCE" a.md 2>&1)"
STATUS=$?
assert "with no SWE_PLUGIN_ROOT, the git-common-dir pointer still finds the linter" "$([ "$STATUS" -eq 1 ]; echo $?)"
case "$OUT" in
  *"[no-em-dash]"*) assert "the pointer-discovered linter reports the real finding" 0 ;;
  *) assert "the pointer-discovered linter reports the real finding" 1 ;;
esac

NO_POINTER_REPO="$(new_repo no-pointer)"
NO_POINTER_WORKTREE="$TMP/no-pointer-worktree"
git -C "$NO_POINTER_REPO" worktree add -q --detach "$NO_POINTER_WORKTREE" >/dev/null 2>&1
printf '# a doc\n\nhas an em dash \xe2\x80\x94 right here\n' > "$NO_POINTER_WORKTREE/a.md"
OUT="$(cd "$NO_POINTER_WORKTREE" && env -u SWE_PLUGIN_ROOT TSK_DOCS_WORKTREE="$NO_POINTER_WORKTREE" "$HOOK_SOURCE" a.md 2>&1)"
STATUS=$?
assert "with no pointer and no SWE_PLUGIN_ROOT: fails open, exit 0" "$([ "$STATUS" -eq 0 ]; echo $?)"
case "$OUT" in
  *"linter was not found"*) assert "the fail-open path names the reason" 0 ;;
  *) assert "the fail-open path names the reason" 1 ;;
esac

OUT="$(SWE_PLUGIN_ROOT=/nonexistent TSK_DOCS_WORKTREE="$DOCS_WORKTREE" "$HOOK_SOURCE" a.md 2>&1)"
STATUS=$?
assert "an invalid SWE_PLUGIN_ROOT falls through to the pointer or fails open" "$([ "$STATUS" -eq 0 ]; echo $?)"

# A PATH with git and bash but no python3 (python3 may live under more
# than one of /usr/bin, /usr/local/bin, and similar on a given platform,
# so excluding a directory is not reliable; a bare empty PATH would also
# fail to launch bash itself). Invoked as `bash <script>`, not through
# its own #!/usr/bin/env bash shebang, since a prefix PATH assignment on
# a simple command is used to search for that command too, and the
# shebang's own /usr/bin/env would need to be on this PATH as well.
NO_PY_BIN="$TMP/no-python-bin"
mkdir -p "$NO_PY_BIN"
ln -s "$(command -v git)" "$NO_PY_BIN/git"
ln -s "$(command -v bash)" "$NO_PY_BIN/bash"
OUT="$(PATH="$NO_PY_BIN" SWE_PLUGIN_ROOT="$FIXTURE" TSK_DOCS_WORKTREE="$DOCS_WORKTREE" bash "$HOOK_SOURCE" a.md 2>&1)"
STATUS=$?
assert "no python3 on PATH: fails open, exit 0" "$([ "$STATUS" -eq 0 ]; echo $?)"
case "$OUT" in
  *"python3 is not on PATH"*) assert "the no-python3 path names the reason" 0 ;;
  *) assert "the no-python3 path names the reason" 1 ;;
esac

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
