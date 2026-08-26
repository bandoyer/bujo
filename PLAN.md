# Bujo — living plan

**This document is the project's source of truth for status and intent.
Update it whenever a slice lands, a decision is made, or the plan
changes — but only the operator/planning session edits it; pack roles
never do (their slice specs bound their file scope).** A future session (human or agent) should be able to read this
file top to bottom and know exactly where things stand and what happens
next.

> **Status: slice 1.5.3a IN PROGRESS (2026-08-26).** The approved experimental
> `six-mix-fable-review` swarm is active from baseline `2a4fb8e`; no candidate
> has been integrated. The pre-swarm baseline is green at 200 fast tests / 3360
> assertions and 56 system tests / 1220 assertions. Production still runs
> 1.4.1.
> See `HANDOFF.md` for the exact landed and process boundaries.

## What this is

A digital Bullet Journal (Ryder Carroll's method) with two clients
sharing one Rails system of record:

- **This repo** — the Rails 8 app: Hotwire PWA for the phone, and later
  the JSON sync API.
- **bujo-tui** (future repo, phases 3–5) — a local-first Ruby TUI for
  Omarchy with a SQLite mirror.

Reference material:

- `docs/METHOD.md` — the binding product interpretation of Ryder
  Carroll's system and practice; source semantics outrank convenience.
- `ARCHITECTURE.md` (this repo) — the sync design; its schema decisions
  bind from slice 1.2 onward.
- [mockups](mockups/README.md) — TUI and mobile mockups; the mobile artboards
  are the visual spec for this app.
- Design canvases: [mockups](https://claude.ai/code/artifact/749c4391-1504-488c-910e-e830d08efa45)
  · [sync architecture](https://claude.ai/code/artifact/062d1db5-9c9e-4748-9ae7-e2593626c623)

## How this project is built

The working loop, proven on [crap4rb](https://github.com/bandoyer/crap4rb):

1. **Plan** — the planning session writes a source-aligned `SLICE.md`-style
   brief with scope, decisions pre-made, tests required, and review criteria.
   Specs live in `docs/slices/` as they are written.
2. **Build** — the swarm implements it:
   [swarm-forge-herdr](https://github.com/bandoyer/swarm-forge-herdr),
   compatibility-named pack `six-mix-fable-review` for 1.5.3a. Its experimental
   roster is Sol Max specifier; Sol High coder; Grok High cleaner; Sol High
   architect; Grok High hardener; Sol XHigh QA. `swarm up` from a herdr
   session, then feed the approved slice as tasks.
3. **Review** — the architect, hardener, QA, and operator verify parity with
   the spec, quality bars, and mutation spot-checks before human-approved
   integration.

Quality bars are in `swarmforge/constitution/articles/project.prompt`
(unit tests, rubocop, crap4rb ≤ 6, jscpd). The `ruby` toolset article
comes from swarm-forge-herdr's `toolsets/ruby.edn`.

## Decisions log

| Date | Decision |
|---|---|
| 2026-08-23 | Minitest over RSpec — omakase; fixtures over factories; low-mock rule (details in the toolset) |
| 2026-08-23 | Sync design settled: cursor + ops protocol, HLC ordering, field-level LWW with kept revisions — see ARCHITECTURE.md |
| 2026-08-24 | Public repo; deploy to a VPS with Kamal; app keeps the name **bujo** |
| 2026-08-24 | Swarm pack: `six-all-models-review` (Claude/Codex/Grok, workers isolated behind human integration) |
| 2026-08-24 | Ruby 4.0.6 via mise (Omarchy's Rails install), Rails 8.1 |
| 2026-08-24 | Mobile look: paper-and-ink direction from the mocks |
| 2026-08-24 | **Both themes ship** (supersedes the line above): light = paper dot-grid, dark = "terminal-kin" using the Tokyo Night palette from the TUI mocks, so web-dark and the TUI rhyme. Default follows the system (`prefers-color-scheme`); a user toggle overrides (light/dark/system three-state). Views are built on CSS custom-property tokens from slice 1.3 onward — theming is a foundation, not a retrofit |
| 2026-08-24 | Host: DigitalOcean (Hetzner's 2026 price hikes closed the gap; DO wins on stability and smoothness). Droplet size decided at deploy time — 2 GB is enough for bujo alone, 4 GB once press-start shares the box |
| 2026-08-24 | Umbrella domain: **questlog.dev** — a quest log is both a gaming term and a journal, covering the whole portfolio. Apps on subdomains: `bujo.questlog.dev`, `pressstart.questlog.dev`. Availability confirmed via registry RDAP 2026-08-24; purchase pending |
| 2026-08-24 | **Book-faithful v1 — everything resides on one page.** After the operator's Part II/III study (`docs/METHOD.md`), Monthly Calendar/Tasks, Future Log, Daily Logs, and Custom Collections become deliberate residency pages. Dates never create page membership and movement is append-only. Temporary reflection, Index, and later search lenses may reference originals without creating a second residency. Start true to Ryder; add digital smartness only where dogfooding proves pain |
| 2026-08-25 | **The core pages keep their vocabulary and time boundary.** Daily/Custom roots accept all bullet kinds; Monthly Calendar and Future roots accept tasks/events; Monthly Tasks roots tasks. The Future Log is for dates after the current month, not merely after today. Direct writing is Daily today/past and Monthly current/past; future Monthly pages can show deliberately migrated residents but are not ordinary capture surfaces. Ryder's night-before Daily exception is consciously deferred rather than approximated with a clock rule |
| 2026-08-25 | **Placement immutability is a domain and sync invariant, not a raw-SQL claim.** Public APIs and mass assignment refuse page changes; movement creates a successor. Database constraints defend structural facts they can express, especially the unique successor chain. Time rules receive a caller-provided `as_of` date (distinct from the parser's page-relative `today`); models do not read the clock |
| 2026-08-25 | **Finish the method spine before convenience work.** After 1.5.1: writable Custom Collections plus a manually maintained Index; monthly migration; AM/PM reflection; then `!` inspiration and master-task completion gating. Broad search, settings polish, and PWA work follow. Dedicated modules for every Part III example are unnecessary; generic Collections and reflection carry the practice |
| 2026-08-25 | **Slice 1.5.2 approved.** The deliberate Index uses a server-allocated nullable `index_position`; exact Topic access preserves intentional reachability without discovery; inbound Daily/Monthly movement ships now; deletion is never-used only; Collection residents receive Complete/Strike/Reopen but no outbound movement. The approved phone header always puts the page title first and context underneath |
| 2026-08-26 | **Review-pack change.** Slice 1.5.3 and the next swarm use `six-mix-fable-review`, superseding `six-all-models-review` for new work. The completed 1.5.2 swarm is retired before switching packs; no new swarm starts before its source-aligned specification and mock are approved |
| 2026-08-26 | **Mock source joined the app repository.** The pre-project `bujo-mockups` checkout now lives at `mockups/`; new page mocks use the current app tokens, one selected hand for all visible text, and page-title-first hierarchy |
| 2026-08-26 | **Slice 1.5.3 approved.** Monthly Migration uses target-month URLs for past/current/next month, derives progress from Entry state, reviews Calendar → Tasks → Daily trees, scans only exact-target-month Future roots, and clears temporal fields only from tasks rewritten to Monthly Tasks. `six-mix-fable-review` may begin |
| 2026-08-26 | **Slice 1.5.3 landed.** The deliberate Monthly Migration ritual shipped with no schema or persisted progress state. Terminal candidate `329b8f6`; 200 fast / 56 system tests, CRAP ≤ 6 over 194 methods, zero clones, and RapidLog mutation 1105/1105. Dogfood the ritual before freezing Daily Reflection behavior |
| 2026-08-26 | **Slice 1.5.3a approved from phone dogfooding.** Daily and Monthly Tasks gain truthful trailing writing surfaces; Calendar date rows capture with a separate Daily chevron; Future reuses the shared kind controls and gains reachable trailing capture plus aligned residents; Index gains a trailing create gesture; empty Monthly Migration stages require explicit Scan and Finish gestures. The approved mock is `mockups/PhoneCaptureCorrection.dc.html`; no page semantics, schema, parser, automatic behavior, or persisted ritual state changes |
| 2026-08-26 | **Experimental 1.5.3a swarm roster.** Keep the compatibility pack name `six-mix-fable-review`, with Sol Max specifier, Sol High coder, Grok High cleaner, Sol High architect, Grok High hardener, and Sol XHigh QA. All roles remain isolated and the terminal candidate still requires operator review and explicit human integration approval |
| 2026-08-26 | **Slice 1.5.3a implementation started.** Planning baseline `2a4fb8e` is pushed; the six-role experimental swarm is active in isolated `mix-*` worktrees. The Rails headless-Chrome lane remains authoritative and root integration stays behind explicit operator review and human approval |
| 2026-08-26 | **`blackcat.dev` acquired and will replace `questlog.dev` as the umbrella domain.** Bujo's planned origin is `bujo.blackcat.dev`; Press Start is tentatively `lift.blackcat.dev`, pending its own deployment ruling. Resend's Cloudflare setup installed DKIM, SPF, and return-path MX, monitoring-mode DMARC is saved, and the aggregate domain is verified. Bujo's domain-restricted production key is stored in 1Password; application implementation and production cutover remain, while Press Start gets its own key only during its later slice |
| 2026-08-26 | **Transactional email provider selected: Resend over HTTPS.** Bujo and Press Start will share the one verified `blackcat.dev` sending domain and free-plan quota, using `bujo@blackcat.dev` and `lift@blackcat.dev`, but keep separate domain-restricted Sending access keys, code, secrets, and deployments. See `docs/resend-transactional-email.md` |
| 2026-08-26 | **Rails authentication rollout fixed at five ordered steps.** (1) Resend delivery plus short-lived, single-use magic links; (2) canonical cutover to `bujo.blackcat.dev`; (3) discoverable passkey registration/sign-in with exact RP ID `bujo.blackcat.dev`; (4) prove two passkeys plus email recovery; (5) retire the password UI. Provider/DNS/key setup is complete and Step 1 is next in the authentication track after the immediate 1.5.3a journal correction. The approved direction is `mockups/SignIn.dc.html`; full gates live in `docs/resend-transactional-email.md` |
| 2026-08-24 | **Route by gesture, not by parsing.** The rapid-log grammar freezes at its 1.1 forms; dating an entry is a deliberate act — write on the day's page (capture logs onto the page you opened, superseding the 1.3 capture-always-today ruling) or write under a Future Log month. The drafted grammar expansion is parked unbuilt (`docs/slices/1.4.3`); parse preview deferred with it |

## Phases and slices

### Phase 0 — scaffold ✅ (2026-08-24)

- [x] Rails 8.1 on Ruby 4.0, omakase defaults, no CSS framework
- [x] Session auth (Rails 8 generator), single seeded user, root placeholder
- [x] Quality bars wired: COVERAGE=1 → lcov → crap4rb; rubocop-minitest; jscpd
- [x] Swarm config: `six-all-models-review` pack + ruby toolset + project article
- [x] This plan

### Phase 1 — the journal (web app usable end-to-end)

- [x] **1.1 Rapid-log parser** ✅ (2026-08-24) — `Bujo::RapidLog` in
      `lib/`, spec at `docs/slices/1.1-rapid-log-parser.md`. Full
      six-pack run + operator review; bars at merge: 33 tests green,
      mutation 1105/1105 killed, CRAP ≤ 6, rubocop/jscpd clean, purity
      boundary test. Bonus from a qa finding: the browser acceptance
      lane (`bin/rails test:system`, headless Chrome) now exists,
      seeded with the sessions flow.
- [x] **1.2 Entries & collections** ✅ (2026-08-24) — Entry/Collection
      models, spec at `docs/slices/1.2-entries-and-collections.md`
      (amended in-flight: integer `user_id` FK, pinned scope ordering).
      Full six-pack run + operator review; at merge: 66 tests green,
      21/21 operator probes (incl. raw-SQL unique-chain-index attack),
      4/4 hand-mutations killed, parser mutation still 1105/1105,
      CRAP ≤ 6 over 57 methods, system lane green.
- [x] **1.3 Daily Log** ✅ (2026-08-24) — Daily Log screen, rapid-log
      bar, entry lifecycle actions, day navigation, and the token-based
      theme system (paper light / Tokyo Night dark / system-follow,
      cookie-backed toggle). Root moved off the sign-in placeholder.
      Spec at `docs/slices/1.3-daily-log.md` (amended in-flight: header
      counts the rendered tree; path-scope baseline is the accepted-spec
      commit; schedule refuses unusable dates). Four qa verification
      passes + operator review; review sent back two findings (schedule
      500 on a crafted date, a surviving `.kept` hand-mutant in the
      header count), fixed in a follow-up pass. At merge: 80 fast + 10
      system runs green, rubocop clean, CRAP ≤ 6 over 78 methods, jscpd
      0 clones, parser mutation 1105/1105, 4/4 hand-mutations killed,
      both themes visually verified, tenancy probe clean.
- [x] **1.3.1 Collapsed task actions** ✅ (2026-08-24, mini slice) —
      the five task buttons collapse behind a row tap, per the picked
      "Tap to reveal" mock ([canvas](https://claude.ai/code/artifact/016d3b48-d915-416c-a073-14ed1abcb7f6)).
      Spec at `docs/slices/1.3.1-collapsed-task-actions.md` (specifier
      added four rulings at acceptance: line-only toggle, strips reopen
      on actions, distinct Schedule…/Schedule names, one tap per
      action). Single clean qa pass + operator review; at merge: 80
      fast + 11 system runs green, all bars, 3/3 hand-mutations
      killed, both themes verified against the mock.
- [x] **1.3.2 Hand lettering** ✅ (2026-08-24, mini slice) — Permanent
      Marker is the journal's default face (full treatment), with a
      header cycler through Rock Salt / Architects Daughter / Patrick
      Hand / Gochi Hand / an all-sans look (operator post-merge swap:
      the serif stop became sans and Newsreader left the app). Faces
      picked on the [Hand-Lettered Titles canvas](https://claude.ai/code/artifact/31d0cb57-850b-4498-95b1-9dab725ccc03);
      spec at `docs/slices/1.3.2-hand-lettering.md`. The swarm
      extracted a shared PreferenceCookies concern + one Stimulus
      cycler serving both toggles; theme tests byte-identical. Single
      clean qa pass + operator review; at merge: 83 fast + 13 system
      runs green, all bars, 3/3 hand-mutations killed, marker verified
      in both themes.
- [x] **1.4 Monthly + Future Logs** ✅ (2026-08-24) — the Month and
      Future tabs live: month-at-a-glance day-list calendar behind a
      Calendar|Tasks pill, the month's full task history with the
      open·logged count, and the month-grouped Future runway with six
      visible headers. Reading screens — every row navigates to its
      day's Daily Log. Shared tab bar with the mocks' SVG icons; Index
      stays the placeholder. Spec at
      `docs/slices/1.4-monthly-and-future-logs.md`, all three
      artboards operator-approved. Single clean qa pass (it caught and
      fixed its own flaky-wait) + operator review; at merge: 94 fast +
      22 system runs green, all bars, 3/3 hand-mutations killed,
      screens verified against the mocks in both themes.
- [x] **1.4.1 Placement and capture** ✅ (2026-08-24, mini slice) —
      route by gesture: the capture bar hides at rest and writes onto
      the page you opened (superseding 1.3's capture-always-today,
      annotated in both specs); the Future Log gained the original
      write-under-a-month behavior; relative tokens resolve
      against the page; submit copy is "Log"; nav shows the viewed day
      with the Today tab as the way home. Mock-first
      ([Placement Gestures](https://claude.ai/code/artifact/9299895f-f328-4910-99e3-2fe3754b4f40));
      spec at `docs/slices/1.4.1-placement-and-capture.md`. Two qa
      passes + operator review; at merge: 102 fast + 29 system runs
      green, all bars, 3/3 hand-mutations killed. ("Place from today"
      artboard parked; grammar expansion parked unbuilt per the
      route-by-gesture decision.) The 1.5.1 spec now supersedes its
      future-day Daily writing and corrects its Future boundary from
      after-today to after-current-month.
- [ ] **1.5 The book-faithful realignment** (see decisions log +
      `docs/METHOD.md`):
      - [x] **1.5.1 The page model and its pages** ✅ (2026-08-25) —
            schema uses immutable-through-domain `page_kind`/`page_on`;
            every log is a residency scope;
            Calendar/Tasks/Future become semantically constrained
            pages; future-page and future-month capture are guarded;
            append-only movement becomes page-aware. The UI exposes
            Future scheduling for tasks/events, not notes. QA pass 1
            found crafted lifecycle commands could bypass read-only
            Future/Collection pages; follow-up 1.5.1a put all five
            member commands behind one persisted-residency guard and
            QA pass 2 verified the full slice. At merge: 133 fast + 33
            system runs green, RuboCop clean, CRAP ≤ 6 over 126
            methods, jscpd 0 clones, parser mutation 1105/1105. Spec at
            `docs/slices/1.5.1-the-page-model.md`.
      - [x] **1.5.2 Custom Collections + deliberate Index** ✅
            (2026-08-26) — a minimal writable Collection page, explicit
            server-ordered registration in the Index, exact-Topic access to
            known unindexed pages, and append-only inbound movement from
            eligible Daily/Monthly residents. Core logs remain fixed
            navigation; Daily Logs are never indexed, and broad search stays
            deferred. Operator review caught and closed unbounded Topic
            wrapping and duplicate move-field ids. Final candidate `1ae8136`;
            at merge: 188 fast + 50 system runs green, RuboCop clean, CRAP ≤ 6
            over 159 methods, jscpd 0 clones, parser mutation 1105/1105. Spec
            at `docs/slices/1.5.2-custom-collections-and-index.md`.
      - [x] **1.5.3 Monthly migration ritual** ✅ (2026-08-26) — set up the new
            Monthly Log and fresh mental inventory; review every
            unresolved task on the outgoing month's Daily and Monthly
            pages one at a time, with its tree context; strike it or
            rewrite it to the new Tasks page, a Custom Collection, or
            the Future Log. Then scan due Future tasks into the new
            Tasks page and due events into the Calendar. No bulk
            rollover and no silent carry. Contract at
            `docs/slices/1.5.3-monthly-migration-ritual.md`; review mock at
            `mockups/MonthlyMigration.dc.html`. Terminal candidate `329b8f6`;
            at merge: 200 fast + 56 system runs green, RuboCop clean, CRAP ≤ 6
            over 194 methods, jscpd zero clones, parser mutation 1105/1105.
      - [ ] **1.5.3a Phone capture and ritual clarity** — approved dogfood
            correction before Daily Reflection. Make the real blank canvas
            writable on Daily, Monthly Tasks, Future, and Index; make Calendar
            row capture primary with a separate Daily chevron; align Future
            residents and reuse the shared Task/Event controls; require
            explicit participation at both empty migration checkpoints.
            Contract at
            `docs/slices/1.5.3a-phone-capture-and-ritual-clarity.md`; approved
            review mock at `mockups/PhoneCaptureCorrection.dc.html`.
      - [ ] **1.5.4 Daily Reflection** — a small first-class AM/PM
            review: AM sees the current month's open tasks; PM walks
            today's entries to complete, strike, or schedule and makes
            progress visible. This is a reference lens over resident
            entries, never a new page or automatic movement.
      - [ ] **1.5.5 Core notation and hierarchy fidelity** — add the
            `!` inspiration signifier and gate a master task's
            completion until every subtask is done or struck. Keep the
            parked date-grammar expansion separate.
- [ ] **1.6 PWA** — manifest/service worker, vendor the fonts for
      offline. (The deploy, Kamal, and Litestream landed early, with
      1.3 — done 2026-08-24 per the dogfood-first ruling; Phase 1 gets
      built under real use.)

### Phase 2 — the sync spine

- [ ] `server_seq` stamping, `/api/sync` (push ops / pull snapshots),
      `applied_ops` idempotency ledger, HLC, epoch, conflict rules with
      `entry_revisions`. Curl-testable; the conflict table in
      ARCHITECTURE.md becomes the contract test suite the TUI will run
      against.

### Phases 3–5 — the TUI (separate repo `bujo-tui`)

- [ ] 3: OAuth device grant + read-only SQLite mirror
- [ ] 4: local writes + pending-ops queue + conflict handling
- [ ] 5: SSE nudge; phone rapid-log outbox in the PWA

## Open items

- ~~mutant licensing~~ resolved 2026-08-24: mutant 0.16.3 installs and
  runs with no license prompt on this machine
- ~~Droplet~~ **deployed 2026-08-24**: droplet `bujo` (s-1vcpu-2gb,
  nyc3, Ubuntu 24.04) at 174.138.85.202, firewall `bujo-web`
  (22/80/443 by tag), SSH key `bujo-deploy` (`~/.ssh/id_ed25519`).
  Kamal + kamal-proxy with Let's Encrypt; images on GHCR
  (`ghcr.io/bandoyer/bujo`, gh CLI token with write:packages).
  Litestream runs as a Kamal accessory replicating the primary
  database to R2 bucket `bujo-litestream` (came forward from 1.7);
  creds at `~/.config/cloudflare/bujo-r2-credentials` (mode 600).
  `doctl` is authed for droplet management
- Domain: **questlog.dev** purchased 2026-08-24 (Cloudflare Registrar;
  DNS at Cloudflare). Zone carries the no-email lockdown (SPF `-all`,
  DMARC reject, empty wildcard DKIM, null MX) as of 2026-08-24.
  **`bujo.questlog.dev` live 2026-08-24**: A record → 174.138.85.202,
  DNS-only/grey-cloud so Let's Encrypt HTTP-01 reaches kamal-proxy —
  don't flip it to proxied without rethinking certs. Zone-scoped DNS
  token at `~/.config/cloudflare/questlog-dns-token` (mode 600, never
  committed). **Replacement acquired 2026-08-26 but not cut over:**
  `blackcat.dev`, with Bujo at `bujo.blackcat.dev` and Press Start likely at
  `lift.blackcat.dev`. Resend's generated Cloudflare records were installed
  and individually verified 2026-08-26; aggregate domain status is verified.
  Web-origin DNS and the production cutover remain pending. This
  supersedes the earlier thought that Press Start would need its own
  registrable domain; its hostname remains tentative until Press Start's own
  deployment decision
- Transactional email: **Resend selected 2026-08-26**, using its HTTPS
  API because DigitalOcean blocks outbound SMTP. Bujo and Press Start will
  share one exact verified sending domain so the current free plan can cover
  both; each gets its own domain-restricted Sending access key and From
  identity: `bujo@blackcat.dev` and `lift@blackcat.dev`. Provider DNS records
  and monitoring-mode DMARC are installed, the domain is verified, and Bujo's
  scoped production key is stored in 1Password. Implementation happens before
  the web cutover; Press Start gets its own key later. Full cross-app plan and gates:
  `docs/resend-transactional-email.md`
- Packwerk (boundaries bar): deferred until the app has a boundary
  worth defending (slice 1.1 added a require-graph boundary test for
  `lib/bujo/` in its place)
- ~~Project skills~~ done 2026-08-24: `.claude/skills/bujo-conventions`
  and `.claude/skills/testing`
- Fonts served from Google Fonts as of 1.3; vendor locally in 1.6
  (PWA/offline) — the existing `TODO(1.7)` marker must be
  renamed when that slice touches the link site
- Settings/session polish (`/settings`, sign-out, preference controls,
  perhaps lines) follows the 1.5 method spine; it no longer interrupts
  source realignment as the next UI slice
- Broad text search is deferred until the deliberate 1.5.2 Index has
  been dogfooded. Yearly migration gets its own later spec only after
  the monthly ritual is proven
- `bin/ci` does not yet run the system lane or mutation — operator
  decision on wiring, revisit before slice 1.3's deploy
- Auth direction (decided 2026-08-24, build later): go passwordless
  like press-start — passkeys first, magic email links second. The
  generator's email/password remains only as a transitional rollback. The
  provider foundation is complete; Step 1 is next in the authentication track
  after the immediate 1.5.3a journal correction.
  `docs/resend-transactional-email.md` owns its live checklist and safety gates.
  Bujo passkeys bind exactly to `bujo.blackcat.dev`, never the old host or Press
  Start. Recovery is proven before password retirement by registering two
  passkeys (phone + laptop) and retaining the magic-email fallback. Pairs with
  the multi-user item below (same email decision gates both)
- Multi-user: the data layer is already tenant-clean (assessed
  2026-08-24 — `user_id` FKs, per-user indexes/uniqueness, user-scoped
  model API; the 1.3 spec scopes all queries via `Current.user`).
  Invite-only guests are nearly free: console-created accounts, no new
  code. Public sign-up is one small slice (RegistrationsController +
  abuse/rate-limit work) after the Resend delivery slice is proven; the
  provider decision is no longer its gate. Revisit after phase 1

## How to resume (for a future session)

1. Read `docs/METHOD.md`, then this file, `ARCHITECTURE.md`, and
   `HANDOFF.md` in that authority order.
2. `git log --oneline -15` for what actually landed.
3. Check the **Status** line above; if a slice is mid-flight, its spec
   is in `docs/slices/` and the swarm state is visible via `swarm status`
   / herdr.
4. Keep the loop: spec → swarm → review. Update this file when anything
   changes.
