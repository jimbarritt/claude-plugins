#!/usr/bin/env bash
# Covers the pre-commit check: --force-inference and --record-lint-result
# on the linter (including the single-use nonce that binds one to the
# other, claude-plugins#10), swe/scripts/install-commit-hook.sh, and
# swe/git-hooks/pre-commit.sh itself.
# Deterministic and offline: every repository is a throwaway `git init`
# under a scratch directory, and the linter runs against a fixture copy
# of scripts/ carrying a small data/core-rules.toml (the real plugin
# checkout has no data/ until fetched; --force-inference needs a rule
# catalogue to reach the sources loop where a nonce is minted).  Never
# touches $HOME or the network.
#
# Run: swe/tests/commit_check_test.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$HERE/.."
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

# --- fixture plugin: scripts/ + config.json + a minimal rule catalogue ----
# --record-lint-result never reads data/ (it returns before the catalogue
# load), but --force-inference does, so the nonce-issuing tests below need
# one. Every rule id check_line() indexes directly must be present; the
# word lists are left empty so none of the scratch content below trips
# them by accident.
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

[[rules]]
id = "tone-judgement"
check = "model-judgement"
description = "Judge tone by hand."
TOML
LINTER="$FIXTURE/scripts/software_english_lint.py"

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

nonce_for() {  # nonce_for <repo> <file> -- prints the minted nonce, or nothing
  (cd "$1" && python3 "$LINTER" "$2" --force-inference --quiet-vocab 2>&1) \
    | sed -n 's/^swe-lint-nonce: //p' | tail -1
}

lint_and_record() {  # lint_and_record <repo> <file> <status> <findings>
  local repo="$1" file="$2" status="$3" findings="$4" nonce
  nonce="$(nonce_for "$repo" "$file")"
  (cd "$repo" && python3 "$LINTER" --record-lint-result "$status" --findings "$findings" --nonce "$nonce" "$file" >/dev/null 2>&1)
}

# --- --force-inference: nonce issuance -------------------------------------

REPO="$(new_repo recorder)"
echo "# hello" > "$REPO/a.md"
git -C "$REPO" add a.md

FI_OUT="$(cd "$REPO" && python3 "$LINTER" a.md --force-inference --quiet-vocab 2>&1)"
LAST_LINE="$(printf '%s\n' "$FI_OUT" | tail -1)"
case "$LAST_LINE" in
  "swe-lint-nonce: "*) assert "force-inference prints the nonce as its last line" 0 ;;
  *) assert "force-inference prints the nonce as its last line" 1 ;;
esac
NONCE1="${LAST_LINE#swe-lint-nonce: }"
if [[ "$NONCE1" =~ ^[0-9a-f]{32}$ ]]; then
  assert "the nonce is 32 lowercase hex characters" 0
else
  assert "the nonce is 32 lowercase hex characters" 1
fi

NONCE_STORE="$REPO/.git/swe/lint-nonces.json"
assert "the nonce store file exists" "$([ -f "$NONCE_STORE" ]; echo $?)"
EXPECT_BLOB="$(git -C "$REPO" hash-object -- a.md)"
STORE_BLOB="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]]['blob'])" "$NONCE_STORE" "$NONCE1" 2>/dev/null)"
assert "the nonce entry's blob matches git hash-object" "$([ "$STORE_BLOB" = "$EXPECT_BLOB" ]; echo $?)"
STORE_PATH="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]]['path'])" "$NONCE_STORE" "$NONCE1" 2>/dev/null)"
assert "the nonce entry's path is repo-relative" "$([ "$STORE_PATH" = "a.md" ]; echo $?)"

# --- --record-lint-result: recording with a valid nonce --------------------

OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$NONCE1" a.md 2>&1)"
assert "recorder exits 0 with a valid nonce" "$([ $? -eq 0 ]; echo $?)"
assert "recorder writes the ledger file" "$([ -f "$(ledger_path "$REPO")" ]; echo $?)"

ROW="$(tail -1 "$(ledger_path "$REPO")")"
GOT_BLOB="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['blob'])" "$ROW")"
assert "recorded blob matches git hash-object" "$([ "$GOT_BLOB" = "$EXPECT_BLOB" ]; echo $?)"
GOT_STATUS="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['status'])" "$ROW")"
assert "recorded status is clean" "$([ "$GOT_STATUS" = "clean" ]; echo $?)"
GOT_PATH="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['path'])" "$ROW")"
assert "recorded path is repo-relative" "$([ "$GOT_PATH" = "a.md" ]; echo $?)"

# --- nonce misuse: replay, no nonce, fabricated, stale, wrong file ---------

OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$NONCE1" a.md 2>&1)"
assert "replaying a spent nonce exits 4" "$([ $? -eq 4 ]; echo $?)"
LINES="$(wc -l < "$(ledger_path "$REPO")")"
assert "a replay appends no ledger row" "$([ "$LINES" -eq 1 ]; echo $?)"

echo "# second file" > "$REPO/skip3.md"
git -C "$REPO" add skip3.md
OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result clean --findings 0 skip3.md 2>&1)"
assert "recording with no --nonce given exits 4" "$([ $? -eq 4 ]; echo $?)"
LINES="$(wc -l < "$(ledger_path "$REPO")")"
assert "a no-nonce recording appends no ledger row" "$([ "$LINES" -eq 1 ]; echo $?)"

FAKE="0123456789abcdef0123456789abcdef"
OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$FAKE" skip3.md 2>&1)"
assert "a fabricated nonce exits 4" "$([ $? -eq 4 ]; echo $?)"

NONCE2="$(nonce_for "$REPO" skip3.md)"
echo "# second file, edited" > "$REPO/skip3.md"
OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$NONCE2" skip3.md 2>&1)"
assert "a nonce issued before an edit exits 4 (claude-plugins#10)" "$([ $? -eq 4 ]; echo $?)"
case "$OUT" in
  *"changed since"*) assert "the refusal names the content change" 0 ;;
  *) assert "the refusal names the content change" 1 ;;
esac
LINES="$(wc -l < "$(ledger_path "$REPO")")"
assert "a stale-blob recording appends no ledger row" "$([ "$LINES" -eq 1 ]; echo $?)"

echo "# other file" > "$REPO/b.md"
git -C "$REPO" add b.md
NONCE_A="$(nonce_for "$REPO" skip3.md)"
OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$NONCE_A" b.md 2>&1)"
assert "a nonce issued for a different file exits 4" "$([ $? -eq 4 ]; echo $?)"

# --- failed also needs a nonce, and cannot be flipped to clean on it -------

echo "# flip test" > "$REPO/flip.md"
git -C "$REPO" add flip.md
NONCE_FLIP="$(nonce_for "$REPO" flip.md)"
OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result failed --findings 2 --nonce "$NONCE_FLIP" flip.md 2>&1)"
assert "a failed verdict records with a valid nonce" "$([ $? -eq 0 ]; echo $?)"
OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$NONCE_FLIP" flip.md 2>&1)"
assert "flipping to clean on the same spent nonce exits 4" "$([ $? -eq 4 ]; echo $?)"

# --- a later --force-inference supersedes an earlier pending nonce ---------

echo "# superseded" > "$REPO/super.md"
git -C "$REPO" add super.md
NONCE_SUP_A="$(nonce_for "$REPO" super.md)"
NONCE_SUP_B="$(nonce_for "$REPO" super.md)"
OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$NONCE_SUP_A" super.md 2>&1)"
assert "a superseded nonce exits 4" "$([ $? -eq 4 ]; echo $?)"
OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$NONCE_SUP_B" super.md 2>&1)"
assert "the superseding nonce still records" "$([ $? -eq 0 ]; echo $?)"

# --- a nonce is issued even with no prose, or with deterministic errors ---

: > "$REPO/empty.md"
git -C "$REPO" add empty.md
FI_OUT="$(cd "$REPO" && python3 "$LINTER" empty.md --force-inference --quiet-vocab 2>&1)"
case "$FI_OUT" in
  *INFERENCE_ADVISED*) assert "a no-prose file prints no INFERENCE_ADVISED block" 1 ;;
  *) assert "a no-prose file prints no INFERENCE_ADVISED block" 0 ;;
esac
NONCE_EMPTY="$(printf '%s\n' "$FI_OUT" | sed -n 's/^swe-lint-nonce: //p' | tail -1)"
if [[ "$NONCE_EMPTY" =~ ^[0-9a-f]{32}$ ]]; then
  assert "a no-prose file still gets a nonce" 0
else
  assert "a no-prose file still gets a nonce" 1
fi
OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$NONCE_EMPTY" empty.md 2>&1)"
assert "a no-prose file's clean recording succeeds" "$([ $? -eq 0 ]; echo $?)"

printf '# has an em dash \xe2\x80\x94 right here\n' > "$REPO/dash.md"
git -C "$REPO" add dash.md
FI_OUT="$(cd "$REPO" && python3 "$LINTER" dash.md --force-inference --quiet-vocab 2>&1)"
FI_STATUS=$?
assert "a deterministically-failing file exits the lint status (1)" "$([ "$FI_STATUS" -eq 1 ]; echo $?)"
NONCE_DASH="$(printf '%s\n' "$FI_OUT" | sed -n 's/^swe-lint-nonce: //p' | tail -1)"
if [[ "$NONCE_DASH" =~ ^[0-9a-f]{32}$ ]]; then
  assert "a deterministically-failing file still gets a nonce" 0
