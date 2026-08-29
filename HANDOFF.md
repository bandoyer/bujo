# Handoff: Auth Step 1 implementation authorized; blackcat.dev live (2026-08-29)

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

`main` and `origin/main` are aligned at
`867e3b28e07ef92ad295acd006a549d930c2f5e2` before the current uncommitted
planning edits. Both `handoffd` and `squadd` are stopped. The six existing `cg-*` role
worktrees remain from the completed 1.5.5 run: QA points at the integration
commit and the other five point at terminal candidate `70b9c742`. They are
inactive, not alternate sources of truth. Do not start or retire a pack until
Dan approves the next contract and orchestration step.

Slice 1.5.3's approved terminal candidate is `329b8f6` and is integrated on
`main`. Slice 1.5.3a's terminal candidate is `92c43e2`; it is also integrated
on `main`, and its completed six-role swarm is retired. Phone dogfooding then
produced correction slice 1.5.3b. Its terminal candidate `dc2153c` is now
integrated on `main`; its contract is
`docs/slices/1.5.3b-dogfood-entry-corrections.md`, with the approved review
board at `mockups/PhoneDogfoodCorrections.dc.html`. Daily Reflection terminal
candidate `c2127b5` is also integrated and pushed on `main` after Dan's explicit
2026-08-28 approval. Index source correction terminal candidate `12f8164` is
also integrated and pushed after Dan's explicit approval; its completed
`six-cg` swarm is retired. Nothing from 1.5.3a onward has been deployed by
this handoff.

Core notation/hierarchy terminal candidate `70b9c742ccc988575122dfc0b1388ac35235abdf`
is integrated with the operator-owned architecture amendment on `main` at
`867e3b28e07ef92ad295acd006a549d930c2f5e2` after Dan's explicit approval.
Slice 1.5.5 completes the planned method spine. Its contract is
`docs/slices/1.5.5-core-notation-and-hierarchy-fidelity.md` and its review
board is `mockups/CoreNotationHierarchy.dc.html`.

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
- Every kept Custom Collection now belongs to its owner's Index in permanent
  server-allocated append order. Create persists the UUIDv7 page and position
  atomically; prior kept NULL-position rows are registered once in
  deterministic per-user order. Unindex/re-register and Open by Topic no
  longer exist. Entry deletion remains deferred.
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
- Index source correction terminal candidate `12f8164` passed the complete
  `six-cg` chain. Root repeated the exact final tree at 281 fast tests / 6644
  assertions, 112 headless-Chrome system tests / 16796 assertions, 30 focused
  Collection/migration/controller tests / 375 assertions, and 116
  RuboCop-clean files. Terminal QA also recorded CRAP ≤ 6 over 262 methods,
  zero clones, RapidLog mutation 1105/1105, and passing concurrency and raw
  database-constraint probes.
- Architect review recorded one non-blocking dogfood seam: a populated
  outgoing month currently derives trees with per-node child/successor queries.
  Preserve ruled ordering; optimize only if real journals make it hot.
- Inspiration is an independent Entry signifier and may coexist with priority;
  canonical ink is `*` then `!`. Capture, correction, movement, Undo, render,
  and dormant sync-shaped fields preserve it exactly.
- Completing a master task now refuses while any kept descendant task's live
  append-only chain remains unresolved. Traversal crosses contextual Event and
  Note rows, soft-deleted branches are cut off, and no parent/child state
  cascades.
- An eligible open task exposes the approved `Add below…` gesture using the
  shared Task/Event/Note rapid-log anatomy. Residency and ownership derive from
  the persisted parent; indentation text never creates hierarchy.
- Slice 1.5.5 terminal/root receipts: 309 fast tests / 6916 assertions, 124
  headless-Chrome system tests / 15661 assertions, and RuboCop clean over 121
  files. Terminal QA additionally killed 1167/1167 RapidLog mutants.

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

The bounded Tailwind squad is down and every transient squad worker is retired.
Daily Reflection's completed `mix-*` role worktrees are also retired. The
repository's persistent pack configuration is the stopped `six-cg` pack; its
inactive worktrees remain as recorded above. `swarmforge/squad.conf` remains as
the historical Tailwind squad policy. Do not touch unrelated SwarmForge
processes from other repositories.

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

## Current detour: approved Authentication Step 1

The approved source-aligned contract is
`docs/slices/auth-1-resend-and-magic-links.md`; its smallest review board is
`mockups/MagicLinkTransition.dc.html`. It puts the verified Resend provider
behind Action Mailer and adds a scanner-safe, 15-minute,
generation-invalidated magic-email path while keeping password sign-in/reset
as rollback.

The operator foundation completed 2026-08-29: `bujo.blackcat.dev` is verified
in Resend `us-east-1`, tracking is not configured, `bujo-production` is
Sending-only and restricted to that exact domain, and Kamal safely resolves
`op://Personal/bujo-production/credential`. No secret was printed or committed.

