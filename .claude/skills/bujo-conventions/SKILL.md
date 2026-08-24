---
name: bujo-conventions
description: The invariants every change to bujo must respect - schema semantics, the shared grammar, where things go, and which documents rule. Use BEFORE touching models, migrations, lib/bujo, or wondering where something belongs. Triggers - new model, migration, Entry, Collection, rapid log, parser, schema, sync columns, soft delete, migration chain, glyph, "where does X go", PLAN.md.
---

# Bujo conventions

Rails 8 omakase, deliberately: fat framework, no service-object or
clean-architecture layering, models in `app/models`, plain ERB +
Hotwire. The two ruling documents are `PLAN.md` (status, decisions —
operator-edited only) and `ARCHITECTURE.md` (the sync design; its
schema semantics bind every change now, even though sync ships in
phase 2). Slice specs live in `docs/slices/` and pre-decide their
scope; read the relevant one before changing anything it covers.

## Schema invariants (violating these breaks sync before it exists)

- **Entries and collections mint UUIDv7 string ids** via the
  `UuidV7Id` concern; caller-supplied ids must survive (`||=`).
  `users.id` stays the generator's integer — users never sync.
- **Logs are date queries, not containers**: Daily/Monthly/Future
  Logs are scopes on `Entry` (`daily_log`, `monthly_calendar`,
  `monthly_tasks`, `future_log`, `open_tasks`). Never invent a
  container table for a log. Collections are custom collections only.
- **Migration is append-only**: `migrate_to!`/`schedule_to!` create a
  successor and mark the predecessor `migrated`; the unique index on
  `migrated_from_id` keeps the chain a chain. Never mutate history,
  never delete a predecessor. Glyph `<` vs `>` derives from the
  successor's `occurs_on`.
- **Task state is exactly** `open|done|struck|migrated`; events and
  notes carry exactly NULL (not `""` — sync compares values).
  Lifecycle changes go through the bang methods, which raise
  `Entry::LifecycleError` on invalid transitions.
- **Soft delete only** (`SoftDeletable`, `kept` scope, no
  default_scope): rows and ids must survive for sync. Nothing
  cascades.
- **`hlc` and `server_seq` are dormant until phase 2** — no code
  writes them before the sync slice.

## Dates and purity

- `lib/bujo/` is pure Ruby over stdlib `date` — no Rails, no clock,
  no ENV, Ruby-3.3-parseable. The boundary test enforces it by
  loading the parser in a bare subprocess; don't fight it.
- Models never call `Date.today`/`Date.current`; queries and
  operations take dates from the caller. Controllers are the one
  layer that may read the clock.

## The shared grammar

`Bujo::RapidLog` is the one parser for every client (web now, TUI in
phase 3). Grammar changes are spec-level decisions (see
`docs/slices/1.1-rapid-log-parser.md` — its tables are the contract),
carry the strictest bars (mutation 100%), and must keep
`parse`/`render` round-tripping. `Entry.capture!` is the only bridge
from lines to rows.
