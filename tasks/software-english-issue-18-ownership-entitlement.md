# software-english#18: possession and entitlement require an animate possessor

Tracker: `jimbarritt/software-english`. Opened by `jimbarritt-pleo` (trusted
collaborator) on 2026-10-21T10:08:36Z.

## The ask (verbatim)

> ## Verdict
>
> `false-negative`. No existing rule names this.
>
> ## The shape
>
> A possession or entitlement construction is used with a possessor that
> cannot possess. The plain possessive is correct: a system has records, a
> service has a config. The fault is the layer added on top of it.
>
> The family, none of which appears in any vocabulary file today:
>
> - `own`, `its own`, `of its own`, `in its own right`
> - `belongs to`, `is entitled to`, `has a right to`
> - `deserves`, `earns`, `claims`, `is owed`
>
> Example of the fault:
>
> > The dispatch queue's own copy of the manifest is rebuilt nightly.
>
> Repaired by dropping the added layer and keeping the possessive:
>
> > The dispatch queue's copy of the manifest is rebuilt nightly.
>
> Cutting `own` changes nothing the sentence states. That is the test for
> the emphasis being empty.
>
> ## Why this is not `anthropomorphism-paraphrase`
>
> `anthropomorphism-paraphrase` (SPEC §5.1) covers a category error about
> **mind**: wanting, trying, knowing, deciding, giving up. The family above
> is a category error about **status**: the standing to hold property and
> to claim desert.
>
> Neither entails the other, and the repairs differ. A mental state is
> repaired by naming the mechanism. A possessive is repaired by cutting the
> added layer and keeping what was already correct.
>
> ## Why it cannot be a substitution or banned-word entry
>
> Every construction above is correct with an animate possessor:
>
> > the user's own pen
> > the author's own draft
> > the team deserves the time
>
> The string cannot decide it. The possessor does. So the check is: fire
> when the possessor or subject is a system, service, component, process,
> document or record; do not fire when it is a person or an organisation of
> people.
>
> ## Non-trigger, stated explicitly
>
> A plain possessive is not a fault. `the service's config` and `the
> record's identifier` both stand. The rule fires only on the emphasis or
> entitlement layer, never on the possessive itself.
>
> ## Proposed direction
>
> One new inference-based rule covering the whole family, triggered on
> possessor animacy. One animacy test decides every member, which is the
> argument for a single rule rather than entries scattered across two.

## Reading

The issue's split from §5.1 holds: §5.1 is a category error about mind,
this is a category error about status (standing to own or to claim
desert), and the two repairs differ (name the mechanism vs. cut the added
layer). Two refinements the issue doesn't state but the existing spec text
forces:

- Animacy of the possessor is necessary but not sufficient. `own` already
  appears correctly with an inanimate possessor in the shipped spec itself,
  meaning "one each, not shared" (`each event on its own topic`, SPEC
  §3.6/§5.9 fix text; `its own sentence`, §8.1). The issue's own test
  ("cutting `own` changes nothing the sentence states") has to be a second,
  independent condition, not just restated motivation, or the new rule
  fires on the project's own correct fix text.
- `belongs to` needs a sense split. §5.2 names `belongs to` as the correct
  plain classification verb for an abstract subject (`a rule belongs to one
  tier`), and §7.6 and `structure.tsv` use it the same way. The new rule
  must fire on `belongs to` only where its object is a possessor (`the lock
  belongs to the process`), never where the object is a set or whole the
  subject is a member or part of.

