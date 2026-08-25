# Handoff — mid-slice 1.5.1, the book-faithful realignment (2026-08-24, late)

For the next operator session — **any agent** (Claude, Codex, Grok,
or a human). Everything needed is in this repo's documents; nothing
depends on a particular assistant's memory or tooling. `PLAN.md`
stays the living plan; this file is the parked-state detail. Delete
it once 1.5.1 is merged and the follow-ups below are done.

## The one sentence that governs everything

**Dan's ruling: v1 adheres to the source material — Ryder Carroll's
*The Bullet Journal Method*, Parts II–III — as closely as possible.
Start minimal and true to the book; add digital "smartness" later
only where real dogfooding proves the pain.** When any design
question arises, the order of authority is: `docs/METHOD.md` (the
book study + rulings) → `PLAN.md` decisions log → `ARCHITECTURE.md`
(sync + schema semantics) → the relevant `docs/slices/*.md` spec.

## Tonight's findings (why the realignment exists)

- Dogfooding caught the drift: entries were *appearing* on the
  Monthly Tasks view because a scope derived them there — nobody
  placed them. The book's Monthly Tasks page is a curated mental
  inventory; its Future Log is a queue that only migration empties;
  nothing in the system moves or surfaces on its own. **The friction
  is the feature.**
- The operator read Parts II–III (PDF in `~/Downloads/The Bullet
  Journal Method_ Trac - Carroll_ Ryder.pdf`; `pdftotext` extracts
  cleanly) and wrote `docs/METHOD.md` — the binding method
  reference, including the five divergences found and Dan's rulings.
- Rulings that followed (all in PLAN's decisions log, dated
  2026-08-24): **everything is a page** (calendar included — Option
  B, fully manual placement); **write-on-page narrows to today and
  past**; **route by gesture, not by parsing** (the rapid-log
  grammar is FROZEN at its 1.1 forms — the drafted expansion is
  parked unbuilt at `docs/slices/1.4.3-*`, kept as the road not
  taken); model-first sequencing.
- `ARCHITECTURE.md` was revised accordingly (operator-approved):
  pages are **immutable columns** (`page_kind`, `page_on`), never
  container tables; movement is append-only migration via the
  existing `migrated_from_id` successor chain; the
  no-container-conflict sync property survives because placement
  never mutates.

## Exact state

