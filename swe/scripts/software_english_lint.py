#!/usr/bin/env python3
r"""Software English linter: deterministic tier plus a gated inference tier.

Checks prose against Software English's rules. Vocabulary data and the
rule catalogue are vendored under ../data/ from the software-english
repository (source of truth), fetched by fetch-software-english-data.sh
per the tag pinned in ../software-english.json. Rules are parsed directly
from core-rules.toml with the stdlib tomllib on Python 3.11 or later, or
with the copy of tomli in _vendor/ on an earlier Python, such as the
macOS system Python 3.9.

Deterministic-tier rules (vocabulary, banned words, tense patterns,
anthropomorphism, abstract-location) run on every source, every time, at
no cost beyond one Python process.

Inference-based rules (check == "model-judgement" in the catalogue) are
never run by this script. It has no model access of its own and never
spawns one: everything here runs inside a skill or a hook-dispatched
subagent, which already has a model attached, so shelling out to a
second one would only duplicate it. What this script does instead is
decide whether a fresh inference pass is worth doing, and if so, print
the applicable rules for the caller to judge the prose against
directly — as itself, with its own context, not an isolated call.

--advise-inference (used by the three PreToolUse hooks: bash, artifact,
mcp-send) only decides:
gated by inference_eligible() below, plus the deterministic tier being
clean this same invocation and --stop-hook-active not being true. When
eligible, it prints an INFERENCE_ADVISED block (see format_inference_rules()
and main()): one finding-shaped line per applicable rule
(`label:0: [warning] [rule-id] inference pending: ...`), plus one
`[inference-pending]` summary line stating how many rules are pending and
the source's real deterministic counts. Finding-shaped, not free text, so a
caller filtering output for finding lines (a `grep -E
":\s*\[(error|warning)\]"`, the natural thing to do on a long file) still
receives the rules rather than silently discarding the whole block
(claude-plugins#14); always at line 0 and severity "warning" so a pending
rule is never mistaken for a real finding at a real location. The hook
script reads that block and turns it into a non-blocking advisory hook
response telling Claude to dispatch a subagent to read the source and
judge it against those rules itself, then fix anything it finds. Nothing
in that path ever re-invokes this script for the judging step.

Right after a rule's own line, find_register_candidates() (claude-plugins#18)
can add `label:0: [warning] [rule-id] candidate at line N: ...` lines: a
cheap structural signal for no-cadence-device (a verbless fragment right
after a long sentence; two adjacent sentences with matching word-class
shape) or no-mechanical-repetition (a run of bold-lead-in bullet lists),
located without deciding whether the fault is real. The same dispatcher
(claude-plugins#19) also covers no-unanchored-reference and
no-unstated-presupposition: a definite noun phrase ("the"/"these"/"those"/
"both" plus an optional cardinal and up to two adjective-shaped modifiers,
then a head noun) whose head noun's lemma does not occur earlier in the
document, title and headings included. A cardinal inside the phrase ("the
two queues", "both options") routes it to no-unstated-presupposition
instead, since that rule's own trigger is a cardinal or completed-act
participle inside the phrase, not only an earlier noun. The same dispatcher
(software-english#21) also covers define-before-use (a noun occurring three
or more times, with at least one occurrence in a heading, outside the
approved vocabulary, and never followed by a definition clause) and
no-count-list-mismatch (a number word immediately before a short colon list
in the same sentence, whose item count differs from the stated number).
Also at line 0, never counted as a finding, and capped per rule per source;
the `[inference-pending]` summary line names the total when any exist. The
judging step above still reads the whole source: a candidate names one
place to check first, not every instance of the fault.

--force-inference (used by /swe:lint-file) prints the same block
unconditionally: no gate, no threshold, no throttle. It is the current
session itself that then judges the file directly, right where the
command was run, no subagent needed. It still skips on empty prose.
For a single named file inside a git repository, it also prints a
numbered worklist of the file's prose units (one per heading,
paragraph, top-level list item, and table; see prose_units()) as
further finding-shaped lines, each `[inference-unit]`, then
`swe-lint-units: M` naming the total, then mints and prints a
single-use nonce bound to the file's exact git blob id (see
--record-lint-result below), whether or not the rules block itself
printed: a no-prose file (M is 0) and a deterministically-failed file
both still need a nonce to record a verdict later. The worklist and
its total are not printed for a multi-file call: there is no nonce to
bind a total to there. Printed as the last lines of output, in that
order, so that piping this command's output through head, sed, or
grep loses the nonce first, then the total, not silently. A
findings-shaped grep now keeps the rules block and the worklist even
when it drops the nonce and total lines.

Neither flag can be combined with --count: --count returns its one-line
summary before the inference block would print and before a nonce would
mint, so the combination would always report "0 errors, 0 warnings" and
exit 0 regardless of prose content, the same one-tier-reported-as-clean
failure this issue is about. Rejected outright (exit 2) rather than
silently ignored.

The block's exit code still reflects the deterministic tier only: a
pending inference rule is never itself a finding, and a shell pipeline
like the one above reports the last command's (here, grep's) exit status
regardless, so a distinct "block printed, not yet judged" exit code
would not reach the caller this issue describes and was rejected for
that reason.

inference_eligible() throttles --advise-inference for a single named
file (the only source with a stable identity across repeated edits):
after any pass that printed the block (--advise-inference or
--force-inference alike), ~/.claude/swe/inference-state.json records
its word and sentence count, and a later --advise-inference call is
eligible again only once the count has grown by another
threshold_words/threshold_sentences (config.json) since that recorded
pass — not on every single edit, whether the prior pass found issues or
not. A non-file source (piped text, an HTML file) has no stable
identity across calls, so it always uses the plain, one-off absolute
threshold instead.

A second, plugin-owned rule set lives in ../rules/plugin-rules.toml,
separate from the vendored catalogue: it governs interaction structure
(for example, raising more than one decision point in one reply) rather
than prose wording, so it is not part of the Software English spec. It
is added to the printed inference-rules block only for a conversational
source (--reply-file or --transcript), never for a file, a commit
message, or an artifact. No automatic hook supplies a conversational
source today: --reply-file/--transcript remain available for a direct,
manual, or future call, same as the rest of this script's flags.

A finding has a severity, read from the catalogue. An "error"-severity
finding causes a non-zero exit, unless --stop-hook-active true was
passed (then the finding is still reported, but the exit stays 0). No
automatic caller passes this today; it remains available for a future
hook built the same way the old Stop hook was.

A Markdown blockquote line (starts with ">") is not checked — it holds
someone else's words, quoted verbatim, not this writer's prose. The same
skip applies to a fenced or inline code span, at every source.

--record-lint-result (used by /swe:lint-file's own Step 5, after it has
judged a file's inference-tier findings itself) is a wholly separate,
standalone mode: it lints nothing and reads no rule catalogue. It
appends one row to a repository-local ledger,
<git-common-dir>/swe/lint-log.ndjson, proving that one named file's
exact current content (identified by its git blob id, not a path or a
mtime) was judged, both tiers together, with a "clean" or "failed"
verdict. That ledger is read by the pre-commit hook installed by
/swe:install-commit-hook (swe/git-hooks/pre-commit), which blocks a
commit staging a markdown file unless its staged blob has a "clean"
row. This is deliberately not the same file as
~/.claude/swe/inference-state.json above: that file is global, per-user,
keyed by path, and answers "is a fresh advisory pass worth it"; the
ledger is per-repository, keyed by (path, blob), and answers "was this
exact content judged, and what was the verdict". See
swe/docs/agent-guide.md, "The commit check", for the full design.

--record-lint-result fails with exit 4 without a valid nonce: one
--force-inference minted for this exact file and blob, not already
used to record a verdict. This is a third state file,
<git-common-dir>/swe/lint-nonces.json, per-repository and short-lived
(an entry is created by --force-inference and deleted the moment
--record-lint-result consumes it, or superseded by a later
--force-inference pass on the same file). Its purpose is narrow: prove
that --force-inference ran on this exact content and its output
reached the caller, closing the shortcut where a verdict gets recorded
on an earlier, or wholly imagined, judgement of different content. It
cannot prove the caller judged the file against the printed rules in
Step 4; that step happens inside the model and is invisible to this
script by construction. A "failed" verdict needs a nonce too, for the
same reason: without that, a "failed" recording followed by "clean" on
the same nonce would let the second recording through unjudged. See
claude-plugins#10.

--record-lint-result also requires --units-judged: "N" (a claim of
full coverage, every unit on the worklist --force-inference printed
for this exact blob) or "N of M" (a declared partial, quoted on the
shell line). N or M not matching the total the nonce's entry
recorded fails with exit 4, the same as a missing, unknown, or stale
nonce, and consumes the nonce (unlike the nonce checks, which do
not): the mismatch itself proves the caller did not walk the real
worklist for this blob, so a fresh --force-inference pass is needed
regardless. A "clean" verdict with N less than M records as "partial"
in the ledger, not "clean"; a "failed" verdict always records as
"failed", whatever the coverage. Like the nonce, --units-judged proves
only that the caller saw the worklist's total for this blob, not that
it judged every unit on it: that judgement happens inside the model,
invisible to this script. See claude-plugins#20.
"""

import argparse
import datetime
import fnmatch
import html.parser
import json
import os
import re
import secrets
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

try:
    import tomllib
except ModuleNotFoundError:
    sys.path.insert(0, str(HERE / "_vendor"))
    import tomli as tomllib
PLUGIN_ROOT = HERE.parent
DATA = PLUGIN_ROOT / "data"
CONFIG_PATH = PLUGIN_ROOT / "config.json"
PLUGIN_RULES_PATH = PLUGIN_ROOT / "rules" / "plugin-rules.toml"
FETCHED_TAG_PATH = DATA / ".fetched-tag"
PIN_PATH = PLUGIN_ROOT / "software-english.json"
FETCH_SCRIPT = HERE / "fetch-software-english-data.sh"
INFERENCE_STATE_PATH = Path.home() / ".claude" / "swe" / "inference-state.json"


def load_inference_state():
    try:
        with INFERENCE_STATE_PATH.open() as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return {}


