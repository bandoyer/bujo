# Handoff: Daily Reflection landed; Index source correction at review gate (2026-08-28)

For the next operator session, any agent or human. `PLAN.md` is the living
status document; this file records the landed boundary and the next product
gate.

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
board at `mockups/PhoneDogfoodCorrections.dc.html`. Daily Reflection terminal
candidate `c2127b5` is also integrated and pushed on `main` after Dan's explicit
2026-08-28 approval. Nothing from 1.5.3a onward has been deployed by this
handoff.

Tailwind terminal candidate `8d7ccbde93f02f9a7afcc643d7547a43490792fa`
is integrated on `main` with Dan's 2026-08-27 approval. Its complete T0 receipt
remains at `docs/tailwind-v4-baseline/README.md` and its landed contract at
`docs/slices/tailwind-v4-presentation-migration.md`. Deployment is not
authorized; Dan runs deployments himself. Real-device dogfooding then found a
bounded Calendar resident-baseline defect. Dan accepted its correction, and
Daily Reflection subsequently landed.

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
- The currently landed Collection implementation still creates an unindexed
  page and exposes registration. Dan rejected that digital translation after a
  2026-08-28 source check; proposed 1.5.2a corrects it before further feature
  work. Entry deletion remains deferred.
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
- Daily Reflection is a current-day reference lens, not a residency page.
  Morning embeds shared Daily capture then reviews current-month Calendar,
  Tasks, and Daily trees through Mark/Clear priority only. Evening embeds the
  same capture and reviews today's complete Daily trees through the ruled
  Complete/Strike/Schedule matrix with derived progress copy.
- Daily Reflection stores no ritual progress, focus state, copied entries,
  schema, JavaScript, notification, background sweep, or automatic movement.
  All entry changes retain the landed same-user, append-only, and immutable
  residency boundaries.
- Daily Reflection terminal candidate `c2127b5` passed three QA correction
  rounds. Root repeated the exact final tree at 286 fast tests / 6907
  assertions, 112 headless-Chrome system tests / 16797 assertions, and 114
  RuboCop-clean files before integration.
- Architect review recorded one non-blocking dogfood seam: a populated
  outgoing month currently derives trees with per-node child/successor queries.
  Preserve ruled ordering; optimize only if real journals make it hot.

## Tailwind landing

The landed presentation-only migration exact-pins `tailwindcss-rails` 4.6.0 and
`tailwindcss-ruby` 4.3.3, uses no Node, Preflight, or Tailwind default theme,
and serves one fingerprinted application bundle. It preserves the accepted
Index, Collection, Monthly Migration, date-control, preference, notice,
Calendar, and phone behavior across all 135 reference screenshots and 102
targeted geometry samples.

Corrected terminal QA pass 2 is the accepted terminal receipt. It supersedes
pass 1's overconstrained interpretation of raw CSS inside the runtime image.
Only the public/served asset boundary is binding: one fingerprinted Tailwind
bundle is public, manifested, and rendered; no stale, legacy, T0, or second
application stylesheet is served. The Dockerfile needed no correction.

The bounded squad is down, every transient worker is retired, and only the main
worktree remains. Daily Reflection's completed `mix-*` role worktrees are also
retired. The repository's persistent pack configuration is now the stopped
`six-cg` pack; `swarmforge/squad.conf` remains as the historical Tailwind squad
policy. Do not touch unrelated SwarmForge processes from other repositories.

## Accepted post-Tailwind phone correction

The reported Calendar row defect was real: resident glyph, first-line text,
and metadata sat 13.5 CSS px above the date/weekday baseline at 390 px. The
accepted Calendar-only correction centers Entry's first internal line beside
the date while allowing wrapped ink to grow downward. Its executable contract
holds the date number, weekday, glyph, first text line, and metadata within 4
CSS px at the 390 px light/Rock Salt and 320 px dark/Architects Daughter phone
profiles. Horizontal geometry, capture, navigation, residency, and entry
behavior are unchanged.