- **Production** (https://bujo.questlog.dev) runs through slice
  1.4.1. Committed but NOT deployed: the polish batch (lines off,
  dark dot grid, centered month header, Future eyebrow removed).
  Deploys are `kamal deploy` from the repo root — **Dan runs
  deploys himself; hand him the command, don't run it.**
- **main is ahead of origin** from the 1.4 spec onward (~20
  commits). Push only when Dan says push.
- **The swarm is DOWN and slice 1.5.1 must be re-kicked.** The
  chain was launched 2026-08-24 ~22:00 and ran ~1h15m before the
  night's session teardown killed the herdr workspace, handoffd,
  the role worktrees, AND the role branches (`swarm down` was then
  run to clean the half-state). One piece of work was recovered
  from dangling objects and pinned to the branch
  **`recovered/1.5.1-accepted-spec`** (`6da3ba2`): the specifier's
  acceptance commit, which amends the 1.5.1 spec with **seven
  in-flight rulings** — read it; the next chain's specifier can
  fast-forward from it, or the operator folds those rulings into
  the committed spec first. Coder work-in-progress was lost
  (uncommitted; cheap to redo). Spec:
  `docs/slices/1.5.1-the-page-model.md`.

## To resume slice 1.5.1

1. From a **herdr session in this repo** (herdr must be running in
   the user's terminal): `swarm up`, answer any pane startup
   dialogs, then `swarm bootstrap`.
2. Re-kick with the same shape of prompt (specify and drive
   `docs/slices/1.5.1-the-page-model.md`; METHOD.md and the revised
   ARCHITECTURE.md bind; lib/ untouched, mutation exactly
   1105/1105; "nothing may surface anywhere a hand did not place
   it"), and point the specifier at
   `recovered/1.5.1-accepted-spec` so the seven rulings aren't
   re-derived.
3. Arm `script/watch-swarm.sh` in the background — exits 0 printing
   the qa terminal broadcast (a
   `from_qa_to_specifier_coder_cleaner_architect_hardener`
   delivered line in `.swarmforge/daemon/handoffd.log`), exits 1 on
   30 quiet minutes. On a stall: a targeted `swarm prompt <role>`
   nudge, never a restart. `swarm status` / `swarm logs 20` show
   state. Lesson learned: daemons started from an assistant
   session's shell die with that session — prefer launching
   `swarm up` from the user's own herdr terminal.

## When 1.5.1 reaches its qa broadcast

Operator review before merge, per the established protocol:

1. Check out the converged role branch (`git switch -c review/1.5.1
   swarmforge-all-qa`), re-run every bar yourself: `bin/rails test`,
   `bin/rails test:system`, `bin/rubocop`, `COVERAGE=1 bin/rails
   test` + `crap4rb --lcov coverage/lcov.info app/ lib/`, `npx jscpd
   --min-tokens 50 app/ lib/`, and `bundle exec mutant run
   --integration minitest -- 'Bujo::RapidLog*'` — the parser is out
   of scope, so mutation must be EXACTLY 1105/1105.
2. Boundary: the diff must not touch `lib/` or `Gemfile`; measure
   path scope from the slice's accepted-spec commit (docs/slices is
   specifier-owned).
3. Adversarial probes in the 1.2 style: raw-SQL and mass-assignment
   attacks on placement immutability; double-move chain attacks
   (the unique index on `migrated_from_id` must hold); residency
   checks (a daily entry with a future `occurs_on` appears ONLY on
   its daily page).
4. Hand-mutations (3+) with grep-verified application before
   trusting any kill; screenshot the changed screens in both themes
   (headless Chrome via a throwaway system test is the pattern —
   see git history for `operator_screenshot_test.rb` examples).
5. Merge `--no-ff` with a review-record message; run the suite on
   main; mark PLAN.
6. **Post-merge follow-ups, in order**: (a) update
   `.claude/skills/bujo-conventions/SKILL.md` — the "Logs are date
   queries, not containers" invariant becomes "Logs are residency
   scopes over immutable page columns (`page_kind`/`page_on`);
   never a container table; placement is set at creation and moved
   only by append-only migration"; (b) hand Dan `kamal deploy`;
   (c) after deploy, hand-fix the few 1.4.1-era future month-adds —
   post-migration they are daily-page rows with `page_on` in the
   future; via `kamal console`, move each to the future page
   (`page_kind: "future"`, `page_on: nil`, keep `occurs_on`) —
   walk Dan through it or do it with his go-ahead; (d) spec
   **1.5.2 the migration ritual** (mock exists: "Mobile ·
   Migration" artboard on the mockups canvas) — the monthly-setup
   flow: card-per-task review of the old month, strike/carry
   decisions, and the future-log scan-in.

## The working loop (unchanged, agent-agnostic)

Spec → swarm → review → merge → Dan deploys. Kickoffs to the
specifier say **"specify and drive"**, never "implement". Operator
spec commits are docs-only; PLAN/other operator files go in
separate commits (role contracts validate handoff commits by path).
UI changes are mocked first on a design canvas and Dan picks by eye
(canvases: mockups `749c4391-…`, task actions `016d3b48-…`,
placement gestures `9299895f-…`, hand lettering `31d0cb57-…` — all
under claude.ai/code/artifact/). Trivial approved polish goes in
directly as operator commits with tests updated, never weakened.

## Parked, deliberately

- **Settings & session mini slice**: /settings page, sign-out
  button (none exists!), theme/hand toggles there, maybe a lines
  toggle. Next UI slice after the realignment.
- **"Place from today"** artboard (placement-gestures canvas):
  partially realized by 1.5.1's event/note `Schedule…`; the rest
  waits.
- **Grammar expansion** (`docs/slices/1.4.3-*`): parked unbuilt on
  principle. Parse-preview deferred with it.
- **Passwordless auth** (passkeys-first; questlog.dev has a
  no-email lockdown — see PLAN open items). **Multi-user**
  assessment in PLAN open items. **Index** is slice 1.6; **PWA +
  font vendoring** 1.7.

## Infra quick facts (details in PLAN open items)

Droplet `bujo` (DO nyc3, 174.138.85.202), Kamal + GHCR
(`gh` CLI must hold `write:packages`), Litestream → R2 bucket
`bujo-litestream`, DNS via the token at
`~/.config/cloudflare/questlog-dns-token`. `doctl` is authed.
Costs: ~$12/mo flat. `kamal logs` / `kamal console` for prod.