Dan approved magic email as the default sign-in method with password one
explicit tap away, along with the complete security, failure, and transition
contract, on 2026-08-29. Passkeys remain Step 3 and must not appear as a
disabled or fake control. After the canonical cutover and production password
re-proof, Dan authorized the planning commit/push and isolated `six-cg`
implementation run on 2026-08-29. Terminal integration, deployment, provider
delivery, and the live magic-link round trip remain separately gated.

Dan separately authorized the canonical web-origin cutover from
`bujo.questlog.dev` to `bujo.blackcat.dev`. Active Kamal configuration now
names the blackcat host and its future explicit `APP_ORIGIN`/`MAIL_FROM`. The
cutover completed 2026-08-29: public DNS resolves the DNS-only A record to
`174.138.85.202`; TLS and `/up` are healthy; the root redirects to the new
host's `/session/new`; and Kamal proxy serves the unchanged deployed image
`48631001093af1ebd2fb323a0242905da11f1b1c`. The old proxy host and exact
`bujo.questlog.dev` A record were retired only after the overlap verification.
No application image was built, replaced, or deployed.

## Parked proposal: slice 1.6 Installable PWA

The proposed source-aligned contract is
`docs/slices/1.6-installable-pwa.md`; its smallest review board is
`mockups/PwaInstallOffline.dc.html`. It activates an origin-neutral manifest
and minimal service worker, replaces the red generator icons, vendors the seven
font families the live app actually uses, and supplies a neutral offline page
only when a top-level page fetch genuinely fails.

The boundary is intentionally honest: service-worker CacheStorage contains
only the public fallback and its default marker font. No journal HTML or data
is cached, and no failed capture/action is queued or described as saved. Phone
rapid-log outbox/replay stays in phase 5 after the sync spine.

Dan must approve the paper/dot-grid Rapid Log app mark shown under square,
circle, and rounded masks before implementation. The deployment timing is now
settled: first production enablement follows the canonical
`bujo.blackcat.dev` cutover.

Keep the parked date-grammar expansion, Entry deletion, search, settings
polish, authentication, active sync, and deployment outside
1.6. The PWA and authentication tracks do not run in parallel; 1.6 remains
parked while the explicitly chosen authentication detour awaits its separate
implementation gate.

## Build and review

Keep the proven loop: source-aligned spec and smallest review mock → Dan's
explicit approval → approved orchestration → operator review → Dan's explicit
integration approval → merge and push. Do not perform a normal application
release for Dan; the exact-image domain-only transition is the explicit
exception recorded above. Authentication Step 1 is the sole authorized swarm
scope; no 1.6 swarm is authorized.

The current `six-cg` roster is Sol Max specifier, Sol High coder, Grok 4.6
High cleaner, Grok 4.6 xhigh architect, Grok 4.6 High hardener, and Sol xhigh
QA. All roles use isolated `cg-*` worktrees. Passing QA is terminal only for
implementation; it does not authorize root integration or push.

Herdr roles have no Codex Desktop in-app Browser backend. QA must not attempt
or disclaim that surface; `bin/rails test:system` is the authoritative
headless-Chrome acceptance lane, supplemented by screenshots,
DOM/geometry/accessibility checks, and direct request/domain probes.

Daily Reflection terminal candidate `c2127b5`, Index source correction
candidate `12f8164`, and Core notation/hierarchy candidate `70b9c742` are
integrated and pushed. The first two completed role-worktree sets are retired;
the stopped `cg-*` worktrees from 1.5.5 must be retired before the authorized
Authentication Step 1 run is seeded from the new planning baseline. Proposed
1.6 remains parked and is not authorized work.

The completed Tailwind track used a dynamic squad, not the old six persistent worktrees:
at most two transient workers; Sol Max leader/specifier; Sol High coder and
architect; Grok 4.6 High cleaner/hardener; Sol XHigh terminal QA. The exact
policy is preserved in `swarmforge/squad.conf`. Deterministic profile support is on
canonical SwarmForge `main` at `b5b17bd` and passed its complete 375-check
smoke suite. Dan's 2026-08-27 approval landed terminal candidate `8d7ccbd`; the
squad is down and every transient worker is retired.

The book-faithful 1.5 method spine is complete. Authentication Step 1 is the
current approved and implementation-authorized detour; the bounded 1.6
installable PWA and truthful offline fallback remains parked as proposed.
Settings polish, broad search, grammar
expansion, offline capture/outbox, and active sync remain deferred.

## Deployment boundary

Production still runs the 1.4.1 image, unchanged, at
`https://bujo.blackcat.dev`. The 2026-08-29 domain-only operation moved the
existing image `48631001093af1ebd2fb323a0242905da11f1b1c` through a verified
two-host overlap, then removed the old proxy host and `bujo.questlog.dev` A
record. It did not turn the dirty planning checkout into an application
release. Normal code deployments remain Dan's action via `kamal deploy`.

After deployment, inspect the few rows created by 1.4.1's Future month-add.
The irreversible migration deliberately backfills them as Daily residents
because it cannot guess intent. With Dan's explicit go-ahead, repair only
confirmed Future rows to `page_kind: "future"` and `page_on: nil`, preserving
`occurs_on`; never bulk-guess.
