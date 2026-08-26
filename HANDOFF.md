# Handoff — slice 1.5.2 landed; 1.5.3 approved to build (2026-08-26)

For the next operator session — any agent or human. `PLAN.md` is the living
status document; this file records the landed boundary and the next approved
process boundary.

## Governing product rule

Dan's ruling remains: v1 follows Ryder Carroll's *The Bullet Journal Method*,
Parts II–III, as closely as possible. Start minimal and true to the book; add
digital smartness only where dogfooding proves pain. For a design question,
authority is `docs/METHOD.md` → `PLAN.md` → `ARCHITECTURE.md` → the relevant
`docs/slices/*.md` spec. If those leave a source question unresolved, return to
`~/Downloads/The Bullet Journal Method_ Trac - Carroll_ Ryder.pdf`, especially
Parts II–III, before inventing behavior.

## Relocation and branch boundary

The checkout lives at `/home/dlb/Work/bujo`, including the imported `mockups/`
design source, ignored `storage/` data, the `.agents/` skill mirror, and
preserved `.swarmforge/` audit logs.
Never seed work from the historical `recovered/1.5.1-accepted-spec` branch;
it remains a recovery artifact only.

Slice 1.5.2's approved terminal candidate is `1ae8136`. It is integrated on
`main`; no implementation is deployed by this handoff. The completed review
swarm must be retired before another pack is selected. The next review pack is
Dan's explicit choice: `six-mix-fable-review`.

## Exact landed state

- Custom Collections are writable pages for task, event, and note roots.
  Creation, rename, Index registration/unindexing, and guarded never-used
  deletion are explicit lifecycle gestures scoped to `Current.user`.
- The Index is a reference query over kept, explicitly registered Custom
  Collections ordered by server-allocated `index_position`. It does not own
  entries, list logs, discover unindexed pages, or become broad search.
- A known unindexed Collection remains reachable by stable UUID URL or exact
  case-insensitive Topic equality. Missing, deleted, and foreign-only Topics
  refuse uniformly.
- Collection tasks admit Complete/Strike/Reopen. Collection events and notes
  remain commandless. Collection residents admit no outbound movement.
- Eligible Daily and Monthly task/event/note roots can move deliberately to a
  known exact-Topic Collection. Movement remains append-only through
  `Entry#move_to!`; placement is never updated in place and destinations never
  register themselves.
- Operator review caught an unbounded Topic that widened 320 px source pages
  and duplicate `id="topic"` move fields that left later inputs without an
  accessible label. Both are pinned by regressions in the landed candidate.
- Final receipts: `bin/rails test` 188 runs / 3057 assertions;
  `bin/rails test:system` 50 / 1133; RuboCop clean; all 159 measured methods at
  CRAP ≤ 6; jscpd zero clones; `Bujo::RapidLog*` mutation 1105/1105. The
  `index_position` migration passed forward and fresh-database checks.
  `lib/`, `Gemfile`, and the dormant `hlc`/`server_seq` behavior are untouched.

## Next work — build slice 1.5.3

The next slice is **Monthly migration ritual**. Its approved specification is at
`docs/slices/1.5.3-monthly-migration-ritual.md`, with the smallest review delta
at `mockups/MonthlyMigration.dc.html`. The operator approved the mock and all
five digital translations on 2026-08-26; implementation may begin.

Start from `docs/METHOD.md`, then inspect the book's Monthly Migration,
Monthly Log, Future Log, and reflection passages if the project documents leave
a source question unresolved. Inspect current residency scopes, entry trees,
`Entry#move_to!`, the command authorization policy, Monthly/Future readers and
controllers, and all return-destination rules before specifying UI.

The method boundary already recorded in `PLAN.md` is:

- set up a new Monthly Log and a fresh mental inventory;
- review every unresolved task on the outgoing month's Daily and Monthly pages
  one at a time and with its tree context;
- strike what is irrelevant or rewrite what remains worthy to the new Monthly
  Tasks page, a deliberate Custom Collection, or the Future Log;
- scan due Future tasks into the new Tasks page and due events into the new
  Calendar page;
- never bulk-roll, silently carry, auto-discover, or sweep Custom Collection
  tasks merely because a month changed.

The specification must settle the exact review set and order, tree-context
behavior, setup timing/idempotence, every admitted/refused destination by
resident kind and state, Future scan-in, interruption/resume behavior, return
destinations, tenant-safe stale/deleted cases, and the smallest usable phone
flow in both themes. Preserve UUIDv7, immutable residency, append-only
successors, soft deletion without cascades, same-user validation, exact NULL
state for events/notes, and dormant sync fields.

## Build and review

Keep the proven loop: source-aligned spec and smallest review mock → Dan's
explicit approval → `six-mix-fable-review` swarm → operator review → Dan's
explicit integration approval → merge and push. Do not deploy for Dan.

Herdr roles have no Codex Desktop in-app Browser backend. QA must not attempt
or disclaim that surface; `bin/rails test:system` is the authoritative
headless-Chrome acceptance lane, supplemented by screenshots,
DOM/geometry/accessibility checks, and direct request/domain probes.

After the completed 1.5.2 swarm is retired, select the requested pack and start
the approved 1.5.3 review. The required pack is `six-mix-fable-review`.

Later method-spine slices remain, in order: Daily Reflection (1.5.4), then
`!` inspiration and master-task completion gating (1.5.5). Settings polish,
broad search, grammar expansion, and PWA work remain deferred.

## Deployment boundary

Production at https://bujo.questlog.dev still runs through 1.4.1. Dan runs
deployments himself; hand him `kamal deploy` and do not execute it for him.

After deployment, inspect the few rows created by 1.4.1's Future month-add.
The irreversible migration deliberately backfills them as Daily residents
because it cannot guess intent. With Dan's explicit go-ahead, repair only
confirmed Future rows to `page_kind: "future"` and `page_on: nil`, preserving
`occurs_on`; never bulk-guess.
