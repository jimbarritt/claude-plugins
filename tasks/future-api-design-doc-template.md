# Future task: API Design document type for software-english

No GitHub issue filed. Raised by Jim in conversation, opening a new
mission, separate from the `claude-plugins`/`software-english` work in
progress.

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
  registry (what Jim uses at work). A message example therefore shows
  topic, key, and the Avro payload, with the registered schema subject
  and version.
- **Worked example:** Jim will distil his last real API design
  document and file it as a GitHub issue on `claude-plugins`. Design
  the template against that once it arrives.

## Constraint from the spec

Appendix F is by reference only. Each type cites a canonical external
source and keeps a cached summary in `templates/`; Software English
does not define a structure itself. Any addition that is Software
English's own must be marked as such, the way `templates/design.md`
marks its open-questions and future-extension sections. So this type
needs one or more canonical sources to cite.

## Status

Scoping in progress. Research running on candidate canonical sources:
OpenAPI, AsyncAPI, RFC 9110/9112, JSON Schema, Apache Avro, CloudEvents,
the `.http` file format, HAR, and the Google, Microsoft, and Zalando
API design guides. Jim's direction: all of these are good references
to include; OpenAPI as a cross-reference, not the structure.

## Open questions

- Which source, if any, serves as the structural model for the
  document itself, as opposed to the parts (HTTP syntax, schema
  languages) it cites.
- What the canonical example format is for an event/message exchange,
  matching the raw-HTTP form for an HTTP exchange.
- Whether the request/response format needs its own rules in
  `core-rules.toml`, or only the template file.
