#!/usr/bin/env python3
"""Software English linter: deterministic tier plus a gated inference tier.

Checks prose against Software English's rules. Vocabulary data and the
rule catalogue are vendored under ../data/ from the software-english
repository (source of truth), fetched by fetch-software-english-data.sh
per the tag pinned in ../software-english.json. Rules are parsed directly
from core-rules.toml via Python's stdlib tomllib.

Deterministic-tier rules (vocabulary, banned words, tense patterns,
anthropomorphism, abstract-location) run on every source, every time, at
no cost beyond one Python process.

Inference-based rules (check == "model-judgement" in the catalogue) run
only when: every deterministic-tier finding across all sources given to
this invocation is absent, the caller is not already re-running after a
hook block (--stop-hook-active true), and the combined prose exceeds a
small size threshold (config.json) — see
~/.planning/claude-plugins/task9-enforcement-strategy.md for the design
this implements. When those hold, this script shells out to
`claude -p --safe-mode` with a fast model, asking it to judge only the
inference-based rules, and folds the result into the same report.
`--safe-mode` disables CLAUDE.md, hooks, skills, and plugins for that
one call — without it, the subprocess loads this project's own global
CLAUDE.md and mandatory session-start skill, which competes with the
prompt below and was found live to cause spurious timeouts.

A second, plugin-owned rule set lives in ../rules/plugin-rules.toml,
separate from the vendored catalogue: it governs interaction structure
(for example, raising more than one decision point in one reply) rather
than prose wording, so it is not part of the Software English spec. It
is added to the inference-tier prompt only for a conversational source
(--reply-file or --transcript), never for a file, a commit message, or
an artifact.

A finding has a severity, read from the catalogue. An "error"-severity
finding causes a non-zero exit, unless --stop-hook-active true was passed
(then the finding is still reported, but the exit stays 0, so a hook
built on this script never blocks more than once per turn).

A Markdown blockquote line (starts with ">") is not checked — it holds
someone else's words, quoted verbatim, not this writer's prose. The same
skip applies to a fenced or inline code span, at every source.
"""

import argparse
import datetime
import fnmatch
import html.parser
import json
import re
import shutil
import subprocess
import sys
import time
import tomllib
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
PLUGIN_ROOT = HERE.parent
DATA = PLUGIN_ROOT / "data"
CONFIG_PATH = PLUGIN_ROOT / "config.json"
PLUGIN_RULES_PATH = PLUGIN_ROOT / "rules" / "plugin-rules.toml"
FEEDBACK_LOG_PATH = Path.home() / ".claude" / "swe" / "feedback.jsonl"


def log_feedback_event(entry):
    """Append one JSON line to the feedback log. Read by /swe:send-feedback.

    Fails silently: a logging problem must never affect linting itself."""
    try:
        FEEDBACK_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with FEEDBACK_LOG_PATH.open("a") as f:
            f.write(json.dumps(entry) + "\n")
    except OSError:
        pass


def load_ignore_patterns(cwd):
    """Reads <cwd>/.swe-ignore: one glob pattern per line, gitignore-style.
    A blank line or a line starting with "#" is skipped. No negation, no
    directory-only trailing-slash handling: a small, real subset, not a
    full gitignore implementation."""
    path = Path(cwd) / ".swe-ignore"
    if not path.exists():
        return []
    patterns = []
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        patterns.append(line)
    return patterns


def is_path_ignored(file_path, cwd, patterns):
    """A pattern with a "/" matches the path relative to cwd; a pattern
    with no "/" matches the basename, at any depth (gitignore's rule)."""
    if not patterns:
        return False
    path = Path(file_path)
    try:
        rel = path.resolve().relative_to(Path(cwd).resolve())
        rel_str = rel.as_posix()
    except ValueError:
        rel_str = path.as_posix()
    name = path.name
    for pattern in patterns:
        if "/" in pattern:
            if fnmatch.fnmatch(rel_str, pattern):
                return True
        elif fnmatch.fnmatch(name, pattern):
            return True
    return False

