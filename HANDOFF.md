# Handoff — slice 1.5.2 approved; implementation is next (2026-08-25)

For the next operator session — any agent or human. `PLAN.md` is the living
status document; this file records the relocation boundary and the approved
implementation boundary.

## Governing product rule

Dan's ruling remains: v1 follows Ryder Carroll's *The Bullet Journal Method*,
Parts II–III, as closely as possible. Start minimal and true to the book; add
digital smartness only where dogfooding proves pain. For a design question,
authority is `docs/METHOD.md` → `PLAN.md` → `ARCHITECTURE.md` → the relevant
`docs/slices/*.md` spec. If those leave a source question unresolved, return to
`~/Downloads/The Bullet Journal Method_ Trac - Carroll_ Ryder.pdf`, especially
Parts II–III, before inventing behavior.

## Relocation completed

The whole checkout now lives at `/home/dlb/Work/bujo`, including ignored
`storage/` data, the `.agents/` Codex skill mirror, and preserved
`.swarmforge/` audit logs. `main` and `origin/main` were fetched and verified at
`faed999`; `git worktree list` contains only the relocated main checkout, and
`swarm status` reports both daemons stopped. The historical branch
`recovered/1.5.1-accepted-spec` at `6da3ba2` remains a recovery artifact, not an
active candidate.

`script/watch-swarm.sh` now derives the repository root from its own location.
The desktop XDG project location and saved Herdr pane paths point to
`/home/dlb/Work`; `/home/dlb/Projects` is only a compatibility symlink to that
directory.

Before the next swarm, open a fresh Herdr workspace from this relocated root;
do not reuse a pane restored from before the move. Never seed new work from the
historical recovery branch: `main` contains the landed and superseding 1.5.1
history.

## Exact landed state

- Slice 1.5.1 and follow-up 1.5.1a are integrated on `main`. The final swarm
  candidate is `66566ae` (`Strengthen page-model verification`); `274f566`
  records the landed status, and `faed999` records the Work relocation.
- Slice 1.5.2's source-aligned specification and smallest mobile review mock
  are operator-approved. The accepted-spec baseline reconciles the new
  sync-sensitive `collections.index_position` field in `ARCHITECTURE.md`.
  Implementation has not yet been integrated or deployed.
- The schema records exactly one immutable root residency with `page_kind`,
  `page_on`, and `collection_id`. Log scopes read that placement;
  `occurs_on` describes content and never grants membership. Movement is
  append-only through `Entry#move_to!`, and its glyph comes from the successor
  page.
- QA pass 1 found crafted Complete/Strike/Reopen requests could mutate
  read-only Future and Collection residents. Follow-up 1.5.1a routes every
  member command through one persisted-residency guard. This read-only
  Collection behavior is deliberate for 1.5.1 but must be explicitly
  superseded, not casually bypassed, by the writable Collection spec.
- Final receipts: `bin/rails test` 133 runs / 1120 assertions;
  `bin/rails test:system` 33 / 378; RuboCop clean; all 126 measured methods at
  CRAP ≤ 6; jscpd zero clones; `Bujo::RapidLog*` mutation 1105/1105. The
  migration was verified both forward from the prior schema and from a fresh
  database. `lib/` and `Gemfile` are untouched.

## Next work — implement the approved 1.5.2 slice

Implement `docs/slices/1.5.2-custom-collections-and-index.md` for **Custom
Collections + deliberate Index**. The specification and mobile review ruling
are approved; do not reopen them inside the swarm.

The already-settled product boundary is:

- A Custom Collection is a writable residency page accepting task, event, and
  note roots. It is not another log container or a duplicate membership.
- The Index is an explicitly maintained reference lens over Custom Collection
  pages. It never creates entry residency, never indexes Daily Logs, and does
  not replace the fixed Today/Month/Future navigation.
- Broad text search and automatic discovery are deferred. Nothing rolls over,
  moves, registers itself, or becomes indexed without a deliberate gesture.
- Collection capture must continue through `Entry.capture!` with
  `page_kind: "collection"`, `page_on: nil`, and a same-user Collection.
  Movement remains append-only through `move_to!`; placement is never updated
  in place.
- UUIDv7 ids, soft deletion without cascades, tenant scoping, shared grammar,
  and dormant `hlc`/`server_seq` remain binding.

The accepted spec rules these points; implementation and review must prove
each one:

1. How manual Index registration is persisted and ordered. The current
   `collections` schema has only identity, name, sync placeholders, and soft
   deletion; any new field is sync-sensitive and must be reconciled with
   `ARCHITECTURE.md`.
2. The minimum Collection lifecycle: creation, naming/renaming, explicit
   index/unindex gestures, and whether deletion is in scope. Never cascade or
   strand resident words behind a deleted page.
3. How an unindexed Collection remains intentionally reachable without
   turning the Index into an automatic list or smuggling in broad search.
4. The Collection entry-command matrix. In 1.5.1, all five member commands are
   refused. At minimum, writable Collection tasks need a consciously ruled
   lifecycle. Do **not** merely add `collection` to `ACTION_PAGE_KINDS`:
   `migrate` currently calls `@entry.page_on.next_month`, but Collection
   residents have NULL `page_on`. Define which controls render, which crafted
   requests refuse, and where every successful/refused command returns.
5. Whether this slice includes an inbound “move to Collection” gesture for
   Daily/Monthly residents or leaves that gesture to 1.5.3's monthly ritual.
   State the choice; notes' natural non-daily destination is a Collection.
6. The smallest phone UI that makes the Index and one writable Collection
   legible in both themes, including creation/registration affordances, touch
   targets, empty states, and tenant-safe missing/deleted routes.

Inspect the existing seams before implementing the spec: `Collection`,
`Entry.capture!`/`move_to!`, `EntriesController::WRITABLE_PAGE_KINDS` and
`ACTION_PAGE_KINDS`, `JournalReading`, the disabled Index item in
`app/views/shared/_tab_bar.html.erb`, and the 1.5.1a amendment at the end of
`docs/slices/1.5.1-the-page-model.md`.

## Build and review

Keep the proven loop: approved spec/mock → `six-all-models-review` swarm →
operator review → Dan's explicit integration approval → merge and push. Read
the project testing skill before changing tests. Preserve the existing fast,
system, RuboCop, CRAP, jscpd, tenancy, and hand-mutation bars; if `lib/` stays
out of scope, RapidLog mutation remains exactly 1105/1105. Any schema change
must be proven both forward and from a fresh database.

After an approved terminal candidate is integrated, use the new guarded
`swarm retire` command so linked worktrees and merged role branches are cleaned
as part of the workflow while logs and provider histories remain.

Later method-spine slices remain, in order: monthly migration ritual (1.5.3),
Daily Reflection (1.5.4), then `!` inspiration and master-task completion
gating (1.5.5). Settings polish, broad search, grammar expansion, and PWA work
remain deferred as recorded in `PLAN.md`.

## Deployment boundary

Production at https://bujo.questlog.dev still runs through 1.4.1. Dan runs
deployments himself; hand him `kamal deploy` and do not execute it for him.

After deployment, inspect the few rows created by 1.4.1's Future month-add.
The irreversible migration deliberately backfills them as Daily residents
because it cannot guess intent. With Dan's explicit go-ahead, repair only
confirmed Future rows to `page_kind: "future"` and `page_on: nil`, preserving
`occurs_on`; never bulk-guess.

Infra quick facts: droplet `bujo`, DigitalOcean nyc3, `174.138.85.202`; Kamal
pulls from GHCR; Litestream replicates to R2 bucket `bujo-litestream`.
Production diagnostics use `kamal logs` / `kamal console`.