def save_inference_state(key, words, sentences):
    """Records the word/sentence count of the file --force-inference just
    checked, keyed by its resolved path. Fails silently: a logging problem
    must never affect linting itself."""
    if key is None:
        return
    try:
        INFERENCE_STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
        state = load_inference_state()
        state[key] = {
            "words": words,
            "sentences": sentences,
            "checked_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        }
        with INFERENCE_STATE_PATH.open("w") as f:
            json.dump(state, f)
    except OSError:
        pass


def inference_eligible(key, words, sentences, cfg):
    """True when a fresh --advise-inference pass is worth dispatching. A
    keyed (single-file) source compares growth against its last recorded
    --force-inference pass, once one exists; any other source, or a first
    pass, falls back to the plain absolute threshold."""
    if key is not None:
        entry = load_inference_state().get(key)
        if entry is not None:
            delta_words = words - entry.get("words", 0)
            delta_sentences = sentences - entry.get("sentences", 0)
            return delta_words > cfg["threshold_words"] or delta_sentences > cfg["threshold_sentences"]
    return words > cfg["threshold_words"] or sentences > cfg["threshold_sentences"]


LINT_LOG_RELPATH = Path("swe") / "lint-log.ndjson"


def _git(args, cwd):
    """Trimmed stdout, or None when git exits non-zero or is not on PATH."""
    try:
        result = subprocess.run(
            ["git", "-C", str(cwd)] + args, capture_output=True, text=True, check=False
        )
    except OSError:
        return None
    return result.stdout.strip() if result.returncode == 0 else None


def _spec_tag():
    try:
        with (PLUGIN_ROOT / "software-english.json").open() as f:
            return json.load(f).get("tag")
    except (OSError, json.JSONDecodeError):
        return None


def _plugin_version():
    try:
        with (PLUGIN_ROOT / ".claude-plugin" / "plugin.json").open() as f:
            return json.load(f).get("version")
    except (OSError, json.JSONDecodeError):
        return None


NONCE_STORE_RELPATH = Path("swe") / "lint-nonces.json"


def _repo_context(file_path):
    """Resolves file_path's repository identity: the toplevel, its
    repo-relative posix path, its current git blob id, the object-format
    algorithm, and the absolute git-common directory (where both the
    ledger and the nonce store live). Returns (ctx, None) on success, or
    (None, reason) with a human-readable reason for a caller to print
    ("...; nothing recorded." or "...; no nonce issued.", as it prefers)
    and treat as a no-op, not an error: a file outside any git
    repository, or outside its own repository's top level, is a case
    both record_lint_result() and issue_lint_nonce() must accept
    quietly, not fail on."""
    path = Path(file_path)
    toplevel = _git(["rev-parse", "--show-toplevel"], path.parent if path.parent.exists() else ".")
    if toplevel is None:
        return None, f"{file_path} is not inside a git repository"
    try:
        rel = path.resolve().relative_to(Path(toplevel).resolve())
    except ValueError:
        return None, f"{file_path} is outside its repository's top level"
    rel_str = rel.as_posix()

    blob = _git(["hash-object", "--", rel_str], toplevel)
    if blob is None:
        return None, f"could not compute a git blob id for {file_path}"

    algo = _git(["rev-parse", "--show-object-format"], toplevel) or "sha1"
    git_common_dir = _git(["rev-parse", "--git-common-dir"], toplevel) or ".git"
    git_common_path = Path(git_common_dir)
    if not git_common_path.is_absolute():
        git_common_path = Path(toplevel) / git_common_path

    return {
        "toplevel": toplevel,
        "rel": rel_str,
        "blob": blob,
        "algo": algo,
        "git_common": git_common_path,
    }, None


def _load_nonces(store_path):
    try:
        with store_path.open() as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return {}


def _save_nonces(store_path, nonces):
    """Raises OSError on failure; callers decide how to report it."""
    store_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = store_path.with_suffix(store_path.suffix + f".tmp{os.getpid()}")
    with tmp_path.open("w") as f:
        json.dump(nonces, f)
    os.replace(tmp_path, store_path)


def issue_lint_nonce(file_path, units_total):
    """Mints a single-use nonce proving --force-inference ran on
    file_path's exact current content, for --record-lint-result to
    demand back later. Returns (nonce, None) on success, or (None,
    reason) when none could be issued (outside a git repository, a
    ledger-write-style failure saving the store): the caller prints
    "no lint nonce issued" with that reason and moves on, since issuing
    a nonce never blocks linting itself.

    units_total, from prose_units() (claude-plugins#20), is recorded on
    the entry so --record-lint-result's --units-judged can be checked
    against the exact total printed for this blob, not a value the
    caller could otherwise invent.

    Any nonce already pending for this same (toplevel, rel) is dropped
    first: only the newest Step 3 run for a file stays valid, so a
    second --force-inference pass cannot be raced against a first."""
    ctx, reason = _repo_context(file_path)
    if ctx is None:
        return None, reason

    store_path = ctx["git_common"] / NONCE_STORE_RELPATH
    nonces = _load_nonces(store_path)
    nonces = {
        n: entry
        for n, entry in nonces.items()
        if not (entry.get("toplevel") == ctx["toplevel"] and entry.get("path") == ctx["rel"])
    }
    nonce = secrets.token_hex(16)
    nonces[nonce] = {
        "path": ctx["rel"],
        "toplevel": ctx["toplevel"],
        "blob": ctx["blob"],
        "algo": ctx["algo"],
        "units": units_total,
        "issued_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }
    try:
        _save_nonces(store_path, nonces)
    except OSError as exc:
        return None, f"could not write the nonce store: {exc}"
    return nonce, None


def parse_units_judged(value):
    """Parses --units-judged's value (claude-plugins#20): "N", a claim of
    full coverage, or "N of M", a declared partial (quoted on the shell
    line, since it is two words). Returns (judged, declared_total);
    declared_total is None for the bare "N" form. Raises ValueError, for
    main() to report as a malformed call (exit 2), on anything else,
    including N > M: that is nonsensical on its face, not a mismatch
    against a stored worklist total, which is record_lint_result()'s own
    exit-4 check instead."""
    m = UNITS_JUDGED.match(value)
    if not m:
        raise ValueError(f'--units-judged value {value!r} is not "N" or "N of M"')
    judged = int(m.group(1))
    declared_total = int(m.group(2)) if m.group(2) is not None else None
    if declared_total is not None and judged > declared_total:
        raise ValueError(f"--units-judged {judged} of {declared_total}: judged count exceeds its own declared total")
    return judged, declared_total


def _consume_nonce(store_path, nonces, nonce):
    """Deletes nonce from nonces and saves the store. Returns an exit code
    (3) on a write failure, or None on success, for the caller to check
    and return immediately."""
    del nonces[nonce]
    try:
        _save_nonces(store_path, nonces)
    except OSError as exc:
        print(f"swe: could not write the nonce store: {exc}")
        return 3
    return None


def record_lint_result(file_path, status, findings, recorded_by, nonce, units_judged, units_declared_total):
    """Appends one NDJSON row to this repository's lint ledger, proving
    that file_path's exact current content (its git blob id) was judged,
    both tiers together, with this verdict. A commit staging that same
    blob later is what the pre-commit hook checks this ledger for.

    Requires a nonce minted by a --force-inference run on this exact
    content (see issue_lint_nonce()), for both "clean" and "failed"
    verdicts: without this, --record-lint-result trusted its caller
    completely, so an agent could record "clean" on a stale, or wholly
    imagined, earlier judgement (claude-plugins#10). It also requires
    units_judged (parsed by main() from --units-judged; claude-plugins#20):
    N, a claim that every unit on the nonce's own worklist total was
    judged, or, with units_declared_total also given (the "N of M" form),
    a declared partial. Either must equal the total prose_units() found
    for this exact blob when the nonce was minted (entry["units"]), or the
    call fails the same way a stale or reused nonce does.

    The nonce is checked first, then the units claim against it; either
    one failing leaves the ledger untouched. A units mismatch also
    consumes the nonce, same as a successful record: it proves the
    caller did not walk the real worklist for this blob (stale output, a
    truncated read), so Step 3 has to run again regardless, and consuming
    stops a guess-and-retry loop against one nonce. The four nonce checks
    above it do not consume, unchanged from before this flag existed. The
    nonce is consumed before the ledger row is appended either way, so it
    is spent by its first use whether or not the write that follows
    succeeds; a write failure after that still needs a fresh
    --force-inference pass to retry, not a second call with the same
    value.

    A "clean" status with units_judged below the stored total records as
    "partial" instead: the issue's "a partial pass declares itself ...
    and the ledger records it as partial, not clean." A "failed" status
    always records as "failed", whatever the coverage: errors found in
    part of a file still make it failed.

    Prints a one-line result and returns a process exit code: 0 on a
    successful record (including "nothing to record" cases such as the
    file sitting outside a git repository, which need no ledger entry,
    nonce, or units claim), 3 when the ledger itself could not be
    written, 4 when the nonce is missing, unknown, already used, issued
    for a different file, or stale against the file's current content,
    or when units_judged is missing, the nonce predates this flag (minted
    by a plugin version before claude-plugins#20), or its value does not
    match the nonce's own stored total. Unlike save_inference_state(), a
    write failure here is never silent: a lost row turns into a commit
    blocked with no visible cause."""
    ctx, reason = _repo_context(file_path)
    if ctx is None:
        print(f"swe: {reason}; nothing recorded.")
        return 0

    store_path = ctx["git_common"] / NONCE_STORE_RELPATH
    nonces = _load_nonces(store_path)

    if nonce is None:
        print(
            f"swe: no --nonce given for {file_path}; run /swe:lint-file's "
            "Step 3 (--force-inference) first and pass the nonce it prints."
        )
        return 4
    entry = nonces.get(nonce)
    if entry is None:
        print(f"swe: nonce for {file_path} is unknown or already used; re-run /swe:lint-file.")
        return 4
    if entry.get("toplevel") != ctx["toplevel"] or entry.get("path") != ctx["rel"]:
        print(f"swe: nonce given was issued for a different file than {file_path}.")
        return 4
    if entry.get("blob") != ctx["blob"]:
        print(f"swe: {file_path} changed since its --force-inference pass; re-run /swe:lint-file.")
        return 4

    if units_judged is None:
        print(
            f"swe: no --units-judged given for {file_path}; pass the unit "
            'total Step 3 printed (swe-lint-units), or "N of M" for a '
            "partial pass."
        )
        return 4
    units_total = entry.get("units")
    if units_total is None:
        print(f"swe: nonce for {file_path} predates the unit worklist; re-run /swe:lint-file.")
        return 4
    if units_declared_total is not None and units_declared_total != units_total:
        rc = _consume_nonce(store_path, nonces, nonce)
        if rc is not None:
            return rc
        print(
            f"swe: --units-judged total {units_declared_total} does not "
            f"match the {units_total} unit(s) Step 3 printed for "
            f"{file_path} (blob {ctx['blob'][:12]}); re-run /swe:lint-file."
        )
        return 4
    if units_declared_total is None and units_judged != units_total:
        rc = _consume_nonce(store_path, nonces, nonce)
        if rc is not None:
            return rc
        print(
            f"swe: --units-judged {units_judged} does not match the "
            f"{units_total} unit(s) Step 3 printed for {file_path} (blob "
            f"{ctx['blob'][:12]}); pass \"{units_judged} of {units_total}\" "
            "for a partial pass, or re-run /swe:lint-file."
        )
        return 4

    rc = _consume_nonce(store_path, nonces, nonce)
    if rc is not None:
        return rc

    partial = units_judged < units_total
    recorded_status = "partial" if (status == "clean" and partial) else status

    row = {
        "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "path": ctx["rel"],
        "blob": ctx["blob"],
        "algo": ctx["algo"],
        "status": recorded_status,
        "tier": "both",
        "findings": findings,
        "rules_tag": _spec_tag(),
        "plugin_version": _plugin_version(),
        "recorded_by": recorded_by,
        "units_total": units_total,
        "units_judged": units_judged,
    }

    log_path = ctx["git_common"] / LINT_LOG_RELPATH
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("a") as f:
            f.write(json.dumps(row) + "\n")
    except OSError as exc:
        print(f"swe: could not write the lint log: {exc}")
        return 3

    print(
        f"swe: recorded {recorded_status} ({units_judged} of {units_total} "
        f"units) for {ctx['rel']} (blob {ctx['blob'][:12]}) in {log_path}"
    )
    return 0


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
# software-english#27: a code span's own text reads as code, and keeps the
# no-em-dash exemption, when it has no space or shows one of these signs:
# "::", "->", a function call ("f("), a path or dotted name ("a/b", "a.b"),
# or a flag ("--title", "-x").
CODE_SPAN_CODE_SIGNAL = re.compile(r"::|->|\w\(|\w[/.]\w|(?:^|\s)--?[A-Za-z]")
CODE_SPAN_TEXT_RATIO = 0.8
LINK_TARGET = re.compile(r"\]\([^)]*\)")
URL = re.compile(r"https?://\S+")
HTML_TAG = re.compile(r"<[^>]+>")
# claude-plugins#27: the --force-inference worklist's own rendering, read by
# readable_line() below. One alternation, so a link inside a code span is
# left alone.
READABLE_SPAN = re.compile(r"(`[^`]*`)|!?\[([^\]]*)\]\(([^)]*)\)")
WORD = re.compile(r"[A-Za-z][A-Za-z']*")
# Like WORD, but a whole code span counts as one token: the no-cadence-device
# locator (claude-plugins#25) needs a code-span subject to count as a noun
# phrase, not to vanish the way strip_noise()'s blanking makes it for every
# other rule.
CADENCE_TOKEN = re.compile(r"`[^`]*`|[A-Za-z][A-Za-z']*")
SENTENCE_END = (".", "!", "?")

SYSTEM_PRONOUNS = {"it", "this", "that"}
# In vocabulary/structure.tsv for other reasons, but human referents, not
# system referents. Applies to the system-subject gate only (the default,
# used by abstract-location): "the user lives in London" is correct
# English. A rule with subject_gate = "not-human-subject" reads its own
# human_referents list from the catalogue instead.
HUMAN_SUBJECT_NOUNS = {"user"}
# The not-human-subject gate does not look back across a clause boundary.
CLAUSE_BREAK = re.compile(r"[.!?;:,(]")

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

# --- register-rule candidate detectors (claude-plugins#18, #19) ------------
#
# These locate structural signals for four inference-based (model-judgement)
# rules, no-cadence-device, no-mechanical-repetition, no-unanchored-reference,
# and no-unstated-presupposition, without deciding the fault themselves: see
# find_register_candidates() and its callers.

BULLET = re.compile(r"^(\s*)(?:[-*+]|\d+[.)])\s+(.*)$")
HEADING = re.compile(r"^\s{0,3}#{1,6}\s")
TABLE_ROW = re.compile(r"^\s*\|")
HR_LINE = re.compile(r"^\s*([-*_])(?:\s*\1){2,}\s*$")

# A sentence boundary: punctuation, optional closing quote/bracket, then
# whitespace, only where the next sentence starts with a capital (through
# an optional opening quote/bracket/emphasis marker first). The capital
# requirement is what keeps "e.g. this", "SPEC §8. states", and similar
# abbreviation- or reference-like periods from being read as a boundary.
SENTENCE_BREAK = re.compile(r"(?<=[.!?])[\"')\]]*\s+(?=[\"'(\[*_]*[A-Z])")

CONTRACTION_SUFFIX = re.compile(r"(n't|'s|'re|'ll|'ve|'d|'m)$", re.IGNORECASE)

AUXILIARY_VERBS = {
    "be", "is", "are", "was", "were", "am", "been", "being",
    "have", "has", "had", "do", "does", "did",
    "will", "would", "shall", "should", "can", "could", "may", "might", "must", "cannot",
}

# Base-form verbs common in this repo's own technical prose but absent from
# vocabulary/operations.tsv (which lists domain operations, not every verb
# English has). Without this set, a closed-list verb check false-positives
# on ordinary sentences ("A PR description states those facts."), since
# operations.tsv plus AUXILIARY_VERBS alone misses "states". Calibrated
# against this repo's and software-english's own real prose (claude-plugins#18).
COMMON_VERBS = frozenset({
    "see", "state", "name", "live", "know", "exit", "take", "make", "hold", "keep",
    "cover", "define", "record", "mean", "apply", "follow", "describe", "give",
    "go", "come", "list", "mark", "own", "print", "pass", "block", "skip", "cost",
    "emit", "produce", "handle", "appear", "belong", "become", "stay", "govern",
    "lose", "leave", "let", "put", "say", "tell", "ask", "answer", "point", "refer",
    "work", "look", "seem", "exist", "happen", "get", "turn", "move", "form",
})

# A word that is also a common verb reads as a noun right after one of
# these (lemma_candidates() already handles -s/-es/-ed/-ies on the word
# itself): "No retries.", "a read", "each write".
NOUN_DETERMINERS = {
    "a", "an", "the", "no", "each", "every", "zero", "any", "some", "all",
    "this", "that", "these", "those", "its", "their", "your", "one", "two", "three",
}
# "this" and "that" are left out: each is also a system-referring pronoun,
# and so a subject in its own right.
NOUN_USE_DETERMINERS = NOUN_DETERMINERS - SYSTEM_PRONOUNS

# claude-plugins#25: a word directly before one of these object pronouns, with
# a subject token before it, reads as a finite verb even when it is outside
# the closed verb lexicon ("Every client trusts them."). "this" and "that"
# are left out: both are also complementisers ("Not this."), so including
# them would misread a negated fragment as verbed.
OBJECT_PRONOUNS = {"them", "it", "these", "those", "him", "her", "us", "me", "itself", "themselves"}
# Words that precede an object pronoun without being a verb themselves, so
# the OBJECT_PRONOUNS rule does not misread "None of them.", "Not for
# these." or "Both of them." as having a verb.
NON_VERB_BEFORE_OBJECT = {
    # prepositions
    "of", "for", "to", "with", "from", "in", "on", "at", "by", "into", "onto",
    "about", "over", "under", "between", "among", "without", "within",
    "through", "per", "via", "like", "than", "as", "against", "across",
    "around", "behind", "beyond", "near", "after", "before", "since",
    "until", "despite", "except", "up", "down", "out", "off",
    # conjunctions
    "and", "or", "but", "nor", "so",
    # negators and quantifiers
    "not", "no", "all", "both", "each", "none", "any", "some", "most",
    "many", "few", "either", "neither",
    # focusing adverbs
    "only", "just", "even", "also", "too",
    "worth",
} | NOUN_DETERMINERS
# A clause with only these words before the verb is an imperative or an
# infinitive, with no subject: "do not leave a heading empty", "to enter
# the value". "does" is not here: a third-person subject precedes it.
IMPERATIVE_LEAD = {"do", "not", "never", "always", "then", "also", "first", "please", "just", "only", "to"}

# software-english#26: do-support puts a verb in its base form ("does not
# say"), which anthropomorphism-fixed-list's word_list (inflected forms
# only) never matches directly. At most one word (an adverb) sits between
# the negator and the verb: "does not always say". "never" and "no longer"
# need no special handling here, since they take no auxiliary and leave the
# verb inflected, so the existing literal match already catches them.
DO_NEGATION = r"\b(?:do|does)(?:\s+not|n['’]t)\s+(?:[a-z]+\s+)?"
BASE_FORM_IRREGULAR = {"has": "have", "goes": "go", "does": "do"}

# A bullet item whose first line opens with a bold span and has real text
# after it closes: "**Fast startup.** The service starts in 200 ms." A
# bullet that is wholly bold ("**Fast startup.**") is not a lead-in.
BOLD_LEAD = re.compile(r"^(\*\*|__)(?=\S)(.+?)(?<=\S)\1\s*[:.\-–]?\s*\S")

CADENCE_MIN_PRECEDING_WORDS = 15
CADENCE_MAX_FRAGMENT_WORDS = 6
BOLD_LIST_MIN_BULLETS = 2
BOLD_LIST_RUN_MIN = 3
PAIR_MIN_WORDS = 4
PAIR_MAX_WORDS = 12
MAX_CANDIDATES_PER_RULE = 20

# --units-judged's value (claude-plugins#20): "N" or "N of M".
UNITS_JUDGED = re.compile(r"^\s*(\d+)(?:\s+of\s+(\d+))?\s*$", re.IGNORECASE)

# --- definite-phrase candidate detector (claude-plugins#19) -----------------
#
# A definite noun phrase ("the"/"these"/"those"/"both" + optional cardinal +
# up to DEFINITE_MAX_MODIFIERS adjective-shaped words + a head noun) whose
# head noun's lemma does not occur earlier in the document is a located
# candidate for no-unanchored-reference, or for no-unstated-presupposition
# when the phrase carries a cardinal: see find_definite_first_mentions().

# Hyphenated compounds and multi-digit numbers stay one token each, so
# "two-phase" and "30-second" are never read as a bare cardinal.
DEFINITE_TOKEN = re.compile(r"[A-Za-z0-9][A-Za-z0-9'\-]*|[.,;:!?()\"]")

CARDINAL_WORDS = {
    "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
    "eleven", "twelve", "twenty", "both",
}
# 1-99 only: "the 404 response" and "the 2009 edition" never match, since
# those are literal/identifying numbers, not counts. "one" is deliberately
# left out of CARDINAL_WORDS: "the one that ..." is not a count claim.
CARDINAL_NUMERAL = re.compile(r"^[1-9][0-9]?$")

# A numeral cardinal (not a word cardinal) over one of these heads is a
# quantity, not a presupposed count ("the 30 seconds", not "the four
# carriers") — per no-unstated-presupposition's own "not this fault: a
# number that is a quantity" clause.
QUANTITY_HEADS = {
    "second", "seconds", "minute", "minutes", "hour", "hours", "day", "days",
    "ms", "byte", "bytes", "kb", "mb", "gb", "percent",
}

DEFINITE_DETERMINERS = {"the", "these", "those"}
# "both" is handled separately in find_definite_first_mentions(): it is
# itself a cardinal and a determiner at once, and can precede an optional
# "the" ("both the options").

# Heads that never need an antecedent, tuned against this repo's and
# software-english's own real prose (claude-plugins#19).
GENERIC_DEFINITE_HEADS = {
    "same", "other", "next", "following", "previous", "rest", "end",
    "whole", "only", "way", "case", "most", "top", "bottom",
    "user", "reader", "writer", "caller",
}

DEFINITE_MAX_MODIFIERS = 2

# --- define-before-use and count/list candidate detectors (software-english#21) ---
#
# Two more located-candidate detectors, same contract as the ones above:
# find a site, never decide the fault, never enter the findings list.

# Heading occurrence required, found only by measuring both repos' real
# .md files: the literal 3+-occurrences/not-in-vocabulary rule alone
# floods every file (1231 candidates across 33 files); requiring a
# heading occurrence too narrows that to 135 (~4/file) while still
# catching the issue's own "mode" example.
DEFINE_MIN_OCCURRENCES = 3
DEFINE_NOUN_GATE = NOUN_USE_DETERMINERS | (CARDINAL_WORDS - {"both"})

# Number words only, two to twelve: no numerals (so "§7.9" never
# matches), no "one" (a range such as "one or two lines" is a quantity,
# not a list-introducing count), no "both" (software-english#21 corpus:
# "on both flags: a pending rule is never a finding" is an explanatory
# colon, not a list).
COUNT_WORDS = {
    "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
    "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12,
}
COUNT_COLON_LIST = re.compile(
    r"\b(two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\s+"
    r"((?:[a-z][a-z-]*\s+){0,2}[a-z][a-z-]*)\s*:\s+(\S.*)$",
    re.IGNORECASE,
)

BOLD_SPAN = re.compile(r"(\*\*|__)(.+?)\1")


def load_config():
    with CONFIG_PATH.open() as f:
        return json.load(f)


def format_age(seconds):
    """A phrase for seconds elapsed, for the rule-data info line below."""
    seconds = max(0, seconds)
    if seconds < 60:
        return "less than a minute ago"
    minutes = int(seconds // 60)
    if minutes < 60:
        return f"{minutes} minute{'s' if minutes != 1 else ''} ago"
    hours = int(seconds // 3600)
    if hours < 48:
        return f"{hours} hour{'s' if hours != 1 else ''} ago"
    days = int(seconds // 86400)
    return f"{days} day{'s' if days != 1 else ''} ago"


def read_data_status():
    """Returns (fetched_tag, pinned_tag, age_seconds): the tag last written
    to data/.fetched-tag by fetch-software-english-data.sh, the tag pinned
    in software-english.json, and the marker's age in seconds. Any value
    that cannot be read is None."""
    fetched_tag = None
    age_seconds = None
    try:
        fetched_tag = FETCHED_TAG_PATH.read_text().strip() or None
        age_seconds = datetime.datetime.now().timestamp() - FETCHED_TAG_PATH.stat().st_mtime
    except OSError:
        pass
    pinned_tag = None
    try:
        with PIN_PATH.open() as f:
            pinned_tag = json.load(f)["tag"]
    except (OSError, json.JSONDecodeError, KeyError, TypeError):
        pass
    return fetched_tag, pinned_tag, age_seconds


def data_status_lines(fetched_tag, pinned_tag, age_seconds):
    """The stderr lines reporting the cached rule data's identity (claude-
    plugins#28): one line naming the cached tag and its age, plus a second
    line only when the cache holds a tag other than the one pinned in
    software-english.json. The marker's age alone is never a reason to
    warn: fetch-software-english-data.sh pins an exact tag and exits at
    once, with the marker untouched, once that tag is already cached, so
    an old but matching marker is still exactly correct."""
    lines = []
    if fetched_tag is not None:
        lines.append(f"swe: rule data {fetched_tag}, fetched {format_age(age_seconds)}")
    else:
        lines.append("swe: rule data version unknown (no data/.fetched-tag marker)")
    if fetched_tag is not None and pinned_tag is not None and fetched_tag != pinned_tag:
        lines.append(
            f"swe: stale rule data: the cache holds {fetched_tag}, but "
            f"software-english.json pins {pinned_tag}. Findings from this "
            f"run use the old rules. Run {FETCH_SCRIPT} to refresh."
        )
    return lines


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


def load_tsv_words(name):
    words = set()
    path = DATA / name
    if not path.exists():
        return words
    for raw in path.read_text().splitlines()[1:]:
        if not raw.strip():
            continue
        word = raw.split("\t")[0].strip().lower()
        if word:
            words.add(word)
    return words


def load_structure_nouns():
    return load_tsv_words("structure.tsv")


def load_verb_lexicon():
    """Base-form verbs for sentence_has_verb(): vocabulary/operations.tsv's
    domain operations, plus AUXILIARY_VERBS and COMMON_VERBS (see their own
    comments). Not a part-of-speech tagger: a word also used as a noun
    elsewhere (cache, log, test) is still counted a verb here."""
    return load_tsv_words("operations.tsv") | AUXILIARY_VERBS | COMMON_VERBS


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


def strip_noise(line, keep_code=False):
    patterns = (LINK_TARGET, URL, HTML_TAG) if keep_code else (INLINE_CODE, LINK_TARGET, URL, HTML_TAG)
    for pattern in patterns:
        line = pattern.sub(lambda m: " " * len(m.group(0)), line)
    return line


def readable_line(line):
    """claude-plugins#27: the --force-inference worklist's own view of a
    line, read by prose_units() through prose_lines(readable=True). A code
    span stays verbatim. A link or image, [text](target) / ![text](target),
    renders as "text (link: target)" (or just "text", or "(link: target)"
    when either side is empty), so the model reads a resolved reference
    instead of strip_noise()'s blanked, bracket-breaking placeholder. Not
    same-length: never used by the deterministic tier or as a
    split_sentences() mirror, both of which need strip_noise()'s blanking to
    keep positions and vocabulary stable."""
    def repl(m):
        if m.group(1):
            return m.group(1)
        text, target = m.group(2).strip(), m.group(3).strip()
        if not target:
            return text
        return f"{text} (link: {target})" if text else f"(link: {target})"
    return HTML_TAG.sub(" ", READABLE_SPAN.sub(repl, line))


def prose_lines(text, exemptions, only_lines=None, keep_code=False, readable=False):
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
        yield number, (readable_line(line) if readable else strip_noise(line, keep_code=keep_code))


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


def do_support_base_forms(word_list):
    # Derives the base form do-support puts a word_list verb into ("says"
    # -> "say", "has patience" -> "have patience"). Skips the copula
    # ("is happy"), which takes no do-support, and drops a result already
    # in word_list ("arrives" -> "arrive" is already a literal entry), so
    # the literal pass keeps reporting those and nothing is reported twice.
    seen = set(word_list)
    bases = []
    for phrase in word_list:
        head, _, rest = phrase.partition(" ")
        if head == "is":
            continue
        base = BASE_FORM_IRREGULAR.get(head)
        if base is None:
            if head.endswith("ies") and len(head) > 3:
                base = head[:-3] + "y"
            elif head.endswith("s") and not head.endswith("ss") and len(head) > 1:
                base = head[:-1]
        if base is None or base == head:
            continue
        derived = f"{base} {rest}" if rest else base
        if derived in seen:
            continue
        seen.add(derived)
        bases.append(derived)
    return bases


def is_literal_token(word, line, start):
    if LITERAL_TOKEN.match(word):
        return True
    if word[0].isupper() and start != 0:
        preceding = line[:start].rstrip()
        if preceding and not preceding.endswith(SENTENCE_END):
            return True
    return False


def is_human_referent(word, human_referents):
    # A possessive ("user's") modifies the next noun, so it is never the
    # subject. A plural counts only above three letters: "is" is not "i".
    if word.endswith("'s") or word.endswith("s'"):
        return False
    if word in human_referents:
        return True
    return len(word) > 3 and word.endswith("s") and word[:-1] in human_referents


def subject_gate_passes(rule, lowered, start, structure_nouns):
    lookback_words = rule["lookback_words"]
    if rule.get("subject_gate", "system-subject") == "not-human-subject":
        before = lowered[:start]
        breaks = list(CLAUSE_BREAK.finditer(before))
        clause = before[breaks[-1].end():] if breaks else before
        preceding = WORD.findall(clause)[-lookback_words:]
        if not preceding or preceding[-1] in NOUN_USE_DETERMINERS:
            return False
        if all(w in IMPERATIVE_LEAD for w in WORD.findall(clause)):
            return False
        humans = {w.lower() for w in rule.get("human_referents", [])}
        return not any(is_human_referent(w, humans) for w in preceding)
    window = lowered[max(0, start - 40):start]
    preceding = WORD.findall(window)[-lookback_words:]
    gate_nouns = structure_nouns - HUMAN_SUBJECT_NOUNS
    return any(w in gate_nouns or w in SYSTEM_PRONOUNS for w in preceding)


ARTICLE_LEAD = re.compile(r'^["\'“”]*\b(the|a|an)\b', re.IGNORECASE)


def code_span_reads_as_text(content, em_dash):
    """software-english#27: True when an inline code span's own content
    (the text between the backticks) is a sample value or a sample message
    in natural language, rather than code, so an em dash inside it is a
    real finding rather than a token that is exempt from no-em-dash (SPEC
    §3.5). False for every content strip_noise() already keeps exempt via
    CODE_SPAN_CODE_SIGNAL, plus three further signals SPEC §3.5 names: no
    space touches the dash itself (a title's or a compound's own
    convention); the content opens with "the"/"a"/"an" (a label or a value
    is a bare phrase, not a clause); the content holds an inner quote mark
    (a quotation inside a quotation). The two readings this is built to
    tell apart: `2 — Main Office` (a sample display value, reads as text)
    against `the Messages resource — the beating heart` and `IEEE Standard
    for Information Technology—Systems Design—Software Design
    Descriptions` (a quoted fault example and a standard's title, both
    already in this repository, that the plain "has a space and is mostly
    letters" test alone would misread as sample values too)."""
    if " " not in content or CODE_SPAN_CODE_SIGNAL.search(content):
        return False
    if not re.search(r"\s" + re.escape(em_dash) + r"|" + re.escape(em_dash) + r"\s", content):
        return False
    if ARTICLE_LEAD.match(content.strip()):
        return False
    if '"' in content:
        return False
    body = content.replace(em_dash, "")
    if not body.strip():
        return False
    return sum(c.isalnum() or c == " " for c in body) / len(body) >= CODE_SPAN_TEXT_RATIO


def check_code_span_em_dash(number, line, rules, findings):
    """software-english#27: a second, narrower em-dash check, run on the
    keep_code=True view of the same line (code spans intact) so it sees
    exactly the text check_line()'s em-dash count on the keep_code=False
    view never sees (strip_noise() blanks it there). The two views never
    double-count the same character: one only ever looks inside a code
    span, the other only ever looks outside one."""
    rule = rules["no-em-dash"]
    em_dash = rule["character"]
    severity = rule.get("code_span_severity", "warning")
    for m in INLINE_CODE.finditer(line):
        content = m.group(0)[1:-1]
        if em_dash in content and code_span_reads_as_text(content, em_dash):
            for _ in range(content.count(em_dash)):
                findings.append((number, severity, "no-em-dash", "em dash in a code span that reads as natural-language text: replace with a period, a colon, or a comma"))


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
        for phrase in rule["word_list"]:
            for pm in re.finditer(r"\b" + re.escape(phrase) + r"\b", lowered):
                if any(s <= pm.start() < e for s, e in flagged_spans):
                    continue
                if subject_gate_passes(rule, lowered, pm.start(), structure_nouns):
                    flagged_spans.append((pm.start(), pm.end()))
                    findings.append((number, rule["severity"], finding_id, f'"{phrase}"'))
        if rule_id == "anthropomorphism-fixed-list":
            # The gate runs at the negator's own position, not the verb's,
            # so the lookback window is spent on the words before "does
            # not", not consumed by the negator and its optional adverb.
            for base in do_support_base_forms(rule["word_list"]):
                for nm in re.finditer(DO_NEGATION + r"(" + re.escape(base) + r")\b", lowered):
                    vstart, vend = nm.start(1), nm.end(1)
                    if any(s <= vstart < e for s, e in flagged_spans):
                        continue
                    if subject_gate_passes(rule, lowered, nm.start(), structure_nouns):
                        flagged_spans.append((vstart, vend))
                        findings.append((number, rule["severity"], finding_id, f'"{base}"'))

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
    blanked = prose_lines(text, exemptions, only_lines)
    kept = prose_lines(text, exemptions, only_lines, keep_code=True)
    for (number, line), (_, code_line) in zip(blanked, kept):
        check_line(number, line, vocabulary, structure_nouns, banned_rules, rules, findings)
        check_code_span_em_dash(number, code_line, rules, findings)
    return findings


def register_blocks(numbered_lines):
    """Groups prose_lines()'s unfiltered (number, line) pairs into
    paragraph/list/heading/table/hr blocks, so the register-rule candidate
    detectors below can see multi-line structure that check_line()'s
    one-line-at-a-time view cannot: wrapped prose puts one sentence across
    several lines, and "consecutive lists" and "a sentence right after a
    long one" are both multi-line questions.

    A gap between consecutive numbers (prose_lines() skipped a fence, a
    blockquote, an indented block, or a skip-marker line) always closes the
    current paragraph; inside a list it is read as part of a nested block
    within the current item, not a break.

    Returns a list of ("paragraph", [(n, line), ...]), ("list", {"items":
    [(n, first_line_text), ...], "lines": [n, ...]}), ("heading", n),
    ("table", [n, ...]), or ("hr", n)."""
    blocks = []
    current_list = None
    current_para = None
    prev_number = None
    prev_blank = True

    def close_list():
        nonlocal current_list
        if current_list is not None:
            blocks.append(("list", current_list))
            current_list = None

    def close_para():
        nonlocal current_para
        if current_para:
            blocks.append(("paragraph", current_para))
        current_para = None

    for number, line in numbered_lines:
        gapped = prev_number is not None and number != prev_number + 1
        stripped = line.strip()

        if not stripped:
            close_para()
            prev_number = number
            prev_blank = True
            continue

        if HR_LINE.match(line):
            close_list()
            close_para()
            blocks.append(("hr", number))
            prev_number = number
            prev_blank = True
            continue

        if HEADING.match(line):
            close_list()
            close_para()
            blocks.append(("heading", number))
            prev_number = number
            prev_blank = True
            continue

        if TABLE_ROW.match(line):
            close_list()
            close_para()
            if blocks and blocks[-1][0] == "table":
                blocks[-1][1].append(number)
            else:
                blocks.append(("table", [number]))
            prev_number = number
            prev_blank = False
            continue

        bm = BULLET.match(line)
        if bm:
            indent = len(bm.group(1))
            text = bm.group(2)
            close_para()
            if current_list is None:
                current_list = {"indent": indent, "items": [(number, text)], "lines": [number]}
            elif indent <= current_list["indent"]:
                current_list["items"].append((number, text))
                current_list["lines"].append(number)
            else:
                current_list["lines"].append(number)
            prev_number = number
            prev_blank = False
            continue

        if current_list is not None:
            is_indented = line[:1] in (" ", "\t")
            if is_indented or not prev_blank:
                current_list["lines"].append(number)
                prev_number = number
                prev_blank = False
                continue
            close_list()

        if gapped or current_para is None:
            close_para()
            current_para = [(number, line)]
        else:
            current_para.append((number, line))
        prev_number = number
        prev_blank = False

    close_list()
    close_para()
    return blocks


def prose_units(numbered_lines, text_lines=None):
    """The numbered worklist --force-inference prints for a single named
    file (claude-plugins#20): one unit per register_blocks() block, except
    an "hr" block, which is never a unit. Reuses that same parse, so "a
    paragraph outside a code fence" means exactly what the register-rule
    candidate detectors above already treat as prose; a fence, an indented
    block, a blockquote, and a skip-marker line are never units, for the
    same reason they are never candidates.

    A "heading" and a "table" unit cover the whole block. A "list" block
    becomes one "list-item" unit per top-level item: a nested bullet or a
    continuation line folds into its own parent item, not a separate unit,
    taken from the item's start line up to the line before the next item's
    start (or the block's last line, for the final item).

    text_lines, when given (claude-plugins#27), is a second (n, line)
    stream, read in place of numbered_lines for each unit's own text only:
    block structure and line ranges still come from register_blocks() on
    numbered_lines, unaffected. Pass prose_lines(..., readable=True) here so
    a judged unit shows a link resolved and a code span intact, rather than
    strip_noise()'s blanked placeholder.

    Returns [(kind, first_line, last_line, text), ...] in document order;
    kind is "heading", "paragraph", "list-item", or "table". text is the
    unit's own prose, read back for the judging pass to work from: the
    heading line itself, the paragraph's lines joined with a single space,
    a list item's own first line (register_blocks() does not keep a
    continuation line's text), or a table block's first row."""
    line_by_number = dict(numbered_lines)
    text_by_line = dict(text_lines) if text_lines is not None else line_by_number
    units = []
    for kind, data in register_blocks(numbered_lines):
        if kind == "heading":
            units.append(("heading", data, data, text_by_line[data].strip()))
        elif kind == "paragraph":
            first, last = data[0][0], data[-1][0]
            text = " ".join(text_by_line[n].strip() for n, _ in data)
            units.append(("paragraph", first, last, text))
        elif kind == "list":
            item_starts = [n for n, _ in data["items"]]
            block_last = data["lines"][-1]
            for idx, (start, first_text) in enumerate(data["items"]):
                end = item_starts[idx + 1] - 1 if idx + 1 < len(item_starts) else block_last
                bm = BULLET.match(text_by_line[start])
                text = bm.group(2).strip() if bm else first_text.strip()
                units.append(("list-item", start, end, text))
        elif kind == "table":
            units.append(("table", data[0], data[-1], text_by_line[data[0]].strip()))
        # "hr" is never a unit.
    return units


def split_sentences(paragraph, mirror=None):
    """Splits one paragraph block's (n, line) pairs into [(start_line,
    sentence_text), ...] on SENTENCE_BREAK, joining wrapped lines with a
    single space first so a sentence split across lines reads as one.

    mirror, when given, is a same-length, same-offsets (n, line) pairing
    for the same paragraph (claude-plugins#25: paragraph's own lines with
    code spans kept rather than blanked). Sentence boundaries are always
    found on paragraph's text, so a period or "?" inside a code span can
    never create one; each returned sentence is then read from mirror's
    text at the same offsets, so its code spans are intact."""
    joined_parts = []
    mirror_parts = []
    offsets = []
    pos = 0
    for idx, (n, line) in enumerate(paragraph):
        if joined_parts:
            joined_parts.append(" ")
            mirror_parts.append(" ")
            pos += 1
        offsets.append((pos, n))
        joined_parts.append(line)
        mirror_parts.append(mirror[idx][1] if mirror is not None else line)
        pos += len(line)
    full = "".join(joined_parts)
    full_mirror = "".join(mirror_parts) if mirror is not None else full

    def line_at(offset):
        result = offsets[0][1]
        for start, n in offsets:
            if start <= offset:
                result = n
            else:
                break
        return result

    sentences = []
    start = 0
    for m in SENTENCE_BREAK.finditer(full):
        sentence = full_mirror[start:m.start()].strip()
        if sentence:
            sentences.append((line_at(start), sentence))
        start = m.end()
    tail = full_mirror[start:].strip()
    if tail:
        sentences.append((line_at(start), tail))
    return sentences


def sentence_has_verb(sentence, verbs):
    """True when sentence has a word a stdlib-only linter can read as a
    verb: a contraction ("doesn't", "it's"), an auxiliary, a word in verbs
    (unless a determiner right before it, NOUN_DETERMINERS, marks it read
    as a noun instead: "No retries.", "a read"), or a word directly before
    an object pronoun with a subject token before it (claude-plugins#25:
    "Every client trusts them.", outside the closed lexicon). A code span
    (CADENCE_TOKEN) is opaque throughout: never a verb, an auxiliary, or a
    determiner, and its own contents are never looked up."""
    tokens = CADENCE_TOKEN.findall(sentence)
    for i, word in enumerate(tokens):
        if word.startswith("`"):
            continue
        if CONTRACTION_SUFFIX.search(word):
            return True
        candidates = list(lemma_candidates(word.lower()))
        if any(c in AUXILIARY_VERBS for c in candidates):
            return True
        if any(c in verbs for c in candidates):
            prev = tokens[i - 1].lower() if i > 0 else None
            if prev in NOUN_DETERMINERS:
                continue
            return True
        if i >= 1 and i + 1 < len(tokens) and word[0].isalpha() and word.islower():
            nxt = tokens[i + 1].lower()
            if nxt in OBJECT_PRONOUNS and word not in NON_VERB_BEFORE_OBJECT:
                return True
    return False


def find_cadence_fragments(blocks, verbs, code_lines=None):
    """Locates candidates for no-cadence-device's first shape: a verbless
    fragment set as its own sentence right after a sentence of
    CADENCE_MIN_PRECEDING_WORDS or more words, within the same paragraph.
    Never decides the fault: whether the fragment states a fact the
    preceding sentence does not is left to the judging model.

    code_lines, when given, is prose_lines()'s unfiltered output with code
    spans kept (claude-plugins#25): sentence boundaries and the preceding
    sentence's word count still use the blanked text in blocks, but the
    fragment's own tokenising, verb check, and reported detail use the
    code-kept mirror, so a code-span subject or object is read as a noun
    phrase rather than disappearing."""
    code_by_line = dict(code_lines) if code_lines is not None else None
    results = []
    for kind, data in blocks:
        if kind != "paragraph":
            continue
        mirror = [(n, code_by_line.get(n, line)) for n, line in data] if code_by_line is not None else None
        sentences = split_sentences(data, mirror=mirror)
        for i in range(1, len(sentences)):
            _, prev_text = sentences[i - 1]
            frag_line, frag_text = sentences[i]
            if prev_text.endswith("?"):
                continue
            prev_words = WORD.findall(prev_text)
            if len(prev_words) < CADENCE_MIN_PRECEDING_WORDS:
                continue
            if not frag_text or frag_text[-1] not in (".", "!"):
                continue
            frag_words = CADENCE_TOKEN.findall(frag_text)
            if not (1 <= len(frag_words) <= CADENCE_MAX_FRAGMENT_WORDS):
                continue
            if sentence_has_verb(frag_text, verbs):
                continue
            detail = (
                f'verbless sentence "{frag_text}" follows a {len(prev_words)}-word '
                "sentence; judge whether it states a fact that sentence does not."
            )
            results.append((frag_line, detail, {frag_line}))
    return results


def word_class(word, verbs, connectives, structure_nouns, qualities):
    lw = word.lower()
    if lw in connectives:
        return "D"
    candidates = list(lemma_candidates(lw))
    if lw in AUXILIARY_VERBS or any(c in verbs for c in candidates):
        return "V"
    if any(c in structure_nouns for c in candidates):
        return "N"
    if any(c in qualities for c in candidates):
        return "Q"
    return "O"


def find_matched_pairs(blocks, verbs, connectives, structure_nouns, qualities):
    """Locates candidates for no-cadence-device's second shape: two
    adjacent sentences, in the same paragraph, with an identical sequence
    of word classes (determiner/verb/noun/quality/other) and at least one
    verb, each PAIR_MIN_WORDS to PAIR_MAX_WORDS words, neither starting
    with quoted material. Never decides whether the second restates the
    first, only that the shapes match."""
    results = []
    for kind, data in blocks:
        if kind != "paragraph":
            continue
        sentences = split_sentences(data)
        for i in range(1, len(sentences)):
            a_line, a_text = sentences[i - 1]
            b_line, b_text = sentences[i]
            if not a_text or not b_text:
                continue
            if a_text[0] in ("\"", "'", "(") or b_text[0] in ("\"", "'", "("):
                continue
            a_words = WORD.findall(a_text)
            b_words = WORD.findall(b_text)
            if not (PAIR_MIN_WORDS <= len(a_words) <= PAIR_MAX_WORDS):
                continue
            if not (PAIR_MIN_WORDS <= len(b_words) <= PAIR_MAX_WORDS):
                continue
            a_classes = [word_class(w, verbs, connectives, structure_nouns, qualities) for w in a_words]
            b_classes = [word_class(w, verbs, connectives, structure_nouns, qualities) for w in b_words]
            if a_classes != b_classes or "V" not in a_classes:
                continue
            detail = (
                f'sentence "{b_text}" has the same word-class shape as the sentence '
                f"before it (line {a_line}); judge whether it restates that sentence."
            )
            results.append((b_line, detail, {a_line, b_line}))
    return results


def find_bold_list_runs(blocks):
    """Locates candidates for no-mechanical-repetition's first pattern: a
    run of BOLD_LIST_RUN_MIN or more markdown lists, each with at least
    BOLD_LIST_MIN_BULLETS top-level bullets that all open with a bold
    lead-in. A paragraph or heading between qualifying lists does not break
    the run (the usual shape is heading/intro sentence/bold list, repeated);
    a non-qualifying list does. Reports once per run, at the run's first
    bullet, naming every list's start line; never decides whether a lead-in
    restates its own bullet."""
    results = []
    run = []

    def qualifies(list_data):
        items = list_data["items"]
        return len(items) >= BOLD_LIST_MIN_BULLETS and all(BOLD_LEAD.match(t) for _, t in items)

    def flush():
        if len(run) >= BOLD_LIST_RUN_MIN:
            run_lines = {items[0][0] for items in (l["items"] for l in run)}
            first_line = run[0]["items"][0][0]
            starts = ", ".join(str(l["items"][0][0]) for l in run)
            detail = (
                f"{len(run)} lists in a row open every bullet with a bold lead-in "
                f"(lists at lines {starts}); judge whether each lead-in restates the "
                "item it labels. Report once per run."
            )
            results.append((first_line, detail, run_lines))
        run.clear()

    for kind, data in blocks:
        if kind == "list":
            if qualifies(data):
                run.append(data)
            else:
                flush()
        elif kind in ("paragraph", "heading"):
            continue
        else:
            flush()
    flush()
    return results


def definite_segments(numbered_lines):
    """Splits numbered_lines (prose_lines()'s unfiltered output for one
    source) into phrase-bounded segments: each a list of (line, token)
    pairs tokenised with DEFINITE_TOKEN, in document order. A segment never
    crosses a blank line, an HR_LINE, a HEADING, a TABLE_ROW, a BULLET, or a
    gap in line numbers (a fence, a blockquote, an indented block, or a
    skip-marker line prose_lines() already excluded). A heading, a table
    row, and a bullet item each become their own one-line segment: a
    heading's text stays in the token stream (stripped of its leading
    "#"s) since it both anchors an earlier noun and can itself hold a
    candidate phrase; a table row has its "|" characters stripped first; a
    bullet's marker is stripped, only the text after it is tokenised. A
    wrapped line inside one ordinary paragraph (no boundary line type, no
    gap) joins the current segment, so a phrase split across a wrap still
    reads as one segment (claude-plugins#19)."""
    segments = []
    current = None
    prev_number = None

    def close():
        nonlocal current
        if current:
            segments.append(current)
        current = None

    for number, line in numbered_lines:
        gapped = prev_number is not None and number != prev_number + 1
        prev_number = number
        stripped = line.strip()

        if not stripped:
            close()
            continue
        if HR_LINE.match(line):
            close()
            continue

        hm = HEADING.match(line)
        if hm:
            close()
            tokens = [(number, t) for t in DEFINITE_TOKEN.findall(line[hm.end():])]
            if tokens:
                segments.append(tokens)
            continue

        if TABLE_ROW.match(line):
            close()
            tokens = [(number, t) for t in DEFINITE_TOKEN.findall(line.replace("|", " "))]
            if tokens:
                segments.append(tokens)
            continue

        bm = BULLET.match(line)
        if bm:
            close()
            tokens = [(number, t) for t in DEFINITE_TOKEN.findall(bm.group(2))]
            if tokens:
                segments.append(tokens)
            continue

        if gapped or current is None:
            close()
            current = [(number, t) for t in DEFINITE_TOKEN.findall(line)]
        else:
            current.extend((number, t) for t in DEFINITE_TOKEN.findall(line))

    close()
    return segments


def _strip_possessive_s(word):
    """"carrier's" reads as "carrier" for the head check and for anchoring."""
    if word[-2:].lower() == "'s":
        return word[:-2]
    return word


def _definite_head_ok(token, connectives):
    """True when token could be the head of a definite phrase: starts with
    a lowercase letter (a capitalised or punctuation token is out of
    scope), at least 3 characters after stripping a trailing "'s", not a
    connective/auxiliary/cardinal-word/generic-definite-head, and not a
    literal token (acronym, snake_case/dotted/path-like, camelCase, a
    version number — LITERAL_TOKEN, shared with the vocabulary check)."""
    word = _strip_possessive_s(token)
    if not word or not word[0].islower():
        return False
    if not any(ch.isalpha() for ch in word):
        return False
    if len(word) < 3:
        return False
    lw = word.lower()
    if lw in connectives or lw in AUXILIARY_VERBS or lw in CARDINAL_WORDS:
        return False
    if lw in GENERIC_DEFINITE_HEADS:
        return False
    if LITERAL_TOKEN.match(word):
        return False
    return True


def find_definite_first_mentions(numbered_lines, connectives, qualities):
    """Locates candidates for no-unanchored-reference and, where the
    phrase carries a cardinal, no-unstated-presupposition: one forward
    pass over definite_segments(numbered_lines), in document order,
    maintaining one `seen` set of lemma_candidates() across the whole
    document (never reset per segment — a noun seen in the title or an
    earlier heading anchors a later mention the same as one seen in body
    prose). A hyphenated token also contributes lemma_candidates() of each
    half ("dead-letter" anchors a later bare "letter" or "dead").

    A phrase starts at "the"/"these"/"those", or at "both" immediately
    followed by "the" ("both the options"). Bare "both" with no following
    "the" is not a phrase start: in this repo's and software-english's own
    prose, every such occurrence is the correlative/pronoun use ("both
    match", "X and Y both existed"), never a determiner before a noun, so
    treating it as one only produced noise (claude-plugins#19 corpus
    sweep) — the module has no verb lexicon to tell "both enforced" (a
    clause) from "both options" (a phrase) apart otherwise. From there, an
    optional cardinal (a CARDINAL_WORDS word, or a CARDINAL_NUMERAL
    numeral) is consumed, then up to DEFINITE_MAX_MODIFIERS tokens shaped
    like an adjective or past participle (ends "ed", or in qualities),
    each consumed only while the token after it could still itself be a
    head (_definite_head_ok()), so a long run of ordinary words is never
    read as "all modifiers". The next token is the head if it passes
    _definite_head_ok(); otherwise this was not a definite phrase worth
    reporting, and the scan resumes one token past the determiner, not
    past the whole attempt, so a token inside a failed attempt can still
    start its own phrase.

    A head immediately followed by ":" or "(" is a same-sentence
    enumeration ("the three routes: read, write, and delete") and is not
    reported. A numeral (not word) cardinal over a QUANTITY_HEADS head
    ("the 30 seconds") is a quantity, not a presupposed count, and is not
    reported. A head whose lemma is already in `seen` is anchored and is
    not reported. Every token read, including a head that is excluded or
    anchored, is added to `seen` before the scan moves on, so a given head
    noun only ever produces one candidate: its own first occurrence.

    Returns [(line, phrase_text, has_cardinal), ...] in document order
    (claude-plugins#19)."""
    seen = set()

    def mark_seen(token):
        lw = token.lower()
        for c in lemma_candidates(lw):
            seen.add(c)
        if "-" in lw:
            for part in lw.split("-"):
                if part:
                    for c in lemma_candidates(part):
                        seen.add(c)

    results = []
    for segment in definite_segments(numbered_lines):
        n = len(segment)
        i = 0
        while i < n:
            line, tok = segment[i]
            lw = tok.lower()
            is_both = lw == "both" and i + 1 < n and segment[i + 1][1].lower() == "the"
            if lw not in DEFINITE_DETERMINERS and not is_both:
                mark_seen(tok)
                i += 1
                continue

            start = i
            det_line = line
            j = i + 1
            has_cardinal = False
            cardinal_is_numeral = False
            if is_both:
                has_cardinal = True
                j += 1  # the "the" immediately after "both" is already confirmed
            elif j < n:
                nxt = segment[j][1]
                if nxt.lower() in CARDINAL_WORDS:
                    has_cardinal = True
                    j += 1
                elif CARDINAL_NUMERAL.match(nxt):
                    has_cardinal = True
                    cardinal_is_numeral = True
                    j += 1

            skipped = 0
            while skipped < DEFINITE_MAX_MODIFIERS and j < n:
                cand = segment[j][1]
                lc = cand.lower()
                modifier_shaped = (lc.endswith("ed") and len(lc) > 2) or lc in qualities
                if not modifier_shaped:
                    break
                if j + 1 >= n or not _definite_head_ok(segment[j + 1][1], connectives):
                    break
                j += 1
                skipped += 1

            head_idx = j
            if head_idx >= n or not _definite_head_ok(segment[head_idx][1], connectives):
                for k in range(start, min(head_idx, n - 1) + 1):
                    mark_seen(segment[k][1])
                i = start + 1
                continue

            head_tok = segment[head_idx][1]
            head_word = _strip_possessive_s(head_tok).lower()
            next_tok = segment[head_idx + 1][1] if head_idx + 1 < n else None

            for k in range(start, head_idx):
                mark_seen(segment[k][1])

            if next_tok in (":", "("):
                mark_seen(head_tok)
                i = head_idx + 1
                continue

            if has_cardinal and cardinal_is_numeral and any(
                c in QUANTITY_HEADS for c in lemma_candidates(head_word)
            ):
                mark_seen(head_tok)
                i = head_idx + 1
                continue

            anchored = any(c in seen for c in lemma_candidates(head_word))
            mark_seen(head_tok)
            if not anchored:
                phrase_text = " ".join(t for _, t in segment[start:head_idx + 1])
                results.append((det_line, phrase_text, has_cardinal))

            i = head_idx + 1

    return results


def term_is_defined(forms, text):
    """True when text contains a definition clause for any of forms (a set
    of lowercase surface forms of one term): a bold span containing a
    form; "FORM means/refers to/is defined as/stands for/denotes"; "called/
    named/termed/known as FORM"; "a/an FORM is a/an/the/any/one"; a
    parenthetical gloss right after the term; or a bullet/table row that
    opens with the term followed by ":" or "|" (software-english#21)."""
    if not forms:
        return False
    alt = "|".join(re.escape(f) for f in sorted(forms, key=len, reverse=True))

    for m in BOLD_SPAN.finditer(text):
        inner = m.group(2).lower()
        if any(re.search(r"\b" + re.escape(f) + r"\b", inner) for f in forms):
            return True

    if re.search(r"\b(?:" + alt + r")\s+(?:means|refers to|is defined as|stands for|denotes)\b", text, re.IGNORECASE):
        return True
    if re.search(
        r"\b(?:called|named|termed|known as)\s+(?:an?\s+|the\s+)?[\"'“]?(?:" + alt + r")\b",
        text, re.IGNORECASE,
    ):
        return True
    if re.search(r"\b(?:a|an)\s+(?:" + alt + r")\s+is\s+(?:a|an|the|any|one)\b", text, re.IGNORECASE):
        return True
    if re.search(r"\b(?:" + alt + r")\s*\(", text, re.IGNORECASE):
        return True

    for line in text.splitlines():
        bm = BULLET.match(line)
        if bm:
            item_text = bm.group(2)
        elif TABLE_ROW.match(line):
            item_text = line.replace("|", " ", 1)
        else:
            continue
        if re.match(r"\s*(?:" + alt + r")\s*[:|]", item_text, re.IGNORECASE):
            return True

    return False


def find_undefined_terms(numbered_lines, vocabulary, verbs, banned_words):
    """Locates candidates for define-before-use (software-english#21): a
    noun that occurs at least DEFINE_MIN_OCCURRENCES times, with at least
    one of those occurrences in a heading, preceded somewhere by a word in
    DEFINE_NOUN_GATE (confirming a noun use, not some other part of
    speech), outside the approved vocabulary/verb lexicon/single-word
    banned phrases (those are vocabulary-membership's or banned-word's own
    territory), and never defined anywhere in the source (term_is_defined()).

    One forward pass, grouping by lemma: a token joins the group of any of
    its lemma_candidates() already seen, keyed on the first-seen surface
    form (not the shortest candidate — that would map "modes" to "mod" and
    split it from "mode"). Returns [(line, detail, {line}), ...] sorted by
    first occurrence, so an opening-sentence term is always inside the cap."""
    full_text = "\n".join(line for _, line in numbered_lines)
    groups = {}
    key_by_lemma = {}

    for number, line in numbered_lines:
        hm = HEADING.match(line)
        in_heading = bool(hm)
        search_text = line[hm.end():] if in_heading else line

        for m in WORD.finditer(search_text):
            word = m.group(0)
            start = m.start()
            if in_heading:
                if LITERAL_TOKEN.match(word):
                    continue
            else:
                if is_literal_token(word, line, start):
                    continue

            lw = word.lower()
            if len(lw) < 3 or lw.endswith("ed") or lw.endswith("ly"):
                continue
            if lw in CARDINAL_WORDS or lw in GENERIC_DEFINITE_HEADS:
                continue
            candidates = list(lemma_candidates(lw))
            if any(c in vocabulary or c in verbs or c in banned_words for c in candidates):
                continue

            prev_text = search_text[:start].rstrip()
            prev_match = None
            for pm in WORD.finditer(prev_text):
                prev_match = pm
            noun_gate_ok = bool(prev_match) and prev_match.group(0).lower() in DEFINE_NOUN_GATE

            key = None
            for c in candidates:
                if c in key_by_lemma:
                    key = key_by_lemma[c]
                    break
            if key is None:
                key = lw
                groups[key] = {
                    "count": 0, "first_line": number, "first_surface": word,
                    "forms": set(), "in_heading": False, "noun_gate": False,
                }
            for c in candidates:
                key_by_lemma[c] = key

            g = groups[key]
            g["count"] += 1
            g["forms"].add(lw)
            if in_heading:
                g["in_heading"] = True
            if noun_gate_ok:
                g["noun_gate"] = True

    results = []
    for g in groups.values():
        if g["count"] < DEFINE_MIN_OCCURRENCES or not g["in_heading"] or not g["noun_gate"]:
            continue
        if term_is_defined(g["forms"], full_text):
            continue
        detail = (
            f'term "{g["first_surface"]}" occurs {g["count"]} times, in a heading among them, '
            "with no definition clause, and is not in the approved vocabulary; judge whether the "
            "intended reader uses it, or whether the document must define it before this use."
        )
        results.append((g["first_line"], detail, {g["first_line"]}))

    results.sort(key=lambda r: r[0])
    return results


def count_list_items(tail):
    """Counts the items in a list that follows a colon in the same
    sentence, for find_count_list_mismatches() (software-english#21).
    Splits tail on commas outside parentheses and double quotes; drops
    empty parts and a leading "and"/"or" on the last part. Where exactly
    one part remains, splits it on a bare "and"/"or": one conjunction
    gives 2 items, none gives 1, more than one is ambiguous and returns
    None (not reported). Otherwise, where the last part had no leading
    "and"/"or" (no Oxford comma), a single bare "and"/"or" inside it
    (claude-plugins#24) counts as a serial conjunction and adds one item;
    more than one is ambiguous and returns None. Otherwise returns the
    number of comma-split parts."""
    tail = re.sub(r"[.!?]+\s*$", "", tail.strip()).strip()
    if not tail:
        return None

    parts = []
    current = []
    depth = 0
    in_dquote = False
    for ch in tail:
        if ch == '"':
            in_dquote = not in_dquote
            current.append(ch)
            continue
        if not in_dquote:
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth = max(0, depth - 1)
            if ch == "," and depth == 0:
                parts.append("".join(current).strip())
                current = []
                continue
        current.append(ch)
    parts.append("".join(current).strip())
    parts = [p for p in parts if p]
    if not parts:
        return None

    stripped_last = re.sub(r"^(?:and|or)\s+", "", parts[-1], flags=re.IGNORECASE)
    oxford = stripped_last != parts[-1]
    parts[-1] = stripped_last

    if len(parts) == 1:
        conjunctions = list(re.finditer(r"\s+(?:and|or)\s+", parts[0], re.IGNORECASE))
        if len(conjunctions) == 1:
            return 2
        if len(conjunctions) == 0:
            return 1
        return None

    if not oxford:
        conjunctions = list(re.finditer(r"\s+(?:and|or)\s+", parts[-1], re.IGNORECASE))
        if len(conjunctions) == 1:
            return len(parts) + 1
        if len(conjunctions) > 1:
            return None

    return len(parts)


def find_count_list_mismatches(blocks):
    """Locates candidates for no-count-list-mismatch (software-english#21):
    a number word (COUNT_WORDS) immediately before a short noun phrase and
    a colon, in the same sentence, whose following list's item count
    (count_list_items()) differs from the stated number. Reads sentences
    from paragraph blocks and from each list block's own top-level items
    (register_blocks()); headings and tables are out of scope. Returns
    [(line, detail, {line}), ...] sorted by line."""
    results = []
    for kind, data in blocks:
        if kind == "paragraph":
            sentences = split_sentences(data)
        elif kind == "list":
            sentences = []
            for n, text in data["items"]:
                sentences.extend(split_sentences([(n, text)]))
        else:
            continue

        for line, sentence in sentences:
            for m in COUNT_COLON_LIST.finditer(sentence):
                stated = COUNT_WORDS[m.group(1).lower()]
                actual = count_list_items(m.group(3))
                if actual is not None and actual >= 2 and actual != stated:
                    detail = (
                        f'count "{m.group(1)}" before a colon list of {actual} items in the same '
                        "sentence; judge whether the count, the list, or the punctuation that "
                        "separates the items is wrong."
                    )
                    results.append((line, detail, {line}))

    results.sort(key=lambda r: r[0])
    return results


def find_register_candidates(numbered_lines, only_lines, lexicon, rule_ids, code_lines=None):
    """Returns {rule_id: [(line, detail), ...]} of located candidates for
    whichever of no-cadence-device, no-mechanical-repetition,
    no-unanchored-reference, no-unstated-presupposition, define-before-use,
    and no-count-list-mismatch are in rule_ids, from numbered_lines
    (prose_lines()'s unfiltered output for one source). With only_lines set
    (--diff --added-only), keeps a candidate only where it touches a
    changed line. Candidates never enter a findings list and never affect
    error_total or the exit code.

    code_lines, when given, is prose_lines()'s unfiltered output with code
    spans kept (claude-plugins#25), used only by find_cadence_fragments()
    so a code-span subject or object reads as a noun phrase."""
    out = {}
    if not numbered_lines or not rule_ids:
        return out
    blocks = register_blocks(numbered_lines)
    verbs, connectives, structure_nouns, qualities, vocabulary, banned_words = lexicon

    if "no-cadence-device" in rule_ids:
        candidates = find_cadence_fragments(blocks, verbs, code_lines) + find_matched_pairs(
            blocks, verbs, connectives, structure_nouns, qualities
        )
        candidates.sort(key=lambda c: c[0])
        out["no-cadence-device"] = candidates
    if "no-mechanical-repetition" in rule_ids:
        out["no-mechanical-repetition"] = find_bold_list_runs(blocks)

    definite_rule_ids = {"no-unanchored-reference", "no-unstated-presupposition"} & set(rule_ids)
    if definite_rule_ids:
        unanchored = []
        presupposition = []
        for line, phrase_text, has_cardinal in find_definite_first_mentions(numbered_lines, connectives, qualities):
            if has_cardinal:
                detail = (
                    f'definite phrase "{phrase_text}" whose head noun first occurs here, '
                    "with a count; judge whether an earlier sentence states that count."
                )
                if "no-unstated-presupposition" in rule_ids:
                    presupposition.append((line, detail, {line}))
                elif "no-unanchored-reference" in rule_ids:
                    unanchored.append((line, detail, {line}))
            else:
                detail = (
                    f'definite phrase "{phrase_text}" whose head noun first occurs here; '
                    "judge whether an earlier sentence, the title, a link or a table names its referent."
                )
                if "no-unanchored-reference" in rule_ids:
                    unanchored.append((line, detail, {line}))
        # Already in document order from one forward pass; no re-sort needed.
        if "no-unanchored-reference" in rule_ids:
            out["no-unanchored-reference"] = unanchored
        if "no-unstated-presupposition" in rule_ids:
            out["no-unstated-presupposition"] = presupposition

    if "define-before-use" in rule_ids:
        out["define-before-use"] = find_undefined_terms(numbered_lines, vocabulary, verbs, banned_words)
    if "no-count-list-mismatch" in rule_ids:
        out["no-count-list-mismatch"] = find_count_list_mismatches(blocks)

    if only_lines is not None:
        for rule_id, candidates in out.items():
            out[rule_id] = [c for c in candidates if c[2] & only_lines]

    return {rule_id: [(line, detail) for line, detail, _ in candidates] for rule_id, candidates in out.items()}


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


def count_words_sentences(text):
    words = len(WORD.findall(text))
    sentences = len([s for s in re.split(r"(?<=[.!?])\s+", text.strip()) if s.strip()])
    return words, sentences


def format_unit_worklist(label, units):
    """units' prose_units() list (claude-plugins#20) as finding-shaped
    `[inference-unit]` lines, for the judging pass to walk: one separator
    line stating the total, then one numbered line per unit, "unit N of M,
    <kind>, line(s) <range>: <text>". Also at line 0 and severity
    "warning", the same never-a-finding convention format_inference_rules()
    uses for a rule or a candidate line. Returns [] for an empty worklist
    (the separator line still states "0 prose unit(s)"); the caller
    decides whether to print that."""
    total = len(units)
    lines = [
        f"{label}:0: [warning] [inference-unit] {total} prose unit(s) follow; "
        "judge each one against every rule above."
    ]
    for idx, (kind, first, last, text) in enumerate(units, start=1):
        where = f"line {first}" if first == last else f"lines {first}-{last}"
        lines.append(f"{label}:0: [warning] [inference-unit] unit {idx} of {total}, {kind}, {where}: {text}")
    return lines


def format_inference_rules(label, inference_rules, det_errors, det_warnings, candidates=None, units=None):
    """The applicable inference-based rules for one source, as finding-shaped
    lines, for the caller to judge the prose against directly. This script
    never judges them itself.

    Finding-shaped (not "- rule-id: description") so a caller filtering
    output for finding lines (a `grep -E ":\\s*\\[(error|warning)\\]"`, the
    natural thing to do on a long file) still receives them instead of
    silently discarding the whole block (claude-plugins#14). Always at line
    0 and severity "warning", so a rule line is never mistaken for a real
    finding at a real location: a pending rule is not itself a violation.
    Where the catalogue's own severity differs, it is appended in
    parentheses so the judging step still knows it.

    candidates, from find_register_candidates() (claude-plugins#18), is an
    optional {rule_id: [(line, detail), ...]} of located structural
    candidates for a rule above; each prints right after its rule's own
    line, also at line 0 (never a real finding), as "candidate at line N:
    <detail>", capped at MAX_CANDIDATES_PER_RULE with an "omitted" line past
    the cap. The summary line's own text is unchanged when no candidate
    exists for any rule, so an existing caller sees no difference.

    units, from prose_units() (claude-plugins#20), is an optional list
    printed via format_unit_worklist() right after every rule's own lines
    and before the summary line, so "the rules print once and the units
    print once": a caller walks the whole rule set once per source, then
    the whole worklist once per source. The summary line also gains a
    trailing clause naming the total and the --units-judged value that
    claims it. Omitted (as for a multi-file --force-inference call, which
    mints no nonce to bind a total to) the summary line's own text is
    unchanged, so an existing caller sees no difference."""
    lines = []
    total_candidates = 0
    for rule_id, rule in inference_rules.items():
        desc = " ".join(rule["description"].split())
        line = f"{label}:0: [warning] [{rule_id}] inference pending: {desc}"
        severity = rule.get("severity", "warning")
        if severity != "warning":
            line += f" (severity on violation: {severity})"
        lines.append(line)

        rule_candidates = (candidates or {}).get(rule_id, [])
        shown = rule_candidates[:MAX_CANDIDATES_PER_RULE]
        for cand_line, detail in shown:
            lines.append(f"{label}:0: [warning] [{rule_id}] candidate at line {cand_line}: {detail}")
        total_candidates += len(shown)
        omitted = len(rule_candidates) - len(shown)
        if omitted:
            lines.append(
                f"{label}:0: [warning] [{rule_id}] candidate at line 0: "
                f"{omitted} more candidate(s) omitted; judge the whole source."
            )

    if units is not None:
        lines.extend(format_unit_worklist(label, units))

    summary = (
        f"{label}:0: [warning] [inference-pending] {len(inference_rules)} inference rule(s) "
        f"above need model judgement; this script does not judge them. "
        f"Deterministic tier: {det_errors} error(s), {det_warnings} warning(s)."
    )
    if total_candidates:
        summary += f" {total_candidates} located candidate(s) above are not findings."
    if units is not None:
        summary += f" {len(units)} prose unit(s) listed above; record with --units-judged {len(units)}."
    lines.append(summary)
    return lines


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
    parser.add_argument("--advise-inference", action="store_true", help="prints the applicable inference rules as finding-shaped `label:0: [warning] [rule-id] inference pending: ...` lines, each optionally followed by its own `candidate at line N: ...` lines (a located structural signal, never a finding), plus an `[inference-pending]` summary line, inside an INFERENCE_ADVISED block; gated: only when the deterministic tier is clean this invocation, not already stop_hook_active, and eligible per inference_eligible(); never judges the prose itself. Cannot be combined with --count.")
    parser.add_argument("--force-inference", action="store_true", help="prints the same block unconditionally: ignores the deterministic-clean gate, stop_hook_active, and the eligibility throttle (still skips on empty prose); never judges the prose itself; for a single named file inside a git repository, also prints its prose as a numbered `[inference-unit]` worklist, a `swe-lint-units: M` total, and a single-use swe-lint-nonce, all for --record-lint-result's --units-judged and --nonce. Cannot be combined with --count.")
    parser.add_argument("--stop-hook-active", default="false", choices=["true", "false"])
    parser.add_argument("--quiet-vocab", action="store_true", help="omit vocabulary-membership lines from the printed report (they never block; this only reduces noise)")
    parser.add_argument("--cwd", default=None, help="project root .swe-ignore is read from (defaults to the current directory)")
    parser.add_argument("--record-lint-result", choices=["clean", "failed"], default=None, help="record a both-tier verdict for one named file in this repository's lint ledger (<git-common-dir>/swe/lint-log.ndjson) and exit; lints nothing itself; requires --nonce and --units-judged (exit 4 without a valid, matching pair)")
    parser.add_argument("--findings", type=int, default=0, help="error-severity finding count to record with --record-lint-result")
    parser.add_argument("--recorded-by", default="lint-file", help="label for whoever judged the file, recorded with --record-lint-result")
    parser.add_argument("--nonce", default=None, help="the swe-lint-nonce value a prior --force-inference run printed for this file's current content; required by --record-lint-result inside a git repository")
    parser.add_argument("--units-judged", default=None, help='a coverage claim for --record-lint-result, checked against the swe-lint-units total that --force-inference\'s nonce recorded for this exact blob: "N" (every unit judged) or "N of M", quoted on the shell line (a declared partial; records as a "partial" status, not "clean"). Required inside a git repository; rejected with exit 4 when missing, when the nonce predates this flag, or when the value does not match that total; a malformed value, or N > M, is a malformed call (exit 2)')
    args = parser.parse_args()

    if args.count and (args.force_inference or args.advise_inference):
        print(
            "swe: --count cannot be combined with --force-inference or "
            "--advise-inference: --count prints no inference rules and "
            "mints no nonce, so the combination would report a two-tier "
            "pass as clean with nothing to judge",
            file=sys.stderr,
        )
        return 2

    if args.record_lint_result is not None:
        if len(args.files) != 1:
            print("swe: --record-lint-result takes exactly one file path", file=sys.stderr)
            return 2
        units_judged = None
        units_declared_total = None
        if args.units_judged is not None:
            try:
                units_judged, units_declared_total = parse_units_judged(args.units_judged)
            except ValueError as exc:
                print(f"swe: {exc}", file=sys.stderr)
                return 2
        return record_lint_result(
            args.files[0], args.record_lint_result, args.findings, args.recorded_by,
            args.nonce, units_judged, units_declared_total,
        )

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

    # sources: list of (label, findings, prose_text_for_threshold, candidate_input)
    # candidate_input is (numbered_lines, only_lines, code_lines, unit_lines).
    # numbered_lines, only_lines and code_lines feed find_register_candidates();
    # code_lines is None where there is no code-preserving mirror (a code
    # file's extracted comments, already unblanked). unit_lines
    # (claude-plugins#27) is prose_lines(readable=True), read by prose_units()
    # for the --force-inference worklist in place of numbered_lines, so a
    # unit shows a link resolved and a code span intact. candidate_input
    # itself is None where adjacency between lines is not real prose
    # adjacency (--html-file).
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
            comment_pairs = []
            for number, comment in extract_comments(text, ext):
                check_line(number, comment, vocabulary, structure_nouns, banned_rules, rules, findings)
                comment_pairs.append((number, comment))
            prose_for_threshold = "\n".join(c for _, c in comment_pairs)
            candidate_input = (comment_pairs, None, None, None)
        else:
            only_lines = changed_line_numbers(f) if (args.diff and args.added_only and f in changed_markdown_files()) else None
            findings = lint_text(text, vocabulary, structure_nouns, banned_rules, rules, exemptions, only_lines)
            numbered_lines = list(prose_lines(text, exemptions))
            code_lines = list(prose_lines(text, exemptions, keep_code=True))
            unit_lines = list(prose_lines(text, exemptions, readable=True))
            prose_for_threshold = "\n".join(line for _, line in prose_lines(text, exemptions, only_lines))
            candidate_input = (numbered_lines, only_lines, code_lines, unit_lines)
        sources.append((f, findings, prose_for_threshold, candidate_input))

    if args.text:
        text = sys.stdin.read()
        label = args.source_label or "text"
        findings = lint_text(text, vocabulary, structure_nouns, banned_rules, rules, exemptions)
        numbered_lines = list(prose_lines(text, exemptions))
        code_lines = list(prose_lines(text, exemptions, keep_code=True))
        unit_lines = list(prose_lines(text, exemptions, readable=True))
        prose_for_threshold = "\n".join(line for _, line in numbered_lines)
        sources.append((label, findings, prose_for_threshold, (numbered_lines, None, code_lines, unit_lines)))

    if args.reply_file:
        path = Path(args.reply_file)
        text = path.read_text() if path.exists() else ""
        findings = lint_text(text, vocabulary, structure_nouns, banned_rules, rules, exemptions)
        numbered_lines = list(prose_lines(text, exemptions))
        code_lines = list(prose_lines(text, exemptions, keep_code=True))
        unit_lines = list(prose_lines(text, exemptions, readable=True))
        prose_for_threshold = "\n".join(line for _, line in numbered_lines)
        sources.append(("reply", findings, prose_for_threshold, (numbered_lines, None, code_lines, unit_lines)))

    if args.transcript:
        path = Path(args.transcript)
        text = extract_transcript_reply_text(path) if path.exists() else ""
        findings = lint_text(text, vocabulary, structure_nouns, banned_rules, rules, exemptions)
        numbered_lines = list(prose_lines(text, exemptions))
        code_lines = list(prose_lines(text, exemptions, keep_code=True))
        unit_lines = list(prose_lines(text, exemptions, readable=True))
        prose_for_threshold = "\n".join(line for _, line in numbered_lines)
        sources.append(("transcript", findings, prose_for_threshold, (numbered_lines, None, code_lines, unit_lines)))

    if args.html_file:
        path = Path(args.html_file)
        text = path.read_text() if path.exists() else ""
        nodes = html_text_nodes(text, cfg["html_min_chars"])
        synthetic = "\n".join(nodes)
        findings = lint_text(synthetic, vocabulary, structure_nouns, banned_rules, rules, exemptions)
        # No candidates: adjacent text nodes are not adjacent prose lines.
        sources.append((args.html_file, findings, synthetic, None))

    if not sources:
        print("No sources to check.")
        return 0

    fetched_tag, pinned_tag, age_seconds = read_data_status()
    for line in data_status_lines(fetched_tag, pinned_tag, age_seconds):
        print(line, file=sys.stderr)

    if args.count:
        error_total = sum(1 for _, findings, _, _ in sources for _, sev, _, _ in findings if sev == "error")
        warning_total = sum(1 for _, findings, _, _ in sources for _, sev, _, _ in findings if sev == "warning")
        print(f"{error_total} errors, {warning_total} warnings across {len(sources)} files")
        return 1 if error_total else 0

    error_total = 0
    warning_total = 0
    per_source_counts = {}
    for label, findings, _, _ in sources:
        src_errors = 0
        src_warnings = 0
        for number, severity, rule, detail in findings:
            if severity == "error":
                error_total += 1
                src_errors += 1
            else:
                warning_total += 1
                src_warnings += 1
            if args.quiet_vocab and rule == "vocabulary-membership":
                continue
            print(f"{label}:{number}: [{severity}] [{rule}] {detail}")
        per_source_counts[label] = (src_errors, src_warnings)

    stop_hook_active = args.stop_hook_active == "true"

    # A single named file is the only source with a stable identity across
    # repeated edits, so it is the only one inference_eligible() throttles
    # by growth since the last time the block below was printed for it.
    inference_key = None
    if len(args.files) == 1 and not (args.text or args.reply_file or args.transcript or args.html_file):
        inference_key = str(Path(args.files[0]).resolve())

    # The numbered worklist for the single named file --force-inference
    # will mint a nonce for (claude-plugins#20), computed once so the
    # per-source print loop below and the nonce-minting block after it
    # agree on the same total. None for a multi-file call, --advise-
    # inference, or any other source kind: none of those mint a nonce to
    # bind a total to.
    nonce_units = None
    if args.force_inference and inference_key is not None and sources and sources[0][0] == args.files[0]:
        nonce_candidate_input = sources[0][3]
        if nonce_candidate_input is not None:
            nonce_units = prose_units(nonce_candidate_input[0], nonce_candidate_input[3])

    due_for_inference = args.force_inference or (args.advise_inference and error_total == 0 and not stop_hook_active)
    if due_for_inference:
        combined_prose = "\n".join(prose for _, _, prose, _ in sources if prose.strip())
        if combined_prose.strip():
            words, sentences = count_words_sentences(combined_prose)
            if args.force_inference or inference_eligible(inference_key, words, sentences, cfg):
                inference_rules = {rid: r for rid, r in rules.items() if r.get("check") == "model-judgement"}
                is_conversational = bool(args.reply_file or args.transcript)
                if is_conversational:
                    inference_rules.update(plugin_rules)
                # Located candidates (claude-plugins#18): a cheap structural
                # signal for a rule above, never itself a finding. Computed
                # once the rule set is known, only for the rule ids actually
                # applicable, and only when at least one of them is present.
                register_rule_ids = {
                    "no-cadence-device", "no-mechanical-repetition",
                    "no-unanchored-reference", "no-unstated-presupposition",
                    "define-before-use", "no-count-list-mismatch",
                } & set(inference_rules)
                lexicon = None
                if register_rule_ids:
                    lexicon = (
                        load_verb_lexicon(),
                        load_tsv_words("connectives.tsv"),
                        structure_nouns,
                        load_tsv_words("qualities.tsv"),
                        vocabulary,
                        {p.lower() for p, _, _ in banned_rules if " " not in p},
                    )
                print("===INFERENCE_ADVISED===")
                for label, _, prose, candidate_input in sources:
                    if not prose.strip():
                        continue
                    src_errors, src_warnings = per_source_counts.get(label, (0, 0))
                    candidates = None
                    if lexicon is not None and candidate_input is not None:
                        numbered_lines, only_lines, code_lines, _ = candidate_input
                        candidates = find_register_candidates(numbered_lines, only_lines, lexicon, register_rule_ids, code_lines)
                    units = nonce_units if nonce_units is not None and label == args.files[0] else None
                    for line in format_inference_rules(label, inference_rules, src_errors, src_warnings, candidates, units):
                        print(line)
                print("===END_INFERENCE_ADVISED===")
                save_inference_state(inference_key, words, sentences)

    # A nonce is minted for --force-inference on a single named file
    # regardless of whether the block above printed: a no-prose file (its
    # worklist total is 0) and a deterministically-failed file both still
    # need one, to record "clean" or "failed" later. The total and the
    # nonce are printed last, deliberately, in that order: output piped
    # through head/sed/grep loses the nonce first, then the total, so a
    # truncated Step 3 fails Step 5 loudly instead of silently reading as
    # complete (claude-plugins#10). The rules block above is now
    # finding-shaped (claude-plugins#14) and includes the unit worklist
    # (claude-plugins#20), so a findings-shaped grep keeps both even when
    # it still drops the total and nonce lines.
    if args.force_inference and inference_key is not None and sources and sources[0][0] == args.files[0]:
        units_total = len(nonce_units) if nonce_units is not None else 0
        nonce, reason = issue_lint_nonce(args.files[0], units_total)
        if nonce is not None:
            print(f"swe-lint-units: {units_total}")
            print(f"swe-lint-nonce: {nonce}")
        else:
            print(f"swe: no lint nonce issued for {args.files[0]}: {reason}")

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
