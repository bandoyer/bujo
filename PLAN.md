# Bujo — living plan

**This document is the project's source of truth for status and intent.
Update it whenever a slice lands, a decision is made, or the plan
changes — but only the operator/planning session edits it; pack roles
never do (their slice specs bound their file scope).** A future session (human or agent) should be able to read this
file top to bottom and know exactly where things stand and what happens
next.

> **Status: the 1.5 method spine LANDED; Authentication Step 1 IMPLEMENTATION
> AUTHORIZED;
> canonical blackcat.dev cutover COMPLETE; 1.6 Installable PWA PARKED AS
> PROPOSED (2026-08-29).** Slice 1.5.5 terminal
> candidate `70b9c742` is integrated on `main` at `867e3b28`; root verification
> is green. Dan authorized the `six-cg` authentication implementation run on
> 2026-08-29; terminal integration and deployment remain separate gates.
> Production now serves the unchanged 1.4.1 image at
> `https://bujo.blackcat.dev`; the old `bujo.questlog.dev` proxy route and A
> record are retired. The approved authentication contract is
> `docs/slices/auth-1-resend-and-magic-links.md` and
> `mockups/MagicLinkTransition.dc.html`. No authentication or 1.6
> implementation is authorized; no 1.6 implementation/swarm is authorized.
> See `HANDOFF.md`.

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
2. **Build** — the approved swarm or bounded squad implements it:
   [swarm-forge-herdr](https://github.com/bandoyer/swarm-forge-herdr). The
   current `six-cg` pack uses Sol Max specifier, Sol High coder, Grok 4.6 High
   cleaner, Grok 4.6 xhigh architect, Grok 4.6 High hardener, and Sol xhigh QA,
   all isolated behind human integration. The historical
   `six-mix-fable-review` roster carried 1.5.3a through 1.5.4; Tailwind used the
   repository's bounded dynamic squad profile.
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
| 2026-08-26 | **Slice 1.5.3a landed.** Terminal candidate `92c43e2` is integrated on `main` and its six-role swarm is retired. The merged tree passes 201 fast tests / 3412 assertions, 61 headless-Chrome system tests / 1383 assertions, and RuboCop. The first parallel system run had two transient sign-in setup failures; both exact cases passed together in isolation and the complete rerun passed. Operator phone dogfooding is the next gate |
| 2026-08-26 | **Slice 1.5.3b approved from phone dogfooding.** Ordinary Monthly Calendar/Tasks capture offers Task/Event/Note; current entries gain constrained correction without residency/history edits; same-month Schedule targets Calendar while later dates target Future; the native date input becomes full-size; row alignment and lifecycle ink remain stable; every ritual resolution offers append-only immediate Undo; newly created Collections remain deliberately unindexed but expose their next step; Entry deletion is deferred. Contract: `docs/slices/1.5.3b-dogfood-entry-corrections.md`; approved board: `mockups/PhoneDogfoodCorrections.dc.html` |
| 2026-08-26 | **Slice 1.5.3b implementation authorized.** Continue the `six-mix-fable-review` roster unchanged: Sol Max specifier, Sol High coder, Grok High cleaner, Sol High architect, Grok High hardener, Sol XHigh QA. The Rails headless-Chrome system lane is authoritative; terminal QA still requires operator review and explicit integration approval |
| 2026-08-26 | **Slice 1.5.3b landed.** Terminal candidate `dc2153c` is integrated on `main` after one complete QA correction loop. The merged tree passes 230 fast tests / 3822 assertions, 81 headless-Chrome system tests / 1640 assertions, and RuboCop; terminal QA also recorded CRAP ≤ 6 over 234 methods, zero clones, and RapidLog mutation 1105/1105. Hands-on phone dogfooding is the next gate; Entry deletion remains deferred |
| 2026-08-26 | **`blackcat.dev` acquired and will replace `questlog.dev` as the umbrella domain.** Bujo's planned origin is `bujo.blackcat.dev`; Press Start is tentatively `lift.blackcat.dev`, pending its own deployment ruling. Resend's Cloudflare setup installed DKIM, SPF, and return-path MX, monitoring-mode DMARC is saved, and the aggregate domain is verified. Bujo's domain-restricted production key is stored in 1Password; application implementation and production cutover remain, while Press Start gets its own key only during its later slice |
| 2026-08-26 | **Transactional email provider selected: Resend over HTTPS.** The original shared-root-domain plan was superseded on 2026-08-29 after the free tier expanded to three verified domains. See `docs/resend-transactional-email.md` for the current app-specific boundary. |
| 2026-08-26 | **Rails authentication rollout fixed at five ordered steps.** (1) Resend delivery plus short-lived, single-use magic links; (2) canonical cutover to `bujo.blackcat.dev`; (3) discoverable passkey registration/sign-in with exact RP ID `bujo.blackcat.dev`; (4) prove two passkeys plus email recovery; (5) retire the password UI. Provider/DNS/key setup is complete and Step 1 is unblocked in the separate authentication track. The approved direction is `mockups/SignIn.dc.html`; full gates live in `docs/resend-transactional-email.md` |
| 2026-08-26 | **Tailwind migration orchestration selected; migration not yet authorized.** If approved, the proposed Tailwind v4 conversion runs as a dynamic squad with at most two transient workers, a `codex/tailwind-v4` integration branch, and explicit operator approval before `main`. The roster uses Sol Max for leadership and specification workers, Sol High for implementation and architecture, Grok 4.6 High for cleanup and hardening, and Sol XHigh for terminal QA. At selection time the squad launcher still needed deterministic per-leader/per-template model-and-effort support. See `docs/tailwind-v4-migration-plan.md` |
| 2026-08-27 | **Tailwind squad tooling prerequisite landed; launch still withheld.** Deterministic leader/default/template/assignment profiles are now on canonical SwarmForge `main` at `b5b17bd` and pass its complete 375-check smoke suite. Bujo's repository-owned `swarmforge/squad.conf` records the approved two-worker roster and `codex/tailwind-v4` integration branch |
| 2026-08-27 | **Tailwind T0 and source-aligned specification prepared; implementation not authorized.** Baseline `434a9a9` is frozen in `docs/tailwind-v4-baseline/` with 135 screenshots, computed geometry, selector ownership, assets, and green quality receipts. The proposed contract at `docs/slices/tailwind-v4-presentation-migration.md` fixes exact Ruby-hosted v4 gems, no Node/Preflight/default theme, staged legacy parity, stable product behavior, and the bounded squad graph. No mock change is needed for parity; no squad starts until explicit approval |
| 2026-08-27 | **Tailwind v4 presentation migration approved.** Dan approved the complete source-aligned contract and keeping all 135 T0 screenshots in the repository. Commit/push of the planning baseline and `swarm squad up` are authorized. Work remains isolated on `codex/tailwind-v4`; passing terminal QA does not authorize root integration or deployment |
| 2026-08-27 | **Tailwind v4 presentation migration landed.** Dan approved terminal candidate `8d7ccbd` after corrected terminal QA pass 2. The presentation-only migration keeps all accepted behavior and geometry, exact-pins `tailwindcss-rails` 4.6.0 and `tailwindcss-ruby` 4.3.3, uses no Node, Preflight, or default Tailwind theme, and serves one fingerprinted application bundle. The merged tree passes 265 fast tests / 6424 assertions, 94 system tests / 15445 assertions, RuboCop, security audits, coverage/CRAP/duplication, immutable T0 parity, production asset, and Docker checks. Deployment remains Dan's action |
| 2026-08-27 | **Post-Tailwind Calendar baseline correction landed.** Real-device dogfooding exposed Calendar resident ink 13.5 CSS px above the centered date row. The Calendar-only correction brings the date number, weekday, resident glyph, first text line, and metadata within 4 CSS px at 390 px and 320 px; wrapped resident ink grows downward and horizontal geometry and behavior remain unchanged. Dan accepted the corrected phone result and chose Daily Reflection next. The merged tree passes 265 fast tests / 6434 assertions, 95 system tests / 15234 assertions, and RuboCop |
| 2026-08-27 | **Slice 1.5.4 Daily Reflection approved; implementation authorized.** The current-day, no-schema reference lens keeps Morning to shared capture plus current-month dated-page review through the existing `*` priority, and Evening to shared capture plus today's Daily trees with focused Complete/Strike/Schedule actions and derived progress copy. Dan approved all six digital translations in `docs/slices/1.5.4-daily-reflection.md` and the review board at `mockups/DailyReflection.dc.html`. `six-mix-fable-review` may implement in isolation; terminal integration remains separately gated |
| 2026-08-28 | **Slice 1.5.4 Daily Reflection landed.** Dan approved terminal candidate `c2127b5` after three QA correction passes. The integrated tree preserves a current-day Morning/Evening reference lens, shared capture, append-only movement, and ephemeral focus state with no schema, JavaScript, parser, sync, or background behavior. Root verification passes 286 fast tests / 6907 assertions, 112 system tests / 16797 assertions, and RuboCop over 114 files; the completed mix swarm is retired |
| 2026-08-28 | **Index source ruling corrected; implementation not yet authorized.** Ryder's Index is the retrieval container for Collections except Daily, not an optional visibility flag for active Custom Collections. Dan ruled that web Create atomically appends the new Collection to the Index; normal unindex/re-register, hidden live Collections, and Open by Topic go away. Proposed digital transition details are in `docs/slices/1.5.2a-index-is-the-collection-register.md` and `mockups/IndexSourceCorrection.dc.html`; approval remains required before the stopped `six-cg` swarm starts |
| 2026-08-28 | **Current pack changed to `six-cg`.** Sol Max specifies; Sol High codes; Grok 4.6 High cleans; Grok 4.6 xhigh architects; Grok 4.6 High hardens; Sol xhigh QAs. All roles remain isolated and passing QA remains terminal only for implementation |
| 2026-08-28 | **Slice 1.5.2a approved; implementation authorized.** Dan approved all four digital translations in the source-aligned amendment and the smallest review board. The committed planning baseline is `f397837`; `six-cg` may implement in isolated role worktrees. Terminal QA still requires operator review and Dan's explicit approval before integration; deployment remains separate |
| 2026-08-28 | **Slice 1.5.2a Index source correction landed.** Dan approved terminal candidate `12f8164` after the complete `six-cg` chain and independent root review. Creation now atomically appends every live Custom Collection to the complete Index; the irreversible migration deterministically registers prior kept hidden rows; normal unindex/re-register and Open by Topic are gone. Root passes 281 fast tests / 6644 assertions, 112 system tests / 16796 assertions, focused Collection/migration/controller tests, and RuboCop; terminal QA additionally records CRAP ≤ 6 over 262 methods, zero clones, and RapidLog mutation 1105/1105. The completed swarm is retired; deployment remains Dan's action |
| 2026-08-28 | **Slice 1.5.5 proposed; implementation not authorized.** The contract adds Ryder's `!` inspiration signifier and gates master completion through kept descendant task successor chains. It recommends independent/coexisting `*` + `!` fields and exposes the previously missed Rails hierarchy-writing gap through one proposed `Add below…` gesture. Approval must settle both translations before the stopped `six-cg` swarm starts. Contract: `docs/slices/1.5.5-core-notation-and-hierarchy-fidelity.md`; review board: `mockups/CoreNotationHierarchy.dc.html` |
| 2026-08-28 | **Slice 1.5.5 approved; implementation authorized.** Dan approved independent/coexisting `*` + `!` fields with canonical `*!` rendering and the `Add below…` gesture using the shared three-kind rapid-log anatomy. The planning baseline may be committed and pushed, and `six-cg` may implement in isolated `cg-*` worktrees. Terminal QA still requires Dan's explicit approval before root integration; deployment remains separate. |
| 2026-08-29 | **Slice 1.5.5 landed; the method spine is complete.** Dan approved terminal candidate `70b9c742`; root integrated it with the operator-owned architecture amendment at `867e3b28`. The merged tree passes 309 fast tests / 6916 assertions, 124 headless-Chrome system tests / 15661 assertions, and RuboCop over 121 files. Terminal QA additionally killed 1167/1167 RapidLog mutants. The `six-cg` daemons are stopped; deployment remains Dan's action. |
| 2026-08-29 | **Slice 1.6 Installable PWA proposed; implementation not authorized.** The contract activates a minimal manifest and root service worker, vendors the seven live font families, replaces generator icons, and shows a tenant-neutral offline fallback only when a page fetch genuinely fails. It explicitly defers cached journal reads, offline capture, outbox/replay, and sync. First production enablement is settled on `bujo.blackcat.dev`; approval must still settle the proposed icon. Contract: `docs/slices/1.6-installable-pwa.md`; review board: `mockups/PwaInstallOffline.dc.html`. |
| 2026-08-29 | **Resend moved to an app-specific sending boundary.** Resend's free tier now permits three verified domains, so `bujo.blackcat.dev` is independently verified in `us-east-1`, tracking remains disabled, and `bujo-production` is Sending-only and restricted to that exact domain. Bujo sends as `Bujo <sign-in@bujo.blackcat.dev>`. The unchanged secret remains in `op://Personal/bujo-production/credential`; Kamal resolves it without committing or printing it. The verified root domain remains temporarily and Press Start configures its own subdomain/key only in its project. This supersedes shared `blackcat.dev` sending. |
| 2026-08-29 | **Authentication Step 1 proposed as the current planning detour; implementation not authorized.** The contract adds Resend Action Mailer delivery and scanner-safe, 15-minute, generation-invalidated magic links while retaining password rollback. It recommends magic email as the default with password one tap away and no premature passkey control. Contract: `docs/slices/auth-1-resend-and-magic-links.md`; review board: `mockups/MagicLinkTransition.dc.html`. PWA 1.6 remains intact but parked as proposed until this detour is resolved. |
| 2026-08-29 | **Authentication Step 1 approved; implementation remains separately gated.** Dan accepted magic-email-first, one-tap password fallback, exact transition copy, 15-minute generation-invalidated globally single-use tokens, fragment staging plus explicit POST, enumeration/rate limits, and the Resend failure boundary. He separately authorized moving the canonical web origin to `bujo.blackcat.dev` now; that operational cutover does not start authentication implementation or a swarm. |
| 2026-08-29 | **`bujo.blackcat.dev` is the live canonical production origin.** Cloudflare DNS points the DNS-only A record to `174.138.85.202`; Kamal proxy obtained working TLS and serves the unchanged deployed image `48631001093af1ebd2fb323a0242905da11f1b1c`. Root redirects to `/session/new` on the new host and `/up` returns 200. The old proxy host was removed and the exact `bujo.questlog.dev` A record retired; no application build, code release, or swarm occurred. The live magic-link round trip remains gated on Step 1 implementation. |
| 2026-08-29 | **Authentication Step 1 implementation authorized.** After the canonical-origin cutover and successful production password re-proof, Dan authorized committing and pushing the planning baseline and launching `six-cg` for the approved Resend/magic-link contract. Work remains isolated in `cg-*` role worktrees; terminal integration, production deployment, provider delivery, and the live magic-link round trip remain separately gated. |
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
- [x] **1.5 The book-faithful realignment** ✅ (completed 2026-08-29; see decisions log +
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
      - [x] **1.5.3a Phone capture and ritual clarity** ✅ (2026-08-26) — the
            real blank canvas is writable on Daily, Monthly Tasks, Future, and
            Index; Calendar row capture is primary with a separate Daily
            chevron; Future residents align and reuse the shared Task/Event
            controls; both empty migration stages require explicit Scan and
            Finish gestures. Contract at
            `docs/slices/1.5.3a-phone-capture-and-ritual-clarity.md`; approved
            review mock at `mockups/PhoneCaptureCorrection.dc.html`. Terminal
            candidate `92c43e2`; merged-tree receipts: 201 fast tests / 3412
            assertions, 61 system tests / 1383 assertions, RuboCop clean.
      - [x] **1.5.3b Dogfood entry corrections** ✅ (2026-08-26) — the empty
            Daily message is writable; ordinary Monthly pages offer all three
            capture kinds; constrained live-entry correction and same-month
            Calendar scheduling are available; the native date input, row
            alignment, and lifecycle ink are usable; ritual actions offer one
            append-only immediate Undo; and newly created unindexed Collections
            expose their next deliberate step. Entry deletion remains deferred.
            Contract at
            `docs/slices/1.5.3b-dogfood-entry-corrections.md`; approved review
            board at `mockups/PhoneDogfoodCorrections.dc.html`. Terminal
            candidate `dc2153c`; merged-tree receipts: 230 fast tests / 3822
            assertions, 81 system tests / 1640 assertions, RuboCop clean.
      - [x] **Tailwind CSS v4 presentation migration** ✅ (2026-08-27) —
            presentation-only infrastructure interlude preserving the exact
            1.5.3b product/phone behavior. The app now uses exact-pinned
            `tailwindcss-rails` 4.6.0 and `tailwindcss-ruby` 4.3.3, no Node,
            no Preflight, no default theme, and one compiled bundle with
            component/page ownership. T0 receipt at
            `docs/tailwind-v4-baseline/README.md`; landed contract at
            `docs/slices/tailwind-v4-presentation-migration.md`. Terminal
            candidate `8d7ccbd`; merged-tree receipts: 265 fast tests / 6424
            assertions, 94 system tests / 15445 assertions, RuboCop clean.
      - [x] **Post-Tailwind Calendar alignment correction** ✅ (2026-08-27):
            real-device dogfooding found the resident's first-line ink above
            the centered Calendar date row. The bounded Calendar-only fix
            aligns date, weekday, glyph, first text line, and metadata within
            4 CSS px on both phone profiles while wrapped ink grows downward.
            Merged-tree receipts: 265 fast tests / 6434 assertions, 95 system
            tests / 15234 assertions, RuboCop clean.
      - [x] **1.5.4 Daily Reflection** ✅ (2026-08-28) — a current-day,
            no-schema AM/PM reference lens. Morning captures overnight
            thoughts and reviews current-month dated-page tasks through the
            existing `*` priority; Evening captures missed entries and shows
            today's complete Daily trees with focused Complete, Strike, and
            Schedule gestures plus quiet derived progress. Contract:
            `docs/slices/1.5.4-daily-reflection.md`; review board:
            `mockups/DailyReflection.dc.html`. Terminal candidate `c2127b5`;
            merged-tree receipts: 286 fast tests / 6907 assertions, 112 system
            tests / 16797 assertions, and RuboCop clean over 114 files.
      - [x] **1.5.2a Index source correction** ✅ (2026-08-28) — make Custom
            Collection creation and server-owned Index registration atomic;
            backfill existing kept unindexed pages deterministically; remove
            unindex/re-register and Open by Topic; preserve append order,
            stable URLs, tenant scoping, and every Entry invariant. Approved
            contract: `docs/slices/1.5.2a-index-is-the-collection-register.md`;
            review board: `mockups/IndexSourceCorrection.dc.html`. Terminal
            candidate `12f8164`; merged-tree receipts: 281 fast tests / 6644
            assertions, 112 system tests / 16796 assertions, and RuboCop clean
            over 116 files. The completed `cg-*` swarm is retired.
      - [x] **1.5.5 Core notation and hierarchy fidelity** ✅ (2026-08-29) —
            the landed contract
            adds the `!` inspiration signifier and gates a master task's
            completion until every kept subtask chain ends done or struck.
            It also closes the Rails app's missing hierarchy-writing gap with
            an explicit `Add below…` gesture using the shared three-kind
            rapid-log anatomy. Keep the parked date-grammar expansion
            separate. Landed contract:
            `docs/slices/1.5.5-core-notation-and-hierarchy-fidelity.md`;
            review board: `mockups/CoreNotationHierarchy.dc.html`. Terminal
            candidate `70b9c742`; integration commit `867e3b28`; merged-tree
            receipts: 309 fast tests / 6916 assertions, 124 system tests /
            15661 assertions, RuboCop clean over 121 files, and terminal
            RapidLog mutation 1167/1167.
- [ ] **1.6 Installable PWA and truthful offline boundary** — proposed,
      parked during the authentication detour and not authorized. Activate an
      origin-neutral manifest and minimal root service worker, replace
      placeholder icons, vendor the seven live font families, and provide a
      neutral system-themed Offline page after an actual page-fetch failure.
      Do not cache journal pages or add offline capture/outbox/sync behavior.
      Proposed contract:
      `docs/slices/1.6-installable-pwa.md`; review board:
      `mockups/PwaInstallOffline.dc.html`. First production enablement is now
      settled on the canonical `bujo.blackcat.dev` origin; approval must still
      settle the icon. (Deploy, Kamal, and Litestream landed early with 1.3 on
      2026-08-24 per the dogfood-first ruling; Phase 1 is built under real use.)
- [ ] **Authentication Step 1 - Resend delivery and magic links** — approved
      and authorized for implementation through the `six-cg` swarm. Configure
      the verified Resend sender behind Action
      Mailer and add scanner-safe, 15-minute, generation-invalidated,
      single-use email sign-in for known accounts. Keep password sign-in/reset
      as rollback and show no unavailable passkey. The independently authorized
      canonical-origin cutover completed first, outside this implementation.
      Approved contract: `docs/slices/auth-1-resend-and-magic-links.md`;
      review board: `mockups/MagicLinkTransition.dc.html`. Terminal integration
      and deployment remain separately gated.

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
- Historical domain: **questlog.dev** purchased 2026-08-24 (Cloudflare Registrar;
  DNS at Cloudflare). Zone carries the no-email lockdown (SPF `-all`,
  DMARC reject, empty wildcard DKIM, null MX) as of 2026-08-24.
  `bujo.questlog.dev` was live from 2026-08-24 through 2026-08-29; its
  application A record and Kamal proxy host are now retired. Zone-scoped DNS
  token at `~/.config/cloudflare/questlog-dns-token` (mode 600, never
  committed). **Replacement acquired 2026-08-26 and canonical cutover
  completed 2026-08-29:** `blackcat.dev`, with Bujo live at
  `https://bujo.blackcat.dev` and Press Start likely at
  `lift.blackcat.dev`. Root Resend records were verified 2026-08-26;
  `bujo.blackcat.dev` was independently verified in `us-east-1` on 2026-08-29.
  Its DNS-only A record points to `174.138.85.202`; TLS, the canonical redirect,
  and `/up` were verified before the old record was removed. This supersedes
  the earlier thought that Press Start would need its own
  registrable domain; its hostname remains tentative until Press Start's own
  deployment decision
- Transactional email: **Resend selected 2026-08-26; app-specific boundary
  adopted 2026-08-29**, using its HTTPS API because DigitalOcean blocks
  outbound SMTP. Bujo owns verified `bujo.blackcat.dev`, sends as
  `Bujo <sign-in@bujo.blackcat.dev>`, and has a Sending-only key restricted to
  that exact domain. The unchanged secret remains in 1Password and Kamal
  resolves `op://Personal/bujo-production/credential`. Tracking is disabled,
  monitoring-mode DMARC remains installed, and the root sending domain is kept
  temporarily. Press Start gets its own verified subdomain/key later. Full
  cross-app plan and gates:
  `docs/resend-transactional-email.md`
- Packwerk (boundaries bar): deferred until the app has a boundary
  worth defending (slice 1.1 added a require-graph boundary test for
  `lib/bujo/` in its place)
- ~~Project skills~~ done 2026-08-24: `.claude/skills/bujo-conventions`
  and `.claude/skills/testing`
- Fonts are still served from Google Fonts; proposed 1.6 vendors the seven
  live families locally and removes the stale `TODO(1.7)`. Newsreader remains
  absent after the accepted all-sans hand replacement
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
  provider foundation and Kamal secret seam are complete. Step 1 is approved
  at `docs/slices/auth-1-resend-and-magic-links.md` and authorized for the
  isolated `six-cg` implementation run. Terminal integration and deployment
  remain separately gated. The canonical-origin cutover completed independently
  on 2026-08-29 without an application release. Proposed 1.6 remains parked.
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
