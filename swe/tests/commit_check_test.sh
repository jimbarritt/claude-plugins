#!/usr/bin/env bash
# Covers the pre-commit check: --record-lint-result on the linter,
# swe/scripts/install-commit-hook.sh, and swe/git-hooks/pre-commit.sh
# itself.
# Deterministic and offline: every repository is a throwaway `git init`
# under a scratch directory, never fetches rule data (the deterministic
# tier's own fail-open path, covered separately by
# lint_fail_open_test.sh, is unaffected either way), and never touches
# $HOME.
#
# Run: swe/tests/commit_check_test.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$HERE/.."
LINTER="$PLUGIN_ROOT/scripts/software_english_lint.py"
INSTALLER="$PLUGIN_ROOT/scripts/install-commit-hook.sh"

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

ledger_path() {  # ledger_path <repo>
  echo "$1/.git/swe/lint-log.ndjson"
}

# --- --record-lint-result -------------------------------------------------

REPO="$(new_repo recorder)"
echo "# hello" > "$REPO/a.md"
git -C "$REPO" add a.md

OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result clean --findings 0 a.md 2>&1)"
STATUS=$?
assert "recorder exits 0" "$([ "$STATUS" -eq 0 ]; echo $?)"
assert "recorder writes the ledger file" "$([ -f "$(ledger_path "$REPO")" ]; echo $?)"

ROW="$(tail -1 "$(ledger_path "$REPO")")"
EXPECT_BLOB="$(git -C "$REPO" hash-object -- a.md)"
GOT_BLOB="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['blob'])" "$ROW")"
assert "recorded blob matches git hash-object" "$([ "$GOT_BLOB" = "$EXPECT_BLOB" ]; echo $?)"
GOT_STATUS="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['status'])" "$ROW")"
assert "recorded status is clean" "$([ "$GOT_STATUS" = "clean" ]; echo $?)"
GOT_PATH="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['path'])" "$ROW")"
assert "recorded path is repo-relative" "$([ "$GOT_PATH" = "a.md" ]; echo $?)"

(cd "$REPO" && python3 "$LINTER" --record-lint-result failed --findings 2 a.md >/dev/null 2>&1)
LINES="$(wc -l < "$(ledger_path "$REPO")")"
assert "recorder appends, does not rewrite" "$([ "$LINES" -eq 2 ]; echo $?)"

OUTSIDE_DIR="$(mktemp -d)"
OUT="$(python3 "$LINTER" --record-lint-result clean "$OUTSIDE_DIR/x.md" 2>&1)"
STATUS=$?
assert "outside a git repo: exits 0" "$([ "$STATUS" -eq 0 ]; echo $?)"
assert "outside a git repo: no ledger written" "$([ ! -d "$OUTSIDE_DIR/.git" ]; echo $?)"
rm -rf "$OUTSIDE_DIR"

OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result clean a.md b.md 2>&1)"
STATUS=$?
assert "two positional files: exits 2" "$([ "$STATUS" -eq 2 ]; echo $?)"

python3 "$LINTER" --record-lint-result maybe a.md >/dev/null 2>&1
assert "invalid status value: exits 2" "$([ $? -eq 2 ]; echo $?)"

# --- install-commit-hook.sh -----------------------------------------------

REPO="$(new_repo install-fresh)"
OUT="$(cd "$REPO" && "$INSTALLER" . 2>&1)"
STATUS=$?
HOOK="$REPO/.git/hooks/pre-commit"
assert "installer exits 0 on a fresh repo" "$([ "$STATUS" -eq 0 ]; echo $?)"
assert "installer places an executable pre-commit hook" "$([ -x "$HOOK" ]; echo $?)"
bash -n "$HOOK" 2>/dev/null
assert "installed hook passes bash -n" "$([ $? -eq 0 ]; echo $?)"
assert "installer records the plugin root" "$([ -f "$REPO/.git/swe/plugin-root" ]; echo $?)"

BEFORE="$(cat "$HOOK")"
OUT="$(cd "$REPO" && "$INSTALLER" . 2>&1)"
AFTER="$(cat "$HOOK")"
case "$OUT" in
  *"already installed"*) assert "re-install reports already installed" 0 ;;
  *) assert "re-install reports already installed" 1 ;;
esac
assert "re-install leaves the hook byte-identical" "$([ "$BEFORE" = "$AFTER" ]; echo $?)"

REPO="$(new_repo install-chain)"
cat > "$REPO/.git/hooks/pre-commit" <<'EOF'
#!/usr/bin/env bash
echo "FOREIGN"
exit 0
EOF
chmod +x "$REPO/.git/hooks/pre-commit"
FOREIGN_BEFORE="$(cat "$REPO/.git/hooks/pre-commit")"
(cd "$REPO" && "$INSTALLER" . >/dev/null 2>&1)
LOCAL="$REPO/.git/hooks/pre-commit.local"
assert "an existing hook is preserved as pre-commit.local" "$([ -f "$LOCAL" ]; echo $?)"
FOREIGN_AFTER="$(cat "$LOCAL")"
assert "the preserved hook is byte-identical to the original" "$([ "$FOREIGN_BEFORE" = "$FOREIGN_AFTER" ]; echo $?)"
assert "the preserved hook stays executable" "$([ -x "$LOCAL" ]; echo $?)"