FENCE = re.compile(r"^\s*(```|~~~)")
INLINE_CODE = re.compile(r"`[^`]*`")
LINK_TARGET = re.compile(r"\]\([^)]*\)")
URL = re.compile(r"https?://\S+")
HTML_TAG = re.compile(r"<[^>]+>")
WORD = re.compile(r"[A-Za-z][A-Za-z']*")
SENTENCE_END = (".", "!", "?")

SYSTEM_PRONOUNS = {"it", "this", "that"}
# In vocabulary/structure.tsv for other reasons, but human referents, not
# system referents. Must not trigger an anthropomorphism/abstract-location
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

# Line-comment prefix per file extension. Extend as new languages appear in
# the repos this plugin lints. Block comments are not extracted yet: no
# language in scope today (Python, Bash) uses them for real comments.
COMMENT_PREFIXES = {
    ".py": "#",
    ".sh": "#",
    ".bash": "#",
}


def load_config():
    with CONFIG_PATH.open() as f:
        return json.load(f)


def load_rule_catalogue():
    """Returns (rules_by_id, exemptions), or (None, None) when the rule
    catalogue hasn't been fetched yet (see fetch-software-english-data.sh).
    The caller must treat None as "skip this check" rather than lint with
    an empty catalogue: check_line() indexes fixed rule IDs directly
    (rules["no-em-dash"], and similar), so a missing entry there is a
    KeyError, not a soft "no rule configured" case."""
    path = DATA / "core-rules.toml"
    if not path.exists():
        return None, None
    with path.open("rb") as f:
        catalogue = tomllib.load(f)
    return {r["id"]: r for r in catalogue["rules"]}, catalogue["exemptions"]


def load_plugin_rules():
    """Interaction-structure rules owned by this plugin, not the Software
    English spec (SPEC governs prose wording; this governs reply shape)."""
    if not PLUGIN_RULES_PATH.exists():
        return {}
    with PLUGIN_RULES_PATH.open("rb") as f:
        catalogue = tomllib.load(f)
    return {r["id"]: r for r in catalogue["rules"]}


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

    em_dash = rules["no-em-dash"]["character"]
    if em_dash in line:
        for _ in range(line.count(em_dash)):
            findings.append((number, rules["no-em-dash"]["severity"], "no-em-dash", "replace with a period, a colon, or a comma"))

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


def untracked_markdown_files():
    out = subprocess.run(
        ["git", "ls-files", "--others", "--exclude-standard", "--", "*.md"],
        capture_output=True, text=True, check=False,
    )
    return [f for f in out.stdout.splitlines() if f.strip()]


class _TextNodeExtractor(html.parser.HTMLParser):
    """Pulls out text nodes, skipping <script> and <style> content."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self._skip_depth = 0
        self.nodes = []

    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style"):
            self._skip_depth += 1

    def handle_endtag(self, tag):
        if tag in ("script", "style") and self._skip_depth:
            self._skip_depth -= 1

    def handle_data(self, data):
        if self._skip_depth:
            return
        text = data.strip()
        if text:
            self.nodes.append(text)


def html_text_nodes(text, min_chars):
    parser = _TextNodeExtractor()
    parser.feed(text)
    return [node for node in parser.nodes if len(node) >= min_chars]


def _unquoted_prefix_index(line, prefix):
    """Index of prefix's first char outside a '...' or "..." span, else -1."""
    in_single = False
    in_double = False
    i = 0
    n = len(line)
    while i < n:
        ch = line[i]
        if in_single:
            if ch == "'" and line[i - 1] != "\\":
                in_single = False
        elif in_double:
            if ch == '"' and line[i - 1] != "\\":
                in_double = False
        elif ch == "'":
            in_single = True
        elif ch == '"':
            in_double = True
        elif line.startswith(prefix, i):
            return i
        i += 1
    return -1


def extract_comments(text, extension):
    """A prefix's own line, or a trailing comment after real code, per line."""
    prefix = COMMENT_PREFIXES.get(extension)
    if not prefix:
        return []
    out = []
    for number, raw in enumerate(text.splitlines(), start=1):
        idx = _unquoted_prefix_index(raw, prefix)
        if idx == -1:
            continue
        comment = raw[idx + len(prefix):].strip()
        if not comment:
            continue
        if idx == 0 and comment.startswith("!"):  # skip a shebang
            continue
        out.append((number, comment))
    return out


