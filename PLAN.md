# Bujo — living plan

**This document is the project's source of truth for status and intent.
Update it whenever a slice lands, a decision is made, or the plan
changes — but only the operator/planning session edits it; pack roles
never do (their slice specs bound their file scope).** A future session (human or agent) should be able to read this
file top to bottom and know exactly where things stand and what happens
next.

> **Status: PARKED mid-slice 1.5.1 (2026-08-24 late) — the swarm is
> RUNNING the page-model chain and survives session restarts. See
> `HANDOFF.md` for the exact state, the review protocol, and the
> post-merge follow-ups. Prod runs 1.4.1; polish + realignment are
> committed, undeployed.**

## What this is

A digital Bullet Journal (Ryder Carroll's method) with two clients
sharing one Rails system of record:

- **This repo** — the Rails 8 app: Hotwire PWA for the phone, and later
  the JSON sync API.
- **bujo-tui** (future repo, phases 3–5) — a local-first Ruby TUI for
  Omarchy with a SQLite mirror.

Reference material:

- `ARCHITECTURE.md` (this repo) — the sync design; its schema decisions
  bind from slice 1.2 onward.
- [bujo-mockups](https://github.com/bandoyer/bujo-mockups) — TUI and
  mobile mockups; the mobile artboards are the visual spec for this app.
- Design canvases: [mockups](https://claude.ai/code/artifact/749c4391-1504-488c-910e-e830d08efa45)
  · [sync architecture](https://claude.ai/code/artifact/062d1db5-9c9e-4748-9ae7-e2593626c623)

## How this project is built

The working loop, proven on [crap4rb](https://github.com/bandoyer/crap4rb):

1. **Plan** — Claude (Fable) writes the slice spec: a `SLICE.md`-style
   brief with scope, decisions pre-made, tests required, and review
   criteria. Specs live in `docs/slices/` as they are written.
2. **Build** — the swarm implements it:
   [swarm-forge-herdr](https://github.com/bandoyer/swarm-forge-herdr),
   pack `six-all-models-review` (config committed under `swarmforge/`).
   `swarm up` from a herdr session, feed the slice as tasks.
3. **Review** — Fable reviews against the spec before merge: parity
   with the plan, quality bars, and mutation spot-checks on the tests.

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
| 2026-08-24 | **Book-faithful v1 — everything is a page.** After the operator's Part II/III study (`docs/METHOD.md`), all derived surfaces go: Monthly Calendar/Tasks and the Future Log become pages you write into, placement is by hand only, and future-dated content waits in the Future Log until migration carries it in (write-on-page narrows to today/past, superseding part of 1.4.1). Model-first: the page model (immutable `page_kind`/`page_on` columns, append-only movement) is drafted in ARCHITECTURE.md; staged slices follow, with 1.5's migration ritual as capstone. Start true to Ryder; add digital smartness later only where dogfooding proves pain |
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
      annotated in both specs); the Future Log gained
      write-under-a-month (strictly future); relative tokens resolve
      against the page; submit copy is "Log"; nav shows the viewed day
      with the Today tab as the way home. Mock-first
      ([Placement Gestures](https://claude.ai/code/artifact/9299895f-f328-4910-99e3-2fe3754b4f40));
      spec at `docs/slices/1.4.1-placement-and-capture.md`. Two qa
      passes + operator review; at merge: 102 fast + 29 system runs
      green, all bars, 3/3 hand-mutations killed. ("Place from today"
      artboard parked; grammar expansion parked unbuilt per the
      route-by-gesture decision.)
- [ ] **1.5 The book-faithful realignment** (see decisions log +
      `docs/METHOD.md`):
      - [ ] **1.5.1 The page model and its pages** — IN FLIGHT
            (2026-08-24). Schema: immutable `page_kind`/`page_on`;
            every log becomes a residency scope; calendar/tasks/future
            become writable pages; movement generalizes to events and
            notes; write-on-page narrows to today/past. Spec at
            `docs/slices/1.5.1-the-page-model.md`.
      - [ ] **1.5.2 The migration ritual** — the capstone:
            card-per-task monthly review per the Migration mock,
            plus the future-log scan-in at month setup.
- [ ] **1.6 Index** — search across collections and entries.
- [ ] **1.7 PWA** — manifest/service worker, vendor the fonts for
      offline. (The deploy, Kamal, and Litestream landed early, with
      1.3 — done 2026-08-24 per the dogfood-first ruling; 1.4–1.6 get
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
  committed). press-start gets its own domain later if it launches
  publicly
- Packwerk (boundaries bar): deferred until the app has a boundary
  worth defending (slice 1.1 added a require-graph boundary test for
  `lib/bujo/` in its place)
- ~~Project skills~~ done 2026-08-24: `.claude/skills/bujo-conventions`
  and `.claude/skills/testing`
- Fonts served from Google Fonts as of 1.3; vendor locally in 1.7
  (PWA/offline) — a `TODO(1.7)` marks the link site
- `bin/ci` does not yet run the system lane or mutation — operator
  decision on wiring, revisit before slice 1.3's deploy
- Auth direction (decided 2026-08-24, build later): go passwordless
  like press-start — passkeys first, magic email links second. The
  generator's email/password stands in until then. Two constraints to
  design around: (1) magic links require sending mail, which the
  questlog.dev no-email lockdown deliberately blocks — either an email
  provider on a carved-out subdomain or passkeys-only; (2) passkeys-only
  needs a recovery story without email — register a second passkey
  (phone + laptop) and bootstrap the first from a signed-in session.
  Pairs with the multi-user item below (same email decision gates both)
- Multi-user: the data layer is already tenant-clean (assessed
  2026-08-24 — `user_id` FKs, per-user indexes/uniqueness, user-scoped
  model API; the 1.3 spec scopes all queries via `Current.user`).
  Invite-only guests are nearly free: console-created accounts, no new
  code. Public sign-up is one small slice (RegistrationsController +
  abuse/rate-limit thought) **plus an email decision** — questlog.dev's
  no-email lockdown blocks password-reset mail, so either add a
  provider on an email subdomain and relax the lockdown, or stay
  invite-only with manual resets. Revisit after phase 1

## How to resume (for a future session)

1. Read this file, then `ARCHITECTURE.md`.
2. `git log --oneline -15` for what actually landed.
3. Check the **Status** line above; if a slice is mid-flight, its spec
   is in `docs/slices/` and the swarm state is visible via `swarm status`
   / herdr.
4. Keep the loop: spec → swarm → review. Update this file when anything
   changes.
