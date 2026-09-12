#!/usr/bin/env python3
"""Software English deterministic-tier linter.

Checks Markdown prose against Software English's deterministic-tier
rules: closed vocabulary, banned-word substitutions, sentence length,
tense patterns, and a fixed anthropomorphism word list.

Vocabulary data and the rule catalogue are vendored under ../data/ from
the software-english repository (source of truth). Run
sync-from-software-english-repo.sh to refresh them. Rules are parsed
directly from core-rules.toml via Python's stdlib tomllib — nothing here
duplicates the catalogue by hand.

A finding has a severity, read from the catalogue. Only "error" findings
cause a non-zero exit (and so block the Stop hook, via stop-check.sh).
"warning" findings print but do not block — the vocabulary is a seed
set, not exhaustive yet, so vocabulary-membership stays a warning until
it is measured against real usage (see spec Implementation Notes).

A Markdown blockquote line (starts with ">") is not checked — it holds
someone else's words, quoted verbatim, not this writer's prose.
"""

import argparse
import re
import subprocess
import sys
import tomllib
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = HERE.parent / "data"

FENCE = re.compile(r"^\s*(```|~~~)")
INLINE_CODE = re.compile(r"`[^`]*`")
LINK_TARGET = re.compile(r"\]\([^)]*\)")
URL = re.compile(r"https?://\S+")
HTML_TAG = re.compile(r"<[^>]+>")
WORD = re.compile(r"[A-Za-z][A-Za-z']*")
SENTENCE_END = (".", "!", "?")

SYSTEM_PRONOUNS = {"it", "this", "that"}
# In vocabulary/structure.tsv for other reasons, but human referents, not
# system referents — must not gate an anthropomorphism/abstract-location
# check ("the user lives in London" is correct English).
HUMAN_SUBJECT_NOUNS = {"user"}

# A literal token (identifier, path, command, flag, acronym, version) is not
# checked against the vocabulary. Detected structurally, not by a list:
LITERAL_TOKEN = re.compile(
    r"^(?:"
    r"[A-Z]{2,}s?"          # acronym: HTTP, JSON, URLs
    r"|[A-Za-z]+[_./-][A-Za-z0-9_./-]*"  # snake_case, dotted, path-like
    r"|[a-z]+(?:[A-Z][a-z0-9]*)+"        # camelCase
    r"|v?\d+(?:\.\d+)+"                  # version number
    r")$"
)


def load_rule_catalogue():
    path = DATA / "core-rules.toml"
    with path.open("rb") as f:
        catalogue = tomllib.load(f)
    return {r["id"]: r for r in catalogue["rules"]}, catalogue["exemptions"]


def load_vocabulary():
    words = set()
    for name in ("operations.tsv", "structure.tsv", "qualities.tsv", "connectives.tsv"):
        path = DATA / name
        if not path.exists():
            continue
        for raw in path.read_text().splitlines()[1:]:
            if not raw.strip():
                continue
            word = raw.split("\t")[0].strip().lower()
            if word:
                words.add(word)
    return words


def load_structure_nouns():
    words = set()
    path = DATA / "structure.tsv"
    if not path.exists():
        return words
    for raw in path.read_text().splitlines()[1:]:
        if not raw.strip():
            continue
        word = raw.split("\t")[0].strip().lower()
        if word:
            words.add(word)
    return words


def load_banned():
    rules = []
    path = DATA / "banned.tsv"
    if not path.exists():
        return rules
    seen = set()
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        phrase = parts[0].strip()
        fix = parts[1].strip() if len(parts) > 1 else "rewrite"
        if not phrase or phrase.lower() in seen:
            continue
        seen.add(phrase.lower())
        pattern = re.compile(r"\b" + re.escape(phrase) + r"\b", re.IGNORECASE)
        rules.append((phrase, fix, pattern))
    return rules


def strip_noise(line):
    for pattern in (INLINE_CODE, LINK_TARGET, URL, HTML_TAG):
        line = pattern.sub(lambda m: " " * len(m.group(0)), line)
    return line


def prose_lines(text, exemptions, only_lines=None):
    skip_line_marker = exemptions["skip_line_marker"]
    in_fence = False
    for number, line in enumerate(text.splitlines(), start=1):
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if line.startswith("    ") or line.startswith("\t"):
            continue
        if line.lstrip().startswith(">"):
            continue
        if skip_line_marker in line:
            continue
        if only_lines is not None and number not in only_lines:
            continue
        yield number, strip_noise(line)


def lemma_candidates(word):
    yield word
    if word.endswith("ies") and len(word) > 3:
        yield word[:-3] + "y"
    if word.endswith("es") and len(word) > 2:
        yield word[:-2]
    if word.endswith("ed") and len(word) > 2:
        yield word[:-2]
        yield word[:-1]
    if word.endswith("s") and len(word) > 1:
        yield word[:-1]


def is_literal_token(word, line, start):
    if LITERAL_TOKEN.match(word):
        return True
    if word[0].isupper() and start != 0:
        preceding = line[:start].rstrip()
        if preceding and not preceding.endswith(SENTENCE_END):
            return True
    return False