def threshold_pass(text, cfg):
    words = WORD.findall(text)
    sentences = [s for s in re.split(r"(?<=[.!?])\s+", text.strip()) if s.strip()]
    return len(words) > cfg["threshold_words"] or len(sentences) > cfg["threshold_sentences"]


def build_inference_prompt(prose, inference_rules):
    rule_lines = []
    for rule_id, rule in inference_rules.items():
        rule_lines.append(f"- {rule_id}: {rule['description']}")
    rules_block = "\n".join(rule_lines)
    return f"""You check prose against Software English's inference-based rules —
the ones needing judgement, not a fixed pattern. Here are the rules:

{rules_block}

Check ONLY these rules. Do not report vocabulary, banned words, tense
patterns, or the fixed anthropomorphism/abstract-location word lists —
those are checked separately, by a different mechanism.

Prose to check:
---
{prose}
---

Reply with ONLY a JSON object, no other text, in this exact shape:
{{"findings": [{{"rule_id": "...", "quote": "...", "fix": "..."}}]}}

An empty findings array means no fault found. "quote" is the exact
offending text, kept short. "fix" is a short instruction, not a full
rewrite."""


def run_inference(prose, inference_rules, cfg, source_label="unknown"):
    call_id = uuid.uuid4().hex
    log_feedback_event({
        "type": "inference_call_start",
        "call_id": call_id,
        "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "source": source_label,
        "rule_ids": sorted(inference_rules),
    })
    start_time = time.monotonic()

    def log_end(outcome):
        log_feedback_event({
            "type": "inference_call_end",
            "call_id": call_id,
            "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "outcome": outcome,
            "duration_ms": round((time.monotonic() - start_time) * 1000),
        })

    if not shutil.which("claude"):
        print("swe: 'claude' not on PATH, skipping inference tier", file=sys.stderr)
        log_end("no-claude-on-path")
        return []
    prompt = build_inference_prompt(prose, inference_rules)
    try:
        result = subprocess.run(
            ["claude", "-p", "--safe-mode", "--model", cfg["fast_model"]],
            input=prompt, text=True, capture_output=True,
            timeout=cfg["model_call_timeout_seconds"], check=False,
        )
    except subprocess.TimeoutExpired:
        print("swe: inference-tier model call timed out, skipping", file=sys.stderr)
        log_end("timeout")
        return []
    if result.returncode != 0:
        print(f"swe: inference-tier model call failed: {result.stderr.strip()[:200]}", file=sys.stderr)
        log_end("call-failed")
        return []
    raw = result.stdout.strip()
    start = raw.find("{")
    end = raw.rfind("}")
    if start == -1 or end == -1:
        print("swe: inference-tier response had no JSON, skipping", file=sys.stderr)
        log_end("no-json")
        return []
    try:
        parsed = json.loads(raw[start:end + 1])
    except json.JSONDecodeError:
        print("swe: inference-tier response was not valid JSON, skipping", file=sys.stderr)
        log_end("bad-json")
        return []
    out = []
    for item in parsed.get("findings", []):
        rule_id = item.get("rule_id", "")
        if rule_id not in inference_rules:
            continue
        quote = item.get("quote", "")
        fix = item.get("fix", "")
        severity = inference_rules[rule_id]["severity"]
        out.append((rule_id, severity, quote, fix))
    log_end("ok")
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("files", nargs="*")
    parser.add_argument("--diff", action="store_true")
    parser.add_argument("--added-only", action="store_true")
    parser.add_argument("--count", action="store_true")
    parser.add_argument("--text", action="store_true", help="read one prose source from stdin")
    parser.add_argument("--reply-file", help="path to a file holding last_assistant_message text")
    parser.add_argument("--transcript", help="path to the Stop hook transcript JSONL")
    parser.add_argument("--html-file", help="path to an HTML file; text nodes are extracted as prose")
    parser.add_argument("--source-label", default=None, help="label for --text's source in the report")
    parser.add_argument("--run-inference", action="store_true", help="run the inference tier if the deterministic tier is clean and the threshold passes")
    parser.add_argument("--force-inference", action="store_true", help="run the inference tier unconditionally: ignores the deterministic-clean gate and the length threshold (still skips on empty prose)")
    parser.add_argument("--stop-hook-active", default="false", choices=["true", "false"])
    parser.add_argument("--quiet-vocab", action="store_true", help="omit vocabulary-membership lines from the printed report (they never block; this only reduces noise)")
    parser.add_argument("--cwd", default=None, help="project root .swe-ignore is read from (defaults to the current directory)")
    args = parser.parse_args()

    rules, exemptions = load_rule_catalogue()
    if rules is None:
        print(
            "swe: no rule catalogue cached "
            "(data/core-rules.toml is missing). Run "
            "scripts/fetch-software-english-data.sh, or check network "
            "access; skipping this check."
        )
        return 0
    plugin_rules = load_plugin_rules()
    vocabulary = load_vocabulary()
    structure_nouns = load_structure_nouns()
    banned_rules = load_banned()
    cfg = load_config()
    cwd = args.cwd or Path.cwd()
    ignore_patterns = load_ignore_patterns(cwd)

    # sources: list of (label, findings, prose_text_for_threshold)
    sources = []

    file_list = list(args.files)
    if args.diff:
        file_list = changed_markdown_files() + untracked_markdown_files()
    file_list = [f for f in file_list if not is_path_ignored(f, cwd, ignore_patterns)]

    for f in file_list:
        path = Path(f)
        if not path.exists():
            continue
        ext = path.suffix
        text = path.read_text()
        if ext in COMMENT_PREFIXES:
            # A code file: only its comments are prose. The code itself is
            # never linted as if it were Markdown.
            findings = []
            comment_lines = []
            for number, comment in extract_comments(text, ext):
                check_line(number, comment, vocabulary, structure_nouns, banned_rules, rules, findings)
                comment_lines.append(comment)
            prose_for_threshold = "\n".join(comment_lines)
        else:
            only_lines = changed_line_numbers(f) if (args.diff and args.added_only and f in changed_markdown_files()) else None
            findings = lint_text(text, vocabulary, structure_nouns, banned_rules, rules, exemptions, only_lines)
            prose_for_threshold = "\n".join(line for _, line in prose_lines(text, exemptions, only_lines))
        sources.append((f, findings, prose_for_threshold))

    if args.text:
        text = sys.stdin.read()
        label = args.source_label or "text"
        findings = lint_text(text, vocabulary, structure_nouns, banned_rules, rules, exemptions)
        prose_for_threshold = "\n".join(line for _, line in prose_lines(text, exemptions))
        sources.append((label, findings, prose_for_threshold))

    if args.reply_file:
        path = Path(args.reply_file)
        text = path.read_text() if path.exists() else ""
        findings = lint_text(text, vocabulary, structure_nouns, banned_rules, rules, exemptions)
        prose_for_threshold = "\n".join(line for _, line in prose_lines(text, exemptions))
        sources.append(("reply", findings, prose_for_threshold))

    if args.transcript:
        path = Path(args.transcript)
        text = extract_transcript_reply_text(path) if path.exists() else ""
        findings = lint_text(text, vocabulary, structure_nouns, banned_rules, rules, exemptions)
        prose_for_threshold = "\n".join(line for _, line in prose_lines(text, exemptions))
        sources.append(("transcript", findings, prose_for_threshold))

    if args.html_file:
        path = Path(args.html_file)
        text = path.read_text() if path.exists() else ""
        nodes = html_text_nodes(text, cfg["html_min_chars"])
        synthetic = "\n".join(nodes)
        findings = lint_text(synthetic, vocabulary, structure_nouns, banned_rules, rules, exemptions)
        sources.append((args.html_file, findings, synthetic))

    if not sources:
        print("No sources to check.")
        return 0

    if args.count:
        error_total = sum(1 for _, findings, _ in sources for _, sev, _, _ in findings if sev == "error")
        warning_total = sum(1 for _, findings, _ in sources for _, sev, _, _ in findings if sev == "warning")
        print(f"{error_total} errors, {warning_total} warnings across {len(sources)} files")
        return 1 if error_total else 0

    error_total = 0
    warning_total = 0
    for label, findings, _ in sources:
        for number, severity, rule, detail in findings:
            if severity == "error":
                error_total += 1
            else:
                warning_total += 1
            if args.quiet_vocab and rule == "vocabulary-membership":
                continue
            print(f"{label}:{number}: [{severity}] [{rule}] {detail}")

    stop_hook_active = args.stop_hook_active == "true"

    gated_run = args.run_inference and error_total == 0 and not stop_hook_active
    if gated_run or args.force_inference:
        combined_prose = "\n".join(prose for _, _, prose in sources if prose.strip())
        if combined_prose.strip() and (args.force_inference or threshold_pass(combined_prose, cfg)):
            inference_rules = {rid: r for rid, r in rules.items() if r.get("check") == "model-judgement"}
            is_conversational = bool(args.reply_file or args.transcript)
            if is_conversational:
                inference_rules.update(plugin_rules)
            source_label = ",".join(label for label, _, _ in sources)
            i_findings = run_inference(combined_prose, inference_rules, cfg, source_label)
            for rule_id, severity, quote, fix in i_findings:
                print(f'{rule_id}: inference: "{quote}" — {fix}')
                if severity == "error":
                    error_total += 1
                else:
                    warning_total += 1

    if error_total and stop_hook_active:
        # Already re-running after a prior block this turn. Report, don't block again.
        return 0

    return 1 if error_total else 0


