# Handoff — slice 1.5.1 landed; 1.5.2 is next (2026-08-25)

For the next operator session — any agent or human. `PLAN.md` is the
living status document; this file records the operational boundary and
the next concrete work.

## Governing product rule

Dan's ruling remains: v1 follows Ryder Carroll's *The Bullet Journal
Method*, Parts II–III, as closely as possible. Start minimal and true to
the book; add digital smartness only where dogfooding proves pain. For a
design question, authority is `docs/METHOD.md` → `PLAN.md` →
`ARCHITECTURE.md` → the relevant `docs/slices/*.md` spec.

## Exact repository state

- Slice 1.5.1 and follow-up 1.5.1a are integrated on `main`. The final
  swarm candidate is `66566ae` (`Strengthen page-model verification`);
  the post-merge commit only refreshes project status, the tracked
  `bujo-conventions` skill, and its active local mirror.
- The schema now records exactly one immutable root residency with
  `page_kind`, `page_on`, and `collection_id`. Log scopes read that
  placement; `occurs_on` describes content and never grants membership.
  Movement is append-only through `Entry#move_to!`, and its glyph comes
  from the successor page.
- QA pass 1 found that crafted Complete/Strike/Reopen requests could
  mutate read-only Future and Collection residents. Follow-up 1.5.1a
  routes every member command through one persisted-residency guard.
  Pass 2 verified all five commands against both read-only page kinds
  and retained every action on Daily and Monthly residents.
- Final receipts: `bin/rails test` 133 runs / 1120 assertions;
  `bin/rails test:system` 33 / 378; RuboCop clean; all 126 measured
  methods at CRAP ≤ 6; jscpd zero clones; `Bujo::RapidLog*` mutation
  1105/1105. The migration was verified both forward from the prior
  schema and from a fresh database. `lib/` and `Gemfile` are untouched.
- The swarm reached its terminal QA broadcast and every queue completed
  without failure. The reboot stopped its router/watcher; no restart is
  needed for this slice.

## Deployment boundary

Production at https://bujo.questlog.dev still runs through 1.4.1. Dan
runs deployments himself; hand him `kamal deploy` and do not execute it
for him.

After deployment, inspect the few rows created by 1.4.1's Future
month-add. The irreversible migration deliberately backfills them as
Daily residents because it cannot guess intent. With Dan's explicit
go-ahead, repair only confirmed Future rows to `page_kind: "future"`
and `page_on: nil`, preserving `occurs_on`; never bulk-guess.

## Next slice

Spec 1.5.2, **Custom Collections + deliberate Index**, before starting
another swarm. It is a minimal writable Custom Collection page plus
explicit manual Index registration. Core logs remain fixed navigation,
Daily Logs are never indexed, and broad text search stays deferred.
Follow the project loop: source-aligned spec and any needed mock → Dan's
approval → swarm → operator review → merge.

Later method-spine slices remain, in order: monthly migration ritual
(1.5.3), Daily Reflection (1.5.4), then `!` inspiration and master-task
completion gating (1.5.5). Settings polish, broad search, grammar
expansion, and PWA work remain deferred as recorded in `PLAN.md`.

## Infra quick facts

Droplet `bujo` is in DigitalOcean nyc3 at 174.138.85.202. Kamal pulls
from GHCR; Litestream replicates to R2 bucket `bujo-litestream`.
`bujo.questlog.dev` is live, `doctl` is authenticated, and production
diagnostics use `kamal logs` / `kamal console`.