A dispatched Plan subagent (Opus) read the whole of SPEC §5, the most
recent inference-tier rule addition (§7.19, commit 3b4bb30, as a model of
expected depth and of the "Distinct from" cross-reference convention),
`core-rules.toml`'s `[[rules]]` format, `docs/claude-md-ruleset.md`,
`docs/agent-guide.md`, and `vocabulary/*.tsv`, and produced the plan below.
Plan agreed with: inference-based tier (not mixed — a fixed-phrase list
with a subject check, as §5.1 uses, would fire on §5.2's correct `belongs
to` classification use and on the project's own correct distributive
`own`), placement as a new §5.11 (end of §5, same category-error family as
§5.1/§5.2, no renumbering), and no vocabulary-file or
`claude-md-ruleset.md` change (the rule is inference-based, and the recent
precedents §5.10/§7.19 shipped via SPEC.md + core-rules.toml only).

## Plan

### 1. Placement and tier

New **§5.11**, end of §5 (Semantic rules), inserted after the current §5.10
(SPEC.md:595) and before "## 6. Vocabulary rules". Tier: **inference-based**
(`check = "model-judgement"`, `severity = "warning"`). Rejected mixed tier:
every family member has at least one correct use with a system possessor
(`belongs to` as classification, distributive `own`, or a term of art such
as a worker `claims` a job / a deposit `earns` interest), so a fixed list
with a subject-proximity test would misfire, unlike §5.1 where none of its
listed verbs has a correct sense with a system subject.

### 2. Rule id

`no-ownership-or-entitlement-for-a-system`

### 3. SPEC.md edits

**Contents** (insert after SPEC.md:36):

```
  - [5.11 No ownership or entitlement for a system](#511-no-ownership-or-entitlement-for-a-system-inference-based)
```

**New section** (insert after SPEC.md:595, before "## 6. Vocabulary rules"):

```
### 5.11 No ownership or entitlement for a system (Inference-based)

This rule applies to every document type.

A plain possessive states a fact: a service has a config, a record has
an identifier. A possession or entitlement construction adds a second
layer. It states that the possessor owns the thing, or has the
standing to claim it. Only a person or an organisation of people has
that standing. A system, a service, a component, a process, a
document, a record, or an abstract concept does not.

The family has two groups:

- emphasis on a possessive: `own`, `its own`, `of its own`, `in its
  own right`;
- entitlement: `belongs to`, `is entitled to`, `has a right to`,
  `deserves`, `earns`, `claims`, `is owed`.

Fault:

> The dispatch queue's own copy of the manifest is rebuilt nightly.

Cutting `own` changes nothing the sentence states. Cut the layer and
keep the possessive:

> The dispatch queue's copy of the manifest is rebuilt nightly.

An idiom of standing is the same fault:

> The cache is a service in its own right.

Cut the idiom:

> The cache is a service.

An entitlement has no plain possessive under it. State the allocation,
and name the mechanism that makes it:

> Each partition is entitled to one consumer in the group.

> The group coordinator assigns each partition to one consumer in the
> group.

`belongs to` names the possessor in its object, not its subject:

> Each lock belongs to the process that acquired it.

> Only the process that acquired a lock can release it.

`deserves` and `earns` state a judgement of desert. State the fact
the judgement rests on, or the instruction it implies:

> The retry path deserves a dedicated thread pool.

> Run the retry path on a dedicated thread pool, so a burst of retries
> does not delay a new request.

Test: find the possessor. It is the subject of `deserves`, `earns`,
`claims`, `is owed`, `is entitled to`, or `has a right to`, the object
of `belongs to`, or the noun or pronoun before `own`. Where it is a
person or an organisation of people, the sentence is correct.
Otherwise, cut the layer, or replace it with a plain possessive, `has`,
or the mechanism that allocates the thing. If a reader loses no fact,
the layer was this fault.

These are not this fault:

- a plain possessive or a plain `has`, with any possessor: `the
  service's config`, `the record's identifier`, `the queue has three
  consumers`;
- a possessor that is a person or an organisation of people: `the
  user's own pen`, `the author's own draft`, `the team deserves the
  time`, `the company owns the domain name`, since an organisation can
  own property in law;
- an idiom of standing about a person: `she is a maintainer in her own
  right`;
- `own` that states a fact, one each and not shared: `each event on
  its own topic`, `each worker keeps its own copy of the cache`.
  Cutting `own` here loses the fact that no two share one, so the test
  above passes it;
- `belongs to` as classification or membership, the plain verb §5.2
  names: `a rule belongs to one tier`, `the record belongs to
  partition 3`. Where `is a member of` or `is part of` states the same
  fact, the verb classifies;
- a term of art that names an operation, not a standing: `the worker
  claims the next job`, where a claim is a lease the queue records, or
  `the deposit earns interest`;
- `claims that` in the sense of states (`the README claims that the
  tool supports Windows`), which names no standing. Where it marks the
  writer's doubt, §5.3 applies;
- quoted material (§6.3) or a literal token (§6.2).

Other rules have a nearby claim:

- §5.1 covers a category error about mind: wanting, trying, knowing,
  deciding. This rule covers a category error about status: the
  standing to own a thing or to claim a desert. Neither entails the
  other, and the fixes differ. §5.1 names the mechanism. This rule
  cuts the added layer and keeps the possessive. Where one sentence
  has both (`the cache knows its own size`), report two findings, one
  under each rule.
- §5.2 names `belongs to` as the plain classification verb that
  replaces a location verb. That use is correct here too: its object
  is a set or a whole, not a possessor. This rule fires on `belongs
  to` only where the object is a system said to own the subject. §5.2
  judges a location or motion verb, so the two rules never judge one
  verb.
- §5.5 bans `carry` and `hold` as verbs of physical possession, and
  replaces each with `has` or `contains`. This rule keeps the plain
  possession verb, and cuts an emphasis or an entitlement added to it.
  `in its own right` and `earns its place` are idioms, not
  comparisons: report them under this rule only.
- §5.3: `deserves` and `earns` can state the writer's judgement only.
  Where no fact remains once the judgement is cut (`the refactor
  deserves praise`), report it under §5.3 only, since the fix deletes
  the sentence. Where a fact remains, report it under this rule only.
- §5.4 cuts a qualifier that adds no information. `own` adds none
  either, but it attaches to a possessor, and the possessor decides
  the fault. Report `own` under this rule only.
- §6.1 judges the sense of an approved word by lookup. No word in this
  family is in the approved vocabulary, so vocabulary-membership
  reports each one as unlisted, whatever the possessor. This rule
  judges the possessor, which no lookup reads.

Not a banned-word entry, and not a fixed list with a subject check
like §5.1's. Each construction is correct with a person as the
possessor. A subject check would also fire on three correct uses with
a system as the possessor: `belongs to` as classification, `own`
meaning one each, and a term of art. A parser can find each member of
the family. Whether the possessor is a person, and whether the cut
loses a fact, needs judgement, so this stays inference-based.
```

**Cross-reference appends:**

- §5.1, append after SPEC.md:272:
  ```
  Distinct from §5.11: a claim of ownership or entitlement (`its own
  copy`, `is entitled to`, `deserves`) gives a system a status, not a
  mind. Report it under §5.11.
  ```
- §5.2, append after SPEC.md:302:
  ```
  `belongs to` stays correct as this rule's fix: its object is a set
  or a whole the subject is part of. §5.11 judges `belongs to` only
  where its object is a system said to own the subject (`the lock
  belongs to the process`).
  ```

**Worked-text fix** (text the judging model reads word for word, per
commit f7890c2's note; scope set by commit 321718e — fix worked examples
and their explanations only, leave general prose alone):

- SPEC.md:187 (and the matching `core-rules.toml:51`): change `"Their
  contract is below" states no fact of its own` to `states no fact`.

Leave alone (per the same 321718e scope, listed in the commit message, not
changed): "Software English's own" (toml:144, :152), "the document's own
purpose" (toml:152), "the framework's own words"
(templates/tutorial.md:12), and COLOPHON/template uses. Keep as written
(excluded senses): "each on its own topic" (toml:51/194, SPEC:197/491),
"its own sentence" (toml:244), and every `belongs to` (toml:105/123/159/187,
structure.tsv:76).

### 4. core-rules.toml edits

New `[[rules]]` entry, inserted after the `no-framing-device` block (ends
line 201), before `no-out-of-scope-comparand`:

```toml
[[rules]]
id = "no-ownership-or-entitlement-for-a-system"
tier = "inference-based"
check = "model-judgement"
severity = "warning"
trigger_phrases = [
  "own", "its own", "of its own", "in its own right", "belongs to",
  "is entitled to", "has a right to", "deserves", "earns", "claims",
  "is owed",
]
description = "A possession or an entitlement construction needs a possessor that is a person or an organisation of people (SPEC §5.11). A plain possessive states a fact with any possessor: a service has a config, a record has an identifier. The fault is a layer added on top of it, which gives a system, a service, a component, a process, a document, a record, or an abstract concept a standing it cannot have: the standing to own a thing, or to claim a desert. The family: emphasis on a possessive ('own', 'its own', 'of its own', 'in its own right') and entitlement ('belongs to', 'is entitled to', 'has a right to', 'deserves', 'earns', 'claims', 'is owed'). Fault: 'The dispatch queue's own copy of the manifest is rebuilt nightly.' Cutting 'own' changes nothing the sentence states. Fix: cut the layer and keep the possessive, 'The dispatch queue's copy of the manifest is rebuilt nightly.' Fault: 'The cache is a service in its own right.' Fix: 'The cache is a service.' An entitlement has no plain possessive under it: state the allocation, and name the mechanism that makes it. Fault: 'Each partition is entitled to one consumer in the group.' Fix: 'The group coordinator assigns each partition to one consumer in the group.' Fault: 'Each lock belongs to the process that acquired it.' Fix: 'Only the process that acquired a lock can release it.' Fault: 'The retry path deserves a dedicated thread pool.' Fix: 'Run the retry path on a dedicated thread pool, so a burst of retries does not delay a new request.' Judge in two steps: first find the possessor of each family member, which is the subject of 'deserves', 'earns', 'claims', 'is owed', 'is entitled to', or 'has a right to', the object of 'belongs to', or the noun or pronoun before 'own'; then, where the possessor is not a person or an organisation of people, cut the layer or replace it with a plain possessive, 'has', or the mechanism that allocates the thing, and check whether a reader loses a fact. Report a finding only where the possessor is not a person or an organisation of people and the replacement loses no fact. Not this fault: a plain possessive or a plain 'has' with any possessor ('the service's config', 'the record's identifier', 'the queue has three consumers'); a possessor that is a person or an organisation of people ('the user's own pen', 'the author's own draft', 'the team deserves the time', 'the company owns the domain name'), since an organisation can own property in law; an idiom of standing about a person ('she is a maintainer in her own right'); 'own' that states a fact, one each and not shared ('each event on its own topic', 'each worker keeps its own copy of the cache'), since cutting it loses the fact that no two share one; 'belongs to' as classification or membership, the plain verb SPEC §5.2 names ('a rule belongs to one tier', 'the record belongs to partition 3'), where 'is a member of' or 'is part of' states the same fact; a term of art that names an operation, not a standing ('the worker claims the next job', where a claim is a lease the queue records; 'the deposit earns interest'); 'claims that' in the sense of states ('the README claims that the tool supports Windows'), which names no standing, and where it marks the writer's doubt SPEC §5.3 applies; quoted material (SPEC §6.3) or a literal token (SPEC §6.2). Distinct from anthropomorphism-fixed-list and anthropomorphism-paraphrase (SPEC §5.1): those cover a category error about mind (wanting, trying, knowing, deciding), and this rule covers a category error about status. Neither entails the other, and the fixes differ: SPEC §5.1 names the mechanism, and this rule cuts the added layer and keeps the possessive. Where one sentence has both ('the cache knows its own size'), report two findings, one under each rule. Distinct from abstract-location (SPEC §5.2): that rule names 'belongs to' as the plain classification verb, and that use is correct here too, since its object is a set or a whole, not a possessor; this rule fires on 'belongs to' only where the object is a system said to own the subject, so the two rules never judge one verb. Distinct from no-metaphor-or-analogy (SPEC §5.5): that rule bans 'carry' and 'hold' as verbs of physical possession and replaces each with 'has' or 'contains'; this rule keeps the plain possession verb and cuts an emphasis or an entitlement added to it. 'In its own right' and 'earns its place' are idioms, not comparisons: report them under this rule only. Distinct from SPEC §5.3: where no fact remains once a judgement of desert is cut ('the refactor deserves praise'), report it under SPEC §5.3 only, since the fix deletes the sentence; where a fact remains, report it under this rule only. Distinct from SPEC §5.4: 'own' adds no information, like a hedge, but it attaches to a possessor, and the possessor decides the fault; report it under this rule only. Distinct from SPEC §6.1, which judges an approved word by lookup: no word in this family is in the approved vocabulary, so vocabulary-membership reports each one as unlisted whatever the possessor, and this rule says which uses are faults. Not a banned-word entry, and not a fixed list with a subject check like anthropomorphism-fixed-list: each construction is correct with a person as the possessor, and a subject check would also fire on 'belongs to' as classification, on 'own' meaning one each, and on a term of art. A parser can find each member of the family, but whether the possessor is a person, and whether the cut loses a fact, needs judgement, so this stays inference-based."
```

Cross-reference appends to existing entries:

- `anthropomorphism-paraphrase` (line 112): append ` A claim of
  ownership or entitlement ('its own copy', 'is entitled to',
  'deserves') gives a system a status, not a mind: report it under
  no-ownership-or-entitlement-for-a-system (SPEC §5.11).`
- `abstract-location` (line 105): append ` "belongs to" as this rule's
  fix is correct: its object is a set or a whole.
  no-ownership-or-entitlement-for-a-system (SPEC §5.11) judges "belongs
  to" only where its object is a system said to own the subject.`

Worked-text fix: `core-rules.toml:130`, change `a question-shaped heading
that names its own referent` to `names its referent` (same rationale as
the SPEC.md:187 fix above).

§5.3, §5.4 and §6.1 have no rule ids in the catalogue; cite them as "SPEC
§5.x" only, per house convention.

### 5. docs/claude-md-ruleset.md and vocabulary/*.tsv

No change to either. The ruleset file covers deterministic-tier
highest-frequency faults only; this rule is inference-based, matching how
§5.10 and §7.19 shipped. No family word or phrase exists in any
vocabulary file today (confirmed by grep); §5.1's and §5.2's fixed lists
live inline in the TOML description and SPEC prose only, and this rule
has no fixed list (no banned.tsv entry either, for the same misfire
reasons as the rejected mixed-tier design).

### 6. Verification before commit

- `python3 -c "import tomllib;print(len(tomllib.load(open('rules/core-rules.toml','rb'))['rules']))"`
  must print one more than the current count.
- Grep the new SPEC/TOML text for `—` (em dash, banned by §3.5) and for
  `holds`/`carries`/`sits`/`lives` outside blockquote examples.
- Confirm the anchor `#511-no-ownership-or-entitlement-for-a-system-inference-based`
  matches the heading slug GitHub/most Markdown renderers generate.
- Run `/swe:lint-file` (or equivalent) on the touched prose, per
  MAINTAINER-RUN.md step 5.

### 7. Commit and release

Commit message: `Add no-ownership-or-entitlement-for-a-system (SPEC
§5.11): ownership or entitlement given to a non-person possessor`, body
covering the two departures from the issue (the cut-test as a second,
independent condition; the `belongs to` sense split against §5.2) and the
term-of-art exclusions, ending `Closes #18` plus attribution lines.
`software-english` has no `version` file (MAINTAINER-RUN.md step 6); step 7
runs `release.yml` with the next patch version after the newest `v*` tag.
This change touches only `spec/SPEC.md` and `rules/core-rules.toml`
(`core-rules.toml` is under `rules/`), so per step 7 the `swe` plugin also
needs its pinned tag bumped and a `release-plugin.yml` run for `swe`.

### Open points noted, not blocking

- `owns` (as in "Which process owns the cache", toml:130) is outside the
  issue's named family; left for a possible follow-up issue, not added
  here.
- Whether `claims that` (assertion sense) should ever report under §5.3
  instead of nowhere: left as "reports under §5.3 when it marks doubt,
  otherwise not this fault" per the plan above; no outstanding question to
  the author on this point, it is resolved in the exclusion list.

Neither open point is a "two readings lead to materially different work"
blocker under MAINTAINER-RUN.md's Escalate criteria: both are narrow,
resolved by the plan's own text, and left as documented scope decisions.
