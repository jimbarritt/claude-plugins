#!/usr/bin/env bash
# Checks every SKILL.md and output-style frontmatter block in this plugin
# for the faults that make a strict YAML parser reject the whole file.
#
# Why this exists: Claude Code's frontmatter parser accepts a plain
# scalar holding ": " (a colon then a space); a strict YAML parser reads
# that as a second mapping separator and rejects the file, so the
# harness drops the skill with no error a user ever sees. GitHub Copilot
# CLI does exactly that. /swe:lint-file was invisible there from bd9edac
# (v0.7.0) to v0.10.1 for this one reason, while every other skill in
# the same plugin loaded normally.
#
# Deliberately not a full YAML parse: the plugin's own code depends on
# nothing outside the standard library, and PyYAML is not in it. These
# are the hazard classes that occur in a frontmatter value.
#
# Run: swe/tests/skill_frontmatter_test.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$HERE/.."

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

REPORT="$(python3 - "$PLUGIN_ROOT" <<'PYEOF'
import sys
from pathlib import Path

root = Path(sys.argv[1])
# A plain (unquoted) YAML scalar may not hold ": ", and may not open with
# an indicator character, or the document stops parsing there.
INDICATORS = set("[]{}&*!|>%@`,#")

targets = sorted(root.glob("skills/*/SKILL.md")) + sorted(root.glob("output-styles/*.md"))
if not targets:
    print("NONE\tno frontmatter files found at all")

for path in targets:
    rel = path.relative_to(root)
    text = path.read_text()
    if not text.startswith("---"):
        print(f"BAD\t{rel}\tno frontmatter block")
        continue
    parts = text.split("---", 2)
    if len(parts) < 3:
        print(f"BAD\t{rel}\tunterminated frontmatter block")
        continue

    keys = {}
    for number, raw in enumerate(parts[1].splitlines(), start=2):
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            print(f"BAD\t{rel}\tline {number}: no key, not valid frontmatter")
            continue
        key, _, value = line.partition(":")
        value = value.strip()
        keys[key.strip()] = value
        if not value:
            continue
        quoted = (value[0] == value[-1] == '"' and len(value) > 1) or (
            value[0] == value[-1] == "'" and len(value) > 1
        )
        if quoted:
            continue
        if ": " in value:
            print(f"BAD\t{rel}\tline {number}: unquoted '{key.strip()}' holds a colon and a space, which a strict YAML parser rejects")
        elif value[0] in INDICATORS:
            print(f"BAD\t{rel}\tline {number}: unquoted '{key.strip()}' opens with '{value[0]}', a YAML indicator")

    if "name" not in keys:
        print(f"BAD\t{rel}\tno name field")
    elif path.name == "SKILL.md" and keys["name"] != path.parent.name:
        print(f"BAD\t{rel}\tname '{keys['name']}' does not match its directory '{path.parent.name}'")
    if "description" not in keys:
        print(f"BAD\t{rel}\tno description field")

    print(f"SEEN\t{rel}")
PYEOF
)"

SEEN="$(printf '%s\n' "$REPORT" | grep -c '^SEEN')"
BADS="$(printf '%s\n' "$REPORT" | grep '^BAD' | cut -f2-)"

assert "every skill and output style has a frontmatter block to check" "$([ "$SEEN" -ge 4 ]; echo $?)"

if [ -n "$BADS" ]; then
  printf '%s\n' "$BADS" | while IFS=$'\t' read -r file reason; do
    echo "  $file: $reason"
  done
fi
assert "no frontmatter block has a fault a strict YAML parser would reject" "$([ -z "$BADS" ]; echo $?)"

# The exact regression this file exists for, asserted by name.
LINT_FILE="$PLUGIN_ROOT/skills/lint-file/SKILL.md"
DESC="$(sed -n 's/^description: //p' "$LINT_FILE" | head -1)"
case "$DESC" in
  *": "*) assert "lint-file's description holds no unquoted colon (bd9edac regression)" 1 ;;
  *) assert "lint-file's description holds no unquoted colon (bd9edac regression)" 0 ;;
esac

# Only run the authoritative check when the parser is installed.
if python3 -c "import yaml" 2>/dev/null; then
  python3 - "$PLUGIN_ROOT" <<'PYEOF'
import sys
from pathlib import Path
import yaml

root = Path(sys.argv[1])
failed = []
for path in sorted(root.glob("skills/*/SKILL.md")) + sorted(root.glob("output-styles/*.md")):
    parts = path.read_text().split("---", 2)
    if len(parts) < 3:
        continue
    try:
        yaml.safe_load(parts[1])
    except Exception as exc:
        failed.append(f"{path.relative_to(root)}: {str(exc).splitlines()[0]}")
for line in failed:
    print(f"  {line}")
raise SystemExit(1 if failed else 0)
PYEOF
  assert "every frontmatter block parses under a real strict YAML parser" "$?"
else
  echo "note: PyYAML is absent, so the strict-parser assertion was skipped; the stdlib checks above still ran."
fi

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