echo x > "$REPO/code.py"
git -C "$REPO" add code.py
CHAIN_OUT="$(git -C "$REPO" -c user.email=t@t.com -c user.name=t commit -q -m chain 2>&1)"
case "$CHAIN_OUT" in
  *FOREIGN*) assert "the chained hook still runs on commit" 0 ;;
  *) assert "the chained hook still runs on commit" 1 ;;
esac

(cd "$REPO" && "$INSTALLER" --uninstall . >/dev/null 2>&1)
RESTORED="$(cat "$REPO/.git/hooks/pre-commit")"
assert "uninstall restores the original foreign hook" "$([ "$RESTORED" = "$FOREIGN_BEFORE" ]; echo $?)"
assert "uninstall removes pre-commit.local" "$([ ! -f "$LOCAL" ]; echo $?)"

REPO="$(new_repo install-refuse)"
cat > "$REPO/.git/hooks/pre-commit" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$REPO/.git/hooks/pre-commit"
echo "placeholder" > "$REPO/.git/hooks/pre-commit.local"
(cd "$REPO" && "$INSTALLER" . >/dev/null 2>&1)
assert "refuses to overwrite when pre-commit.local already exists" "$([ $? -eq 1 ]; echo $?)"
UNTOUCHED="$(cat "$REPO/.git/hooks/pre-commit.local")"
assert "leaves the pre-existing pre-commit.local untouched" "$([ "$UNTOUCHED" = "placeholder" ]; echo $?)"

# --- git-hooks/pre-commit.sh, exercised through a real commit ---------------

REPO="$(new_repo check)"
(cd "$REPO" && "$INSTALLER" . >/dev/null 2>&1)
commit() {  # commit <message> -- runs in $REPO, returns git's exit code
  git -C "$REPO" -c user.email=t@t.com -c user.name=t commit -q -m "$1"
}

echo x > "$REPO/code.py"
git -C "$REPO" add code.py
commit "no markdown staged"
assert "no staged markdown: commit succeeds" "$([ $? -eq 0 ]; echo $?)"

echo "# unlinted" > "$REPO/a.md"
git -C "$REPO" add a.md
commit "unlinted markdown" 2>/dev/null
assert "staged markdown with no ledger row: commit is blocked" "$([ $? -ne 0 ]; echo $?)"

(cd "$REPO" && python3 "$LINTER" --record-lint-result clean --findings 0 a.md >/dev/null 2>&1)
commit "clean markdown"
assert "staged markdown with a matching clean row: commit succeeds" "$([ $? -eq 0 ]; echo $?)"

echo "# edited after lint" > "$REPO/a.md"
git -C "$REPO" add a.md
commit "edited after lint" 2>/dev/null
assert "content edited after the recorded pass: commit is blocked" "$([ $? -ne 0 ]; echo $?)"

(cd "$REPO" && python3 "$LINTER" --record-lint-result failed --findings 3 a.md >/dev/null 2>&1)
commit "failed status" 2>/dev/null
assert "a failed row for the exact staged content: commit is blocked" "$([ $? -ne 0 ]; echo $?)"

(cd "$REPO" && python3 "$LINTER" --record-lint-result clean --findings 0 a.md >/dev/null 2>&1)
commit "clean after failed"
assert "a later clean row for the same content: commit succeeds" "$([ $? -eq 0 ]; echo $?)"

echo "# bypass me" > "$REPO/c.md"
git -C "$REPO" add c.md
git -C "$REPO" -c user.email=t@t.com -c user.name=t commit -q --no-verify -m bypass
assert "git commit --no-verify bypasses the check" "$([ $? -eq 0 ]; echo $?)"

echo "ignored.md" > "$REPO/.swe-ignore"
echo "# ignored" > "$REPO/ignored.md"
git -C "$REPO" add .swe-ignore ignored.md
commit "ignored file"
assert ".swe-ignore'd markdown needs no ledger row" "$([ $? -eq 0 ]; echo $?)"
rm -f "$REPO/.swe-ignore"
git -C "$REPO" rm -q --cached .swe-ignore >/dev/null 2>&1 || true

mkdir -p "$REPO/.claude"
echo '{"commit-check": {"enabled": false}}' > "$REPO/.claude/swe-lint.json"
echo "# should pass, check disabled" > "$REPO/disabled.md"
git -C "$REPO" add .claude/swe-lint.json disabled.md
commit "check disabled by project config"
assert "commit-check.enabled: false skips the check entirely" "$([ $? -eq 0 ]; echo $?)"

echo '{"commit-check": {"paths": ["*.rst"]}}' > "$REPO/.claude/swe-lint.json"
git -C "$REPO" add .claude/swe-lint.json
echo "# not checked, wrong extension" > "$REPO/other.md"
git -C "$REPO" add other.md
commit "paths filter excludes markdown"
assert "commit-check.paths narrowed away from *.md: markdown is not checked" "$([ $? -eq 0 ]; echo $?)"
rm -f "$REPO/.claude/swe-lint.json"
git -C "$REPO" add .claude/swe-lint.json 2>/dev/null || true
git -C "$REPO" rm -q --cached .claude/swe-lint.json >/dev/null 2>&1 || true

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