def extract_transcript_reply_text(path):
    """Assistant text blocks after the last user message in a Stop hook transcript.

    Two transcript shapes are supported, since both Claude Code and Copilot
    CLI populate `transcript_path` on their Stop-equivalent hook, but write
    a differently-shaped NDJSON file there:

    - Claude Code: {"message": {"role": ..., "content": [...] | str}}
    - Copilot CLI: {"type": "...", "data": {...}}, event types such as
      "user.message" and "assistant.turn_start"/"assistant.message"

    Copilot's exact field path for the assistant's final text is not
    documented publicly and is unverified against a real transcript file;
    the extraction below is a best-effort guess (data.content, else
    data.text, else data.message.content) that returns nothing rather
    than risk pulling in the wrong text as "the reply" on a shape it
    does not recognise. See claude-plugins#1.
    """
    lines = path.read_text().splitlines()
    parsed = []
    for raw in lines:
        try:
            parsed.append(json.loads(raw))
        except json.JSONDecodeError:
            parsed.append(None)

    if any(entry is not None and "message" in entry for entry in parsed):
        return _extract_claude_code_transcript_reply(parsed)
    if any(entry is not None and "type" in entry and "data" in entry for entry in parsed):
        return _extract_copilot_transcript_reply(parsed)
    return ""


