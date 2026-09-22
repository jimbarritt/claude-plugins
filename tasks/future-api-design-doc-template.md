# Future task: API Design document type for software-english

**This is the next task.** Start here.

No GitHub issue filed. Raised by Jim in conversation, opening a new
mission, separate from the `claude-plugins`/`software-english` work in
progress.

## Next steps (for the session that picks this up)

1. Check `jimbarritt/claude-plugins` issues for Jim's worked example:
   a distilled version of a real API design document of his,
   including a request/response format he found worked well. He
   plans to file it tomorrow (day after 2026-09-22) and test the
   template against it directly, then give feedback as further GitHub
   issues. If it is not there yet, ask before designing further.
2. Write `templates/api-design.md` in `software-english` against the
   draft structure below, using the worked example as the real test.
   Follow the pattern the Design type used
   (`templates/design.md`): a cached summary, canonical sources
   listed up top, "Software English addition" called out
   explicitly for anything not from a cited source (the structure
   itself, the `type`-only rule, the examples-required rule, the two
   example formats).
3. Add an Appendix F row to `software-english/spec/SPEC.md`, citing
   the canonical sources from the Research table below (RFC 9110/9112
   for HTTP, Apache Avro and JSON Schema for schemas, OpenAPI and
   AsyncAPI as cross-references, CloudEvents where used).
4. Lint every new and touched file with
   `python3 <claude-plugins>/swe/scripts/software_english_lint.py --quiet-vocab <files>`
   before committing, the way every other change in this session did.
5. Check whether the change needs a `software-english` version bump.
   Precedent from the Design type addition
   (`tasks/issue-7-8-design-type-and-style-cost.md`): the `swe`
   plugin only fetches `rules/core-rules.toml` and `vocabulary/`, not
   `templates/` or `SPEC.md`, so adding the template and the Appendix
   F row alone may need no bump; a bump is needed only if
   `core-rules.toml` itself changes (for example, a §7.9-style
   exclusion naming the new type).
6. Once Jim's real feedback comes in as further issues on
   `claude-plugins`, treat each one as a normal issue against this
   task, the same as any other.

## Ask

Jim, verbatim: "I spend a lot of time designing APIS I think we should
design a document template / format for API design. I will tell you
more about it. Create a task and we can start soecccing it out. One
part of it will be a format for presenting apps requests and
responses."

Read as: a document template/format for designing APIs generally
("apps requests and responses" read as a typo for API requests and
responses).

## Decisions so far

Captured from conversation with Jim, 2026-09-22.

- **Deliverable:** a new document type in `software-english`, added to
  SPEC.md Appendix F with a cached reference file under `templates/`,
  the way the Design type was added (claude-plugins#8,
  `software-english` v0.0.4).
- **Scope:** HTTP APIs and event/message APIs, both.
- **Content the template covers:**
  - endpoint (or channel/topic) definitions and schema definitions;
  - example requests and responses, in a canonical HTTP format (the
    HTTP/1.1 message syntax of RFC 9112, or the `.http` file form of
    it); the message-API equivalent is not yet chosen;
  - design-document sections: context, open questions;
  - appendices: prior art, schemas;
  - the schema appendix offers a choice between Avro and JSON Schema.
    Jim's last real API design used an Avro appendix (Avro is in use
    at work).
- **OpenAPI:** the template does not reuse the OpenAPI document
  structure. OpenAPI (and AsyncAPI) are cross-references: an OpenAPI
  document may later be generated from a document in this format.
- **Message-side model:** Kafka topics with Avro payloads and a schema
  registry (what Jim uses at work).
  **Decided: message example format**, 2026-09-22, mirroring RFC
  9112's request line / headers / blank line / body shape:
  ```text
  topic:   orders.order-placed.v1
  key:     ord_01J8ZK3QW4N9X2M7P5R1T6V0B8
  schema:  orders.order-placed.v1-value, version 3

  headers:
    <any headers actually sent, plain key: value>

  value:
  { ... Avro record rendered as JSON, in the entity schema's shape ... }
  ```
  `topic`/`key` play the request line's role; `schema` names the
  registry subject and version, the one part with no HTTP equivalent;
  `value` is the Avro record as JSON (binary Avro is not readable) and
  uses the same TypeScript type as the entity schema. `headers` is
  empty by default: CloudEvents was not confirmed in use, so it is not
  assumed. A document that does use CloudEvents states that in its
  context section, and the headers block then follows CloudEvents'
  own naming, cited by reference (CloudEvents 1.0.2, CNCF, from the
  source research above).
