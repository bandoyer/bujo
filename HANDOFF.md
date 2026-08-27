# Handoff — Tailwind v4 approved; bounded squad implementation next (2026-08-27)

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
produced correction slice 1.5.3b. Its terminal candidate `dc2153c` is now
integrated on `main`; its contract is
`docs/slices/1.5.3b-dogfood-entry-corrections.md`, with the approved review
board at `mockups/PhoneDogfoodCorrections.dc.html`. Nothing from 1.5.3a or
1.5.3b has been deployed by this handoff.

The current planning baseline is
`434a9a9478a5581494773c5660583e4d8f3cfa4e` on both `main` and
`origin/main`. The approved Tailwind v4 infrastructure track now has a complete
T0 receipt at `docs/tailwind-v4-baseline/README.md` and a source-aligned
contract at `docs/slices/tailwind-v4-presentation-migration.md`. This planning
baseline contains no Tailwind dependency/application change. Dan's 2026-08-27
approval authorizes the bounded squad launch, not root integration or deploy.

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
- Daily's empty message and trailing canvas open the same capture form.
  Ordinary Monthly Calendar and Tasks capture offers Task, Event, and Note.
- Existing live entries can be corrected in place only where the approved page
  and kind matrix allows it. Correction never changes residency, ancestry,
  history, task state, dates, tags, ownership, or sync-sensitive fields.
- Schedule uses a full-width native date field. A date later in the current
  month appends a Calendar successor; a later-month date appends a Future
  successor. Refused requests return to the canonical resident page unchanged.
- Entry rows retain their shared grid as text wraps. Completing a task changes
  only its glyph to `X`; struck text keeps full ink with a thicker current-color
  line.
- Each Monthly Migration resolution offers one immediate Undo. Undo is a
  tenant-scoped compensating append for movement, never history mutation, and
  refuses stale or crafted requests without disturbing the live chain.
- A newly created Collection remains deliberately unindexed and shows the next
  deliberate registration step. Entry deletion remains deferred.
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
- Slice 1.5.3b candidate receipts: 230 fast tests / 3822 assertions; 81 system
  tests / 1640 assertions; RuboCop clean; all 234 measured methods at CRAP ≤ 6;
  jscpd zero clones; `Bujo::RapidLog*` mutation 1105/1105. Root repeated the
  fast and system lanes plus RuboCop after integration.
- Architect review recorded one non-blocking dogfood seam: a populated
  outgoing month currently derives trees with per-node child/successor queries.
  Preserve ruled ordering; optimize only if real journals make it hot.

## Next work — bounded Tailwind implementation

Dan approved `docs/slices/tailwind-v4-presentation-migration.md` together with
the T0 receipt on 2026-08-27. It is a presentation-only migration with exact-pinned
`tailwindcss-rails` 4.6.0 and `tailwindcss-ruby` 4.3.3, no Node, no Preflight,
no Tailwind default theme, one compiled asset, a byte-for-behavior legacy
checkpoint, and component/page checkpoints. Current Index, Collection,
Monthly Migration, date-control, preference, notice, and Calendar behavior is
frozen; the open phone corrections remain a separate product amendment.

No mock change is needed for migration review. The current rendered app is the
visual authority, represented by 135 prepared reference screenshots, 102
targeted geometry samples, and the selector manifest. Commit/push this planning
baseline, then run the configured bounded squad on `codex/tailwind-v4`.
Terminal QA does not authorize root integration, push from that branch to
`main`, or deployment; return the accumulated candidate to Dan first.

The current checkout was verified with one relocated main worktree, a clean
tracked baseline before the planning artifacts, and no Bujo SwarmForge daemon.
Do not touch the unrelated Press Start `handoffd` process.

## Product work after the infrastructure decision

Run the merged app locally and repeat the reported phone flows in both themes:
Daily empty capture; Monthly Task/Event/Note capture and correction; native-date
scheduling to Calendar and Future; wrapped-row alignment and lifecycle ink;
every Monthly Migration Undo outcome; and Collection creation guidance. Record
any dogfood corrections before starting another implementation slice.

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
`docs/resend-transactional-email.md`. Phone review is the immediate gate; do
not start Daily Reflection or authentication in parallel without Dan's choice.

## Build and review

Keep the proven loop: source-aligned spec and smallest review mock → Dan's
explicit approval → `six-mix-fable-review` swarm → operator review → Dan's
explicit integration approval → merge and push. Do not deploy for Dan.

For 1.5.3b the compatibility-named pack used this experimental roster:
Sol Max specifier, Sol High coder, Grok High cleaner, Sol High architect, Grok
High hardener, and Sol XHigh QA. Passing QA is terminal only for implementation;
it does not authorize root integration or push.

Herdr roles have no Codex Desktop in-app Browser backend. QA must not attempt
or disclaim that surface; `bin/rails test:system` is the authoritative
headless-Chrome acceptance lane, supplemented by screenshots,
DOM/geometry/accessibility checks, and direct request/domain probes.

The 1.5.3b terminal candidate `dc2153c` is integrated. Its completed six-role
swarm, role worktrees, and daemons are retired. Do not start another swarm
before its source-aligned specification and any necessary review mock are
approved.

The Tailwind track uses a dynamic squad, not the old six persistent worktrees:
at most two transient workers; Sol Max leader/specifier; Sol High coder and
architect; Grok 4.6 High cleaner/hardener; Sol XHigh terminal QA. The exact
policy is in `swarmforge/squad.conf`. Deterministic profile support is now on
canonical SwarmForge `main` at `b5b17bd` and passed its complete 375-check
smoke suite. Dan's 2026-08-27 approval resolves the specification gate and
authorizes `swarm squad up`; it does not broaden the contract or later gates.

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