Dan accepted the corrected phone result on 2026-08-27 and elected to keep
moving, leaving smaller visual polish for later. Root verification is green at
265 fast tests / 6434 assertions, 95 headless-Chrome system tests / 15234
assertions, and RuboCop clean. The correction is documented as a post-T0
product amendment in `docs/slices/1.5.3b-dogfood-entry-corrections.md`; frozen
Tailwind T0 artifacts remain unchanged.

## Next work: 1.5.2a Index source correction

Phone dogfooding exposed a conceptual problem rather than a missing hint: a
new Custom Collection could exist outside the Index, so returning through the
fixed Index tab made a successful creation appear lost. The source check found
that Ryder describes the Index as the container/retrieval map for Collections
except Daily and does not define a deliberately hidden active Custom
Collection. Dan ruled on 2026-08-28 that the web app must create and register a
Custom Collection in one commitment; normal unindex/re-register and Open by
Topic go away.

The proposed bounded contract is
`docs/slices/1.5.2a-index-is-the-collection-register.md`; the smallest review
board is `mockups/IndexSourceCorrection.dc.html`. It proposes four necessary
digital translations for explicit approval:

- web Create atomically persists the named UUIDv7 page and its next
  server-owned Index position, even before first capture;
- a one-way migration registers existing kept NULL-position Collections in
  deterministic per-user `created_at, id` order after every retained rank;
- append order becomes permanent—rename, capture, movement, and soft deletion
  preserve it, with no reorder or unindex workaround; and
- the nullable column remains for tombstones/wire compatibility while a check
  constraint forbids NULL on a kept Collection.

No broad search, filtering, picker, new entity, Entry behavior, delete scope,
active sync, or deployment belongs in the correction. The configured
`six-cg` swarm is stopped. Do not commit/push this planning delta or start it
until Dan approves the complete amendment and review board.

The separate authentication track is unblocked but remains unstarted and does
not run in parallel. After 1.5.2a, the remaining method-spine slice is 1.5.5.

## Build and review

Keep the proven loop: source-aligned spec and smallest review mock → Dan's
explicit approval → `six-cg` swarm → operator review → Dan's
explicit integration approval → merge and push. Do not deploy for Dan.

The current `six-cg` roster is Sol Max specifier, Sol High coder, Grok 4.6
High cleaner, Grok 4.6 xhigh architect, Grok 4.6 High hardener, and Sol xhigh
QA. All roles use isolated `cg-*` worktrees. Passing QA is terminal only for
implementation; it does not authorize root integration or push.

Herdr roles have no Codex Desktop in-app Browser backend. QA must not attempt
or disclaim that surface; `bin/rails test:system` is the authoritative
headless-Chrome acceptance lane, supplemented by screenshots,
DOM/geometry/accessibility checks, and direct request/domain probes.

Daily Reflection terminal candidate `c2127b5` is integrated and pushed. Its
completed six-role swarm, role worktrees, and daemons are retired. Do not start
another swarm before its source-aligned specification and any necessary review
mock are approved.

The completed Tailwind track used a dynamic squad, not the old six persistent worktrees:
at most two transient workers; Sol Max leader/specifier; Sol High coder and
architect; Grok 4.6 High cleaner/hardener; Sol XHigh terminal QA. The exact
policy is preserved in `swarmforge/squad.conf`. Deterministic profile support is on
canonical SwarmForge `main` at `b5b17bd` and passed its complete 375-check
smoke suite. Dan's 2026-08-27 approval landed terminal candidate `8d7ccbd`; the
squad is down and every transient worker is retired.

After the bounded 1.5.2a correction, the remaining method-spine slice is `!`
inspiration and master-task completion gating (1.5.5). Settings polish, broad
search, grammar expansion, and PWA work remain deferred.

## Deployment boundary

Production at https://bujo.questlog.dev still runs through 1.4.1. Dan runs
deployments himself; hand him `kamal deploy` and do not execute it for him.

After deployment, inspect the few rows created by 1.4.1's Future month-add.
The irreversible migration deliberately backfills them as Daily residents
because it cannot guess intent. With Dan's explicit go-ahead, repair only
confirmed Future rows to `page_kind: "future"` and `page_on: nil`, preserving
`occurs_on`; never bulk-guess.
