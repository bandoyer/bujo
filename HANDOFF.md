# Handoff — slice 1.5.3a approved; prepare its swarm baseline (2026-08-26)

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

Slice 1.5.3's approved terminal candidate is `329b8f6` and is integrated on
`main`. Its completed swarm is retired. Slice 1.5.3a is approved at
`docs/slices/1.5.3a-phone-capture-and-ritual-clarity.md`, with the approved
review board at `mockups/PhoneCaptureCorrection.dc.html`; its implementation
has not started and no implementation is deployed by this handoff.

## Exact landed state

- Monthly Migration is an explicitly opened target-month ritual. It never
  starts on page view or month rollover and never silently carries work.
- Setup gives the ritual alone a task-only admission context for target Monthly
  Tasks; ordinary future-month Monthly capture remains closed.
- Outgoing review is derived live in Calendar → Monthly Tasks → Daily order.
  Each unresolved task receives one turn inside its complete kept root tree.
- A task may be struck, rewritten to target Tasks, moved to a known exact-Topic
  Collection, or scheduled beyond the target month. Future scanning is limited
  to exact-target-month roots: tasks move to Tasks or strike; events move to
  Calendar with date and time preserved.
- Resume, stage, and completion are derived from kept state and successor
  links. No ritual table, completion flag, schema change, background behavior,
  or generic Future controls were added.
- Every movement remains append-only and tenant-scoped with UUIDv7, immutable
  residency, soft deletion without cascades, exact NULL event/note state, and
  dormant `hlc`/`server_seq` behavior preserved. `lib/`, `Gemfile`, and parser
  grammar are untouched.
- Final receipts: `bin/rails test` 200 runs / 3360 assertions;
  `bin/rails test:system` 56 / 1220; RuboCop clean; all 194 measured methods at
  CRAP ≤ 6; jscpd zero clones; `Bujo::RapidLog*` mutation 1105/1105.
- Architect review recorded one non-blocking dogfood seam: a populated
  outgoing month currently derives trees with per-node child/successor queries.
  Preserve ruled ordering; optimize only if real journals make it hot.

## Next work — implement the approved 1.5.3a amendment

Phone dogfooding produced one deliberately small correction before Daily
Reflection:

- remove the duplicate date beneath `Daily Log` while retaining the centered
  date between the day-navigation chevrons;
- make the real trailing canvas open capture on Daily, Monthly Tasks, Future,
  and Index, without making reveal itself persist anything;
- make Calendar day/blank-row taps open that exact Calendar capture while a
  separate 44px chevron opens the Daily Log;
- reuse the shared Task/Event glyph controls in Future, restore their visible
  selected state and focus behavior, and align each resident on one baseline;
- render truthful outgoing-empty and Future-empty Monthly Migration checkpoints
  and require explicit Scan and Finish gestures before completion.

This is presentation and orchestration only. Preserve every residency,
capture-admission, return-destination, same-user, UUIDv7, append-only movement,
soft-deletion, and dormant sync-field invariant. Do not change models, schema,
routes, parser grammar, `lib/`, or dependencies. The required system tests use
real phone coordinates and rendered geometry in the existing Rails
headless-Chrome lane; selector clicks on invisible controls do not prove the
reported gestures.

After 1.5.3a lands and is dogfooded, the next method-spine slice is **1.5.4
Daily Reflection**. Its current plan boundary remains a small AM/PM reference
lens:

- morning reflection brings the current month's open tasks into view;
- evening reflection walks today's entries deliberately through appropriate
  completion, strike, and scheduling gestures;
- reflection references resident entries and never becomes another page,
  duplicate residency, background sweep, notification system, or automatic
  movement.

When 1.5.4 is specified, start with `docs/METHOD.md`; return to the book's
Morning Reflection, Evening Reflection, Daily Log, and Migration passages only
where project authority leaves a source question unresolved. Surface genuinely
digital decisions to Dan rather than guessing.

## Build and review

Keep the proven loop: source-aligned spec and smallest review mock → Dan's
explicit approval → `six-mix-fable-review` swarm → operator review → Dan's
explicit integration approval → merge and push. Do not deploy for Dan.

For 1.5.3a the compatibility-named pack is the approved experimental roster:
Sol Max specifier, Sol High coder, Grok High cleaner, Sol High architect, Grok
High hardener, and Sol XHigh QA. Passing QA is terminal only for implementation;
it does not authorize root integration or push.

Herdr roles have no Codex Desktop in-app Browser backend. QA must not attempt
or disclaim that surface; `bin/rails test:system` is the authoritative
headless-Chrome acceptance lane, supplemented by screenshots,
DOM/geometry/accessibility checks, and direct request/domain probes.

The 1.5.3a spec and mock are approved. Before `swarm up`, they and the roster
must be committed on the baseline branch so isolated worktrees can read them.

After Daily Reflection, the remaining method-spine slice is `!` inspiration
and master-task completion gating (1.5.5). Settings polish, broad search,
grammar expansion, and PWA work remain deferred.

## Deployment boundary

Production at https://bujo.questlog.dev still runs through 1.4.1. Dan runs
deployments himself; hand him `kamal deploy` and do not execute it for him.

After deployment, inspect the few rows created by 1.4.1's Future month-add.
The irreversible migration deliberately backfills them as Daily residents
because it cannot guess intent. With Dan's explicit go-ahead, repair only
confirmed Future rows to `page_kind: "future"` and `page_on: nil`, preserving
`occurs_on`; never bulk-guess.