- **Parent type:** a specialisation of the Design type. Jim confirmed
  this on 2026-09-22. All seven of Design's sections carry over
  (context and scope, goals and non-goals, the design, alternatives
  considered, cross-cutting concerns, open questions, future
  extensions), with the API-specific content (endpoints/channels,
  schemas, request/response examples) added on top. Trim later if any
  section proves not to fit.
- **Schema notation, two layers:** a literate definition in the body,
  for a human reader, and a formal schema (Avro or JSON Schema) as the
  registered artefact. The criterion for the literate layer is the
  number of constructs a reader has to hold: fewer is better.
  - **Decided: TypeScript `type` aliases** are the literate notation
    (Jim used them in his last document). Style rule: `type` only, no
    `interface`. Constraints a type cannot express (RFC 3339, decimal
    string, minimum) go in trailing comments. Recorded as
    `docs/adr/001-typescript-type-aliases-as-literate-schema-notation.md`
    in `software-english`, on `main` at
    [`697cf1b`](https://github.com/jimbarritt/software-english/commit/697cf1b).
    Protobuf, GraphQL SDL, CUE, Smithy, Zod/TypeBox and a field table
    were also assessed there and rejected.
  - Avro IDL rejected as the literate form: `record`/`protocol` flips
    the domain model into Avro's terms, which reads as unintuitive.
  - TypeSpec rejected as too noisy (Jim, 2026-09-22). Evaluated by
    compiling an Order example with TypeSpec 1.16.0 in the scratchpad:
    `@pattern`, `@minValue`, `@minItems`, doc comments and
    `utcDateTime` all emit into OpenAPI 3.0 and JSON Schema 2020-12,
    and one `interface` line emits the endpoint with 200 and 404, but
    it costs five constructs (`model`, `scalar`, `enum`, decorators,
    `#{ }`) where TypeScript needs one. No Avro emitter. Keep it in
    mind only as a possible generation route from the formal layer,
    not as document content.
- **Style rule:** every endpoint or message shows at least one example
  request and response. Jim reads examples first.
- **Worked example:** Jim will distil his last real API design
  document and file it as a GitHub issue on `claude-plugins`. Design
  the template against that once it arrives.

## Draft document structure

Agreed with Jim, 2026-09-22. The seven Design sections keep Design's
own order. Every API-specific part sits inside section 3, so the
specialisation adds depth, not new top-level sections.

```text
Title: <API name> API design
Status / date / author

1. Context and scope
2. Goals and non-goals
3. The design
   3.1 Entity schema
       - one TypeScript `type` per entity
       - trailing comments for any constraint the type cannot express
   3.2 HTTP endpoints
       - one subsection per endpoint
       - signature line, then at least one example exchange, raw HTTP
   3.3 Events and messages
       - one subsection per topic
       - topic, key, schema subject/version, headers, example value
         (Avro as JSON), decided format below
   3.4 Errors
       - error shape as a type, status code table, one example
   3.5 Versioning and compatibility
4. Alternatives considered
5. Cross-cutting concerns
   - security, authentication, observability, idempotency, rate limits
6. Open questions
7. Future extensions

Appendix A. Prior art
Appendix B. Formal schemas (Avro or JSON Schema)
Appendix C. Generated artefacts (OpenAPI or AsyncAPI), if any
```

Notes on the shape:

- 3.1 comes before the endpoints because an endpoint example refers to
  the types.
- Prior art is an appendix, distinct from section 4. Section 4 holds
  the alternatives for this design. The appendix holds what exists
  elsewhere.
- 3.4 and 3.5 are fixed subsections, not cross-cutting concerns. Jim
  confirmed this on 2026-09-22.
- "Entity schema" is Jim's name for 3.1, chosen over "Model".

## Constraint from the spec

Appendix F is by reference only. Each type cites a canonical external
source and keeps a cached summary in `templates/`; Software English
does not define a structure itself. Any addition that is Software
English's own must be marked as such, the way `templates/design.md`
marks its open-questions and future-extension sections. So this type
needs one or more canonical sources to cite.

## Status

Scoping done. Deliverable, scope, the seven-section structure, both
example formats, the schema notation, and the goals/non-goals
question are all decided and recorded above. The only thing blocking
writing `templates/api-design.md` itself is Jim's worked example,
expected as a `claude-plugins` issue. See Next steps above.

## Research: candidate sources

Verified 2026-09-22 by a research agent, mostly from the publishers'
GitHub repositories, since the session proxy blocked several of the
canonical sites. Re-verify the canonical URL when writing the cached
reference file.

| Source | URL | Version/date | Publisher | Governs for the template |
|---|---|---|---|---|
| RFC 9110 HTTP Semantics | https://www.rfc-editor.org/rfc/rfc9110.html | June 2022, STD 97 | IETF HTTP WG | Method, status code, header semantics |
| RFC 9112 HTTP/1.1 | https://www.rfc-editor.org/rfc/rfc9112.html | June 2022, STD 99, obsoletes RFC 7230 | IETF HTTP WG | Syntax of example requests and responses |
| JSON Schema | https://json-schema.org/specification | 2020-12; self-published under OpenJS Foundation, IETF track dropped Oct 2022 | JSON Schema project | Schema blocks, JSON Schema form |
| Apache Avro | https://avro.apache.org/docs/current/specification/ | 1.12.2, 2026-08-23 | Apache Software Foundation | Schema blocks, Avro form |
| CloudEvents | https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/spec.md | 1.0.2, 2024-02-06 | CNCF | Event envelope attributes |
| OpenAPI | https://spec.openapis.org/oas/latest.html | 3.2.1, 2026-09-10 | OpenAPI Initiative | Cross-reference: generation target, HTTP |
| AsyncAPI | https://www.asyncapi.com/docs/reference/specification/v3.1.0 | 3.1.0, 2026-01-31 | AsyncAPI Initiative | Cross-reference: generation target, messages; names Avro 1.9.0 as recommended schema format |
| JetBrains HTTP Request in Editor spec | https://github.com/JetBrains/http-request-in-editor-spec/blob/master/spec.md | undated, last commit 2023-05-30, TODO sections, aligns to RFC 7230 | JetBrains | Convention for `.http` request blocks |
| VS Code REST Client | https://github.com/Huachao/vscode-restclient | README only, cites RFC 2616 | individual | Same block format, no written spec |
| HAR 1.2 | http://www.softwareishard.com/blog/har-12-spec/ | W3C draft (2012) marked abandoned | individual | Weak; convention only |
| Google AIPs | https://google.aip.dev/ | rolling | Google | HTTP and gRPC resource design; no event AIP; AIP-100 names "API design review", no template |
| Microsoft REST API Guidelines | https://github.com/microsoft/api-guidelines | top-level file deprecated; Azure guidelines changed 2025-03-28 | Microsoft | HTTP only |
| Zalando RESTful API and Event Guidelines | https://opensource.zalando.com/restful-api-guidelines/ | rolling | Zalando | REST and events; event schemas use OpenAPI Schema Object, no Avro or CloudEvents |

Findings that shape the design:

- No source defines an "API design document" as a document type with a
  template. The document structure is therefore Software English's own
  addition, marked as such; the parts (HTTP syntax, schema languages,
  event envelope) are cited by reference.
- The `.http` format has no versioned spec. Cite it as a convention,
  with RFC 9112 as the standard behind it.
- AsyncAPI 3.1.0 names JSON Schema draft-07 as its required schema
  format; OpenAPI 3.1+ uses 2020-12. A generator from this document
  type has to handle both.

## Open questions

- ~~What the canonical example format is for an event/message
  exchange.~~ Resolved 2026-09-22; see the message example format
  above.
- ~~Where "goals and non-goals" comes from.~~ Resolved. Jim's own
  research confirms it: a Google convention (Ubl, "Design Docs at
  Google"), no formal spec, no earlier unrelated use found, copied
  directly into other companies' templates (Squarespace's RFC
  template). An IETF-charter lead was ruled out: RFC 1603/2418
  require "Goals and milestones", a timetabled deliverable list, not
  a Goals/Non-Goals pair. Recorded as
  `docs/kb/goals-and-non-goals-origin.md` in `software-english`, on
  `main` at
  [`b2d2b2c`](https://github.com/jimbarritt/software-english/commit/b2d2b2c),
  which also adds the `docs/kb/` directory for research notes
  backing a spec or template decision.
  Recommendation in that note, for the API Design type to consider:
  keep both headings, but require each Goal to state its own success
  criterion, not only its aim (the Kubernetes KEP fix), since a bare
  list of aims reads informally otherwise.
- ~~Whether the request/response format needs its own rules in
  `core-rules.toml`.~~ Folded into
  [future-lint-document-profiles.md](future-lint-document-profiles.md)
  on 2026-09-22, at Jim's direction: the linter skips all fenced code,
  so the request/response examples, message examples, and entity-
  schema `type` declarations are unchecked today regardless of what
  `core-rules.toml` says. Three concrete checks identified there (the
  `type`-only rule, an examples-required structural check, fence
  well-formedness) need the linter to look inside a specific fence
  language, which is new scope, the same question that task already
  asks about document-type profiles generally.

Settled by the research above: no source serves as a structural model
for the document itself, so the structure is Software English's own
addition.
