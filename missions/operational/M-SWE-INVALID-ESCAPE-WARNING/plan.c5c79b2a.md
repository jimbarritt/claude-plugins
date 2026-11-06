# Plan: claude-plugins#26 — invalid `\s` escape prints a SyntaxWarning

## The ask (verbatim)

Title: software_english_lint.py: invalid "\s" escape prints a SyntaxWarning on every run

> Every run of `software_english_lint.py` prints this to stderr before any
> finding:
>
>     software_english_lint.py:35: SyntaxWarning: "\s" is an invalid escape
>     sequence. Such sequences will not work in the future. Did you mean
>     "\\s"? A raw string is also an option.
>
> The text at line 35 is in a docstring, which quotes a regular expression
> of the form `":\s*\[(error|warning)\]"`. Python 3.12 and later report an
> unknown escape in a normal string literal as a `SyntaxWarning`, and a
> later Python version is due to make it an error.
>
> The warning lines come before the findings in the output, so a caller
> that parses the output sees two lines that are not findings.
>
> Proposed fix:
> - Make the docstring a raw string (`r"""..."""`), or escape the
>   backslash as `\\s`.
> - Add a check to CI that fails on the warning, for example:
>
>       python3 -W error::SyntaxWarning -c "import ast, sys; ast.parse(open(sys.argv[1]).read())" scripts/software_english_lint.py
>
>   and the same for every other `.py` file under `scripts/`.

https://github.com/jimbarritt/claude-plugins/issues/26

## Reading

The file is `swe/scripts/software_english_lint.py` (the issue's `scripts/...`
path is relative to the `swe/` plugin directory). Its module docstring
(lines 2–182) contains exactly one line with backslashes: line 35, quoting
the regex `":\s*\[(error|warning)\]"`. That one literal has three invalid
escapes (`\s`, `\[`, `\]`), not just the `\s` the warning names — Python only
reports the first invalid escape per literal. Every regex later in the file
(line 599 on) is already an `r"..."` string. The vendored `_vendor/tomli/*.py`
files are clean, and there are no other `.py` files in the repo.

Python 3.11 reports the same fault as a `DeprecationWarning`, not a
`SyntaxWarning` — the issue's proposed CI command only catches the bug on
3.12+. A check needs both warning classes, or a pinned 3.12+ interpreter.

No CI workflow currently runs the `swe/tests/*_test.sh` suites; they run by
hand and via the maintainer Routine. `check-unshipped.yml` and
`release-plugin.yml` are the only workflows.

## Plan

1. **Fix the docstring.** In `swe/scripts/software_english_lint.py` line 2,
   prefix the module docstring with `r` (`r"""Software English linter: ...`).
   This is the only change needed to the string: `__doc__` keeps the same
   text since Python already preserved the unknown escapes as written.
2. **Add a regression test**, `swe/tests/python_syntax_warnings_test.sh`,
   following the style of `swe/tests/skill_frontmatter_test.sh` (shebang,
   header comment citing claude-plugins#26 and the 3.11/3.12 warning-class
   difference, `assert`/PASS/FAIL helper, final pass/fail summary). For every
   `.py` file under `swe/scripts` (including `_vendor`), compile it with
   `python3 -W error::SyntaxWarning -W error::DeprecationWarning -c
   'compile(open(sys.argv[1]).read(), sys.argv[1], "exec")'` and assert
   success; assert the glob matches at least 5 files so an empty match can't
   pass silently.
3. **Add a CI workflow**, `.github/workflows/swe-python-syntax.yml` (kept
   separate from `check-unshipped.yml`'s single job), triggered on push to
   main, pull_request, and workflow_dispatch, using `actions/setup-python@v5`
   with Python 3.12, running the new test script.
4. **Release.** Bump `swe/.claude-plugin/plugin.json` version (patch) in the
   same commit as the fix, per the repo's release rule.

### Out of scope

No other docstring, regex, or vendored-file change is needed — the escape
fault is confined to line 2/35 of `software_english_lint.py`.