def check_line(number, line, vocabulary, structure_nouns, banned_rules, rules, findings):
    banned_spans = []
    for phrase, fix, pattern in banned_rules:
        for m in pattern.finditer(line):
            banned_spans.append((m.start(), m.end()))
            findings.append((number, rules["banned-word"]["severity"], "banned-word", f'"{phrase}" -> {fix}'))

    max_words = rules["sentence-length"]["max_words"]
    for sentence in re.split(r"(?<=[.!?])\s+", line.strip()):
        words = WORD.findall(sentence)
        if len(words) > max_words:
            findings.append((number, rules["sentence-length"]["severity"], "sentence-length", f"{len(words)} words (max {max_words})"))

    continuous = rules["no-continuous-tense"]
    m = re.search(continuous["pattern"], line, re.IGNORECASE)
    if m and m.group(2).lower() not in continuous["stoplist"]:
        findings.append((number, continuous["severity"], "no-continuous-tense", m.group(0)))

    perfect = rules["no-perfect-tense-for-behaviour"]
    m = re.search(perfect["pattern"], line, re.IGNORECASE)
    if m and m.group(2).lower() not in perfect["stoplist"]:
        findings.append((number, perfect["severity"], "no-perfect-tense-for-behaviour", m.group(0)))

    lowered = line.lower()
    flagged_spans = list(banned_spans)
    for rule_id in ("anthropomorphism-fixed-list", "abstract-location"):
        rule = rules[rule_id]
        finding_id = "anthropomorphism" if rule_id == "anthropomorphism-fixed-list" else rule_id
        lookback_words = rule["lookback_words"]
        for phrase in rule["word_list"]:
            for pm in re.finditer(r"\b" + re.escape(phrase) + r"\b", lowered):
                if any(s <= pm.start() < e for s, e in flagged_spans):
                    continue
                window_start = max(0, pm.start() - 40)
                window = lowered[window_start:pm.start()]
                preceding_words = WORD.findall(window)[-lookback_words:]
                gate_nouns = structure_nouns - HUMAN_SUBJECT_NOUNS
                if any(w in gate_nouns or w in SYSTEM_PRONOUNS for w in preceding_words):
                    flagged_spans.append((pm.start(), pm.end()))
                    findings.append((number, rule["severity"], finding_id, f'"{phrase}"'))

    vocab_severity = rules["vocabulary-membership"]["severity"]
    for wm in WORD.finditer(line):
        word = wm.group(0)
        if len(word) < 2:
            continue
        if is_literal_token(word, line, wm.start()):
            continue
        lw = word.lower()
        if any(c in vocabulary for c in lemma_candidates(lw)):
            continue
        findings.append((number, vocab_severity, "vocabulary-membership", f'"{word}" not in approved vocabulary'))


def lint_text(text, vocabulary, structure_nouns, banned_rules, rules, exemptions, only_lines=None):
    if exemptions["skip_file_marker"] in text:
        return []
    findings = []
    for number, line in prose_lines(text, exemptions, only_lines):
        check_line(number, line, vocabulary, structure_nouns, banned_rules, rules, findings)
    return findings


def changed_line_numbers(path):
    out = subprocess.run(
        ["git", "diff", "--unified=0", "HEAD", "--", path],
        capture_output=True, text=True, check=False,
    )
    lines = set()
    hunk = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@")
    for raw in out.stdout.splitlines():
        m = hunk.match(raw)
        if not m:
            continue
        start = int(m.group(1))
        count = int(m.group(2)) if m.group(2) is not None else 1
        lines.update(range(start, start + count))
    return lines


def changed_markdown_files():
    out = subprocess.run(
        ["git", "diff", "--name-only", "HEAD"], capture_output=True, text=True, check=False
    )
    return [f for f in out.stdout.splitlines() if f.endswith(".md")]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("files", nargs="*")
    parser.add_argument("--diff", action="store_true")
    parser.add_argument("--added-only", action="store_true")
    parser.add_argument("--count", action="store_true")
    args = parser.parse_args()

    rules, exemptions = load_rule_catalogue()
    vocabulary = load_vocabulary()
    structure_nouns = load_structure_nouns()
    banned_rules = load_banned()

    files = args.files
    if args.diff:
        files = changed_markdown_files()

    if not files:
        print("No files to check.")
        return 0

    error_total = 0
    warning_total = 0
    for f in files:
        path = Path(f)
        if not path.exists():
            continue
        only_lines = changed_line_numbers(f) if (args.diff and args.added_only) else None
        findings = lint_text(path.read_text(), vocabulary, structure_nouns, banned_rules, rules, exemptions, only_lines)
        if args.count:
            error_total += sum(1 for _, sev, _, _ in findings if sev == "error")
            warning_total += sum(1 for _, sev, _, _ in findings if sev == "warning")
            continue
        for number, severity, rule, detail in findings:
            print(f"{f}:{number}: [{severity}] [{rule}] {detail}")
            if severity == "error":
                error_total += 1
            else:
                warning_total += 1

    if args.count:
        print(f"{error_total} errors, {warning_total} warnings across {len(files)} files")

    return 1 if error_total else 0


if __name__ == "__main__":
    sys.exit(main())
