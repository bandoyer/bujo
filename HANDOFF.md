# Handoff — slice 1.5.3b approved; implementation starting (2026-08-26)

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
`main`. Slice 1.5.3a's terminal candidate is `92c43e2`; it is also integrated
on `main`, and its completed six-role swarm is retired. Phone dogfooding then
produced approved correction slice 1.5.3b. Its contract is
`docs/slices/1.5.3b-dogfood-entry-corrections.md`, with the approved review
board at `mockups/PhoneDogfoodCorrections.dc.html`. Nothing from 1.5.3a or
1.5.3b has been deployed by this handoff.

## Exact landed state

- Daily no longer repeats its date under the page title. Its centered date
  remains between day-navigation chevrons, and the trailing page canvas opens
  the same rapid-log form as the visible entries.
- Monthly Calendar dates and blank row space open capture for that exact day;
  the separate labelled 44px chevron opens the Daily Log. Monthly Tasks uses
  the same trailing-canvas capture behavior as Daily.
- Future uses the shared Task/Event glyph controls and rapid-log anatomy,
  aligns resident glyph/day/content/time fields, and lets either a month
  heading or the trailing month canvas open the same form with truthful focus
  return.
- Index keeps its explicit New Collection control and also opens that same
  create form from the trailing canvas. Reveal remains ephemeral and creates
  nothing by itself.
- Empty outgoing and Future migration stages are truthful checkpoints. The
  operator explicitly chooses Scan the Future Log and Finish Monthly Migration;
  completion remains derived from live entry state rather than a new flag.
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
- Slice 1.5.3a candidate receipts: 201 fast tests / 3412 assertions; 61 system
  tests / 1383 assertions; RuboCop clean; all 195 measured methods at CRAP ≤ 6;
  jscpd zero clones; `Bujo::RapidLog*` mutation 1105/1105. Root repeated the
  fast and system lanes plus RuboCop after integration. The first parallel
  system run had two transient sign-in setup failures; both exact cases passed
  together in isolation and the complete rerun passed.
- Architect review recorded one non-blocking dogfood seam: a populated
  outgoing month currently derives trees with per-node child/successor queries.
  Preserve ruled ordering; optimize only if real journals make it hot.

## Next work — implement and review approved slice 1.5.3b

Run the approved 1.5.3b contract through the unchanged
`six-mix-fable-review` roster. The slice is deliberately bounded to the
dogfood corrections in its specification: do not add Entry deletion, broaden
search, change parser grammar, begin active sync, or absorb Daily Reflection.
The approved mock is review authority for the new visible states. Terminal QA
still requires Dan's hands-on review and explicit integration approval before
root merges or pushes implementation.

After 1.5.3b is landed and dogfooded, the next method-spine slice is **1.5.4
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

The separate authentication track is also unblocked: Step 1 is Resend delivery
plus short-lived, single-use magic links, governed by
`docs/resend-transactional-email.md`. Slice 1.5.3b is the immediate approved
track; do not start Daily Reflection or authentication in parallel without
Dan's choice.

## Build and review

Keep the proven loop: source-aligned spec and smallest review mock → Dan's
explicit approval → `six-mix-fable-review` swarm → operator review → Dan's
explicit integration approval → merge and push. Do not deploy for Dan.

For 1.5.3b the compatibility-named pack continues this experimental roster:
Sol Max specifier, Sol High coder, Grok High cleaner, Sol High architect, Grok
High hardener, and Sol XHigh QA. Passing QA is terminal only for implementation;
it does not authorize root integration or push.

Herdr roles have no Codex Desktop in-app Browser backend. QA must not attempt
or disclaim that surface; `bin/rails test:system` is the authoritative
headless-Chrome acceptance lane, supplemented by screenshots,
DOM/geometry/accessibility checks, and direct request/domain probes.

The 1.5.3a terminal candidate `92c43e2` is integrated and its prior swarm,
role worktrees, and both daemons were retired before 1.5.3b planning. Slice
1.5.3b's source-aligned specification and required review mock are approved;
its new isolated swarm is now authorized to start from the pushed planning
baseline.

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
