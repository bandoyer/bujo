# Bujo — living plan

**This document is the project's source of truth for status and intent.
Update it whenever a slice lands, a decision is made, or the plan
changes.** A future session (human or agent) should be able to read this
file top to bottom and know exactly where things stand and what happens
next.

> **Status: Phase 0 complete — next up: slice 1.1, the rapid-log parser
> (spec not yet written).**

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
| 2026-08-24 | Mobile look: paper-and-ink direction from the mocks (dark "terminal-kin" alt not chosen for v1) |
| 2026-08-24 | Host: DigitalOcean (Hetzner's 2026 price hikes closed the gap; DO wins on stability and smoothness). Droplet size decided at deploy time — 2 GB is enough for bujo alone, 4 GB once press-start shares the box |
| 2026-08-24 | Umbrella domain: **questlog.dev** — a quest log is both a gaming term and a journal, covering the whole portfolio. Apps on subdomains: `bujo.questlog.dev`, `pressstart.questlog.dev`. Availability confirmed via registry RDAP 2026-08-24; purchase pending |

## Phases and slices

### Phase 0 — scaffold ✅ (2026-08-24)

- [x] Rails 8.1 on Ruby 4.0, omakase defaults, no CSS framework
- [x] Session auth (Rails 8 generator), single seeded user, root placeholder
- [x] Quality bars wired: COVERAGE=1 → lcov → crap4rb; rubocop-minitest; jscpd
- [x] Swarm config: `six-all-models-review` pack + ruby toolset + project article
- [x] This plan

### Phase 1 — the journal (web app usable end-to-end)

- [ ] **1.1 Rapid-log parser** — pure Ruby in `lib/`: the bullet grammar
      (`•` task, `x` done, `>` migrated, `<` scheduled, `○` event, `–`
      note, `*` priority) plus natural-language dates ("tomorrow",
      "sep 9"). The shared core; hardest-tested code in the app.
      Mutation testing (mutant-minitest) enters the bars here.
- [ ] **1.2 Entries & collections** — UUIDv7 ids, logs-as-date-queries,
      append-only migration chain, soft deletes, `hlc`/`server_seq`
      columns dormant. Schema per ARCHITECTURE.md.
- [ ] **1.3 Daily Log** — Hotwire view + rapid-log bar per the mobile
      mock; entry actions (done, migrate, schedule, strike). Root moves
      here from the sign-in placeholder.
- [ ] **1.4 Monthly + Future Logs** — calendar/tasks toggle per mock.
- [ ] **1.5 Migration ritual** — card-per-task review flow per mock.
- [ ] **1.6 Index** — search across collections and entries.
- [ ] **1.7 PWA + deploy** — manifest/service worker, Kamal to the VPS,
      Litestream backup. **Deploy target: after 1.3, not 1.7** — dogfood
      as soon as the Daily Log works; 1.4–1.6 get built under real use.

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

- mutant licensing: free for open source — repo is public, so should be
  fine; confirm when wiring mutant-minitest in slice 1.1
- Droplet: DigitalOcean chosen, not yet provisioned; needed by slice
  1.3's deploy. Litestream backups go to a non-DO object store (R2 or
  B2) so backups don't share the host's failure domain
- Domain: **questlog.dev** purchased 2026-08-24 (Cloudflare Registrar;
  DNS at Cloudflare). Zone carries the no-email lockdown (SPF `-all`,
  DMARC reject, empty wildcard DKIM, null MX) as of 2026-08-24; app
  records come with slice 1.3's deploy. A zone-scoped DNS API token is
  saved locally at `~/.config/cloudflare/questlog-dns-token` (mode 600,
  never committed) for driving deploy-day DNS. The same Cloudflare
  account will hold the R2 bucket for Litestream backups in 1.7.
  press-start gets its own domain later if it launches publicly
- Packwerk (boundaries bar): deferred until the app has a boundary
  worth defending
- Passkeys for web auth: nice-to-have after phase 1 (generator's
  email/password stands in until then)

## How to resume (for a future session)

1. Read this file, then `ARCHITECTURE.md`.
2. `git log --oneline -15` for what actually landed.
3. Check the **Status** line above; if a slice is mid-flight, its spec
   is in `docs/slices/` and the swarm state is visible via `swarm status`
   / herdr.
4. Keep the loop: spec → swarm → review. Update this file when anything
   changes.