else
  assert "a deterministically-failing file still gets a nonce" 1
fi
OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result failed --findings 1 --nonce "$NONCE_DASH" dash.md 2>&1)"
assert "failed records with the nonce from a deterministically-failing pass" "$([ $? -eq 0 ]; echo $?)"

# --- outside a git repository, and a .swe-ignore'd file: no nonce ----------

OUTSIDE_DIR="$(mktemp -d)"
echo "# outside" > "$OUTSIDE_DIR/x.md"
FI_OUT="$(cd "$OUTSIDE_DIR" && python3 "$LINTER" x.md --force-inference --quiet-vocab 2>&1)"
case "$FI_OUT" in
  *"no lint nonce issued"*) assert "outside a git repo: force-inference reports no nonce issued" 0 ;;
  *) assert "outside a git repo: force-inference reports no nonce issued" 1 ;;
esac
case "$FI_OUT" in
  *"swe-lint-nonce:"*) assert "outside a git repo: no nonce value is printed" 1 ;;
  *) assert "outside a git repo: no nonce value is printed" 0 ;;
esac
OUT="$(python3 "$LINTER" --record-lint-result clean "$OUTSIDE_DIR/x.md" 2>&1)"
STATUS=$?
assert "outside a git repo: recording with no nonce still exits 0" "$([ "$STATUS" -eq 0 ]; echo $?)"
assert "outside a git repo: no ledger written" "$([ ! -d "$OUTSIDE_DIR/.git" ]; echo $?)"
rm -rf "$OUTSIDE_DIR"

OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result clean a.md b.md 2>&1)"
assert "two positional files: exits 2" "$([ $? -eq 2 ]; echo $?)"

python3 "$LINTER" --record-lint-result maybe a.md >/dev/null 2>&1
assert "invalid status value: exits 2" "$([ $? -eq 2 ]; echo $?)"

echo "ignoreme.md" > "$REPO/.swe-ignore"
echo "# ignored content" > "$REPO/ignoreme.md"
git -C "$REPO" add .swe-ignore ignoreme.md
FI_OUT="$(cd "$REPO" && python3 "$LINTER" ignoreme.md --force-inference --quiet-vocab 2>&1)"
case "$FI_OUT" in
  *"swe-lint-nonce"*) assert ".swe-ignore'd file: no nonce line printed at all" 1 ;;
  *) assert ".swe-ignore'd file: no nonce line printed at all" 0 ;;
esac
rm -f "$REPO/.swe-ignore"
git -C "$REPO" rm -q --cached .swe-ignore >/dev/null 2>&1 || true

# --- a ledger write failure still consumes the nonce -----------------------

LEDGER="$(ledger_path "$REPO")"
rm -f "$LEDGER"
mkdir -p "$LEDGER"
echo "# ledger write failure" > "$REPO/ledgerfail.md"
git -C "$REPO" add ledgerfail.md
NONCE_LF="$(nonce_for "$REPO" ledgerfail.md)"
OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$NONCE_LF" ledgerfail.md 2>&1)"
assert "a ledger write failure exits 3" "$([ $? -eq 3 ]; echo $?)"
OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result clean --findings 0 --nonce "$NONCE_LF" ledgerfail.md 2>&1)"
assert "the nonce is already spent after a failed write (no retry with the same value)" "$([ $? -eq 4 ]; echo $?)"

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

lint_and_record "$REPO" a.md clean 0
commit "clean markdown"
assert "staged markdown with a matching clean row: commit succeeds" "$([ $? -eq 0 ]; echo $?)"

echo "# edited after lint" > "$REPO/a.md"
git -C "$REPO" add a.md
commit "edited after lint" 2>/dev/null
assert "content edited after the recorded pass: commit is blocked" "$([ $? -ne 0 ]; echo $?)"

OUT="$(cd "$REPO" && python3 "$LINTER" --record-lint-result clean --findings 0 a.md 2>&1)"
assert "recording with no fresh nonce after an edit exits 4" "$([ $? -eq 4 ]; echo $?)"
commit "still edited, no fresh record" 2>/dev/null
assert "with no fresh record: commit stays blocked" "$([ $? -ne 0 ]; echo $?)"

lint_and_record "$REPO" a.md failed 3
commit "failed status" 2>/dev/null
assert "a failed row for the exact staged content: commit is blocked" "$([ $? -ne 0 ]; echo $?)"

lint_and_record "$REPO" a.md clean 0
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