def _extract_claude_code_transcript_reply(parsed):
    last_user_index = -1
    for i, entry in enumerate(parsed):
        if entry is None:
            continue
        if entry.get("message", {}).get("role") == "user":
            last_user_index = i
    texts = []
    for entry in parsed[last_user_index + 1:]:
        if entry is None:
            continue
        message = entry.get("message", {})
        if message.get("role") != "assistant":
            continue
        content = message.get("content", [])
        if isinstance(content, str):
            texts.append(content)
            continue
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                texts.append(block.get("text", ""))
    return "\n".join(texts)


def _extract_copilot_transcript_reply(parsed):
    last_user_index = -1
    for i, entry in enumerate(parsed):
        if entry is not None and entry.get("type") == "user.message":
            last_user_index = i
    texts = []
    for entry in parsed[last_user_index + 1:]:
        if entry is None:
            continue
        event_type = entry.get("type", "")
        if not event_type.startswith("assistant"):
            continue
        data = entry.get("data", {})
        if not isinstance(data, dict):
            continue
        text = data.get("content")
        if isinstance(text, str) and text:
            texts.append(text)
            continue
        text = data.get("text")
        if isinstance(text, str) and text:
            texts.append(text)
            continue
        message = data.get("message")
        if isinstance(message, dict):
            content = message.get("content")
            if isinstance(content, str) and content:
                texts.append(content)
    return "\n".join(texts)


if __name__ == "__main__":
    sys.exit(main())
