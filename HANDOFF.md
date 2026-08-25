# Handoff — slice 1.5.1 approved and ready to swarm (2026-08-25)

For the next operator session — **any agent** (Claude, Codex, Grok,
or a human). Everything needed is in this repo; nothing depends on an
assistant's memory or tooling. `PLAN.md` is the living plan and this
file records the parked operational state. Keep it until 1.5.1 lands
and its follow-ups are complete.

## The one sentence that governs everything

**Dan's ruling: v1 adheres to Ryder Carroll's *The Bullet Journal
Method*, Parts II–III, as closely as possible. Start minimal and true
to the book; add digital smartness only where dogfooding proves the
pain.** When a design question arises, authority is:
`docs/METHOD.md` (source study + product rulings) → `PLAN.md` decisions
log → `ARCHITECTURE.md` (schema/sync semantics) → the relevant
`docs/slices/*.md` spec.

## Why the realignment exists

- Dogfooding caught the drift: entries appeared on Monthly Tasks
  because a date scope derived them there. The book's Tasks page is a
  curated mental inventory and its Future Log is a queue. The friction
  of deliberate rewriting is the method, not a UX defect to automate.
- Parts II–III were reviewed from
  `~/Downloads/The Bullet Journal Method_ Trac - Carroll_ Ryder.pdf`.
  `docs/METHOD.md` is the binding project interpretation of that study.
- The first Fable handoff and accepted-spec recovery had the right page
  model but several overcorrections: Future meant after-today instead
  of outside-current-month; notes gained an invalid Future action;
  future Monthly pages were left too writable; "no derived surfaces"
  accidentally banned legitimate review lenses; and raw-SQL placement
  immutability was treated as an application promise.
- The current docs-only correction resolves those issues and moves the
  missing method spine ahead of convenience work: Custom Collections +
  deliberate Index, monthly migration, daily Reflection, then `!` and
  master-task completion gating.

## Exact state

- **Production** at https://bujo.questlog.dev runs through 1.4.1.
  The approved polish batch (lines off, dark dot grid, centered month
  header, Future eyebrow removed) is committed but not deployed.
  Deploys are `kamal deploy` from the repo root; **Dan runs deploys
  himself. Hand him the command; do not run it.**
- **Dan approved the revised 1.5.1 spec. The swarm is DOWN and ready
  for him to start from his own herdr terminal.** The prior chain died
  with its assistant session; its herdr workspace, daemons, role
  worktrees, and role branches were cleaned up. Coder work was
  uncommitted and lost; there is no partial implementation to preserve.
- `recovered/1.5.1-accepted-spec` still pins dangling commit `6da3ba2`
  as historical evidence. **Do not merge or fast-forward from it.** Its
  useful acceptance rulings have been folded into the current spec;
  its after-today boundary, note-to-Future action, and raw-SQL review
  bar are superseded.
- The source-alignment pass is committed and pushed on `main` at
  `8930935`; the acceptance-state update is docs-only as well. The
  repository is otherwise clean. No app, migration, test, parser, or
  swarm implementation exists for 1.5.1 yet.

## Swarm restart

1. Start herdr and `swarm up` from **Dan's own terminal session**, then
   answer pane startup dialogs and run `swarm bootstrap`. Daemons
   launched from a short-lived assistant shell can die with that shell.
2. Kick the chain with **"specify and drive
   `docs/slices/1.5.1-the-page-model.md`"**. State that METHOD, PLAN,
   and ARCHITECTURE bind in that order; `lib/` and `Gemfile` are out of
   scope; parser mutation stays exactly 1105/1105. Do not point the
   specifier at the recovered branch as a starting point.
3. Arm `script/watch-swarm.sh` in the background. It exits 0 when the
   QA terminal broadcast reaches handoffd and 1 after 30 quiet minutes.
   On a stall, use a targeted `swarm prompt <role>` nudge, never a
   restart. `swarm status` and `swarm logs 20` show state.

## Review when QA broadcasts

1. Check out the converged role branch (`git switch -c review/1.5.1
   swarmforge-all-qa`) and independently run `bin/rails test`,
   `bin/rails test:system`, `bin/rubocop`, `COVERAGE=1 bin/rails test`
   plus `crap4rb --lcov coverage/lcov.info app/ lib/`, `npx jscpd
   --min-tokens 50 app/ lib/`, and `bundle exec mutant run
   --integration minitest -- 'Bujo::RapidLog*'`. Parser mutation must
   remain exactly 1105/1105.
2. Measure path scope from the accepted-spec commit. The diff may touch
   the spec-owned paths only and must not touch `lib/` or `Gemfile`.
3. Probe the real boundaries: domain/API and mass-assignment placement
   immutability; page-kind/root-kind compatibility; injected-`as_of`
   month edges; overdue Future visibility; pure residency; and
   double-move refusal. Use raw SQL to challenge the database's unique
   successor index, **not** to demand a nonexistent SQL placement rule.
4. Apply at least three grep-verified hand mutations before trusting
   kills. Visually verify all changed screens in both themes and two
   hands using the established throwaway system-test screenshot pattern.
5. Merge `--no-ff` with a review-record message, rerun the suite on
   main, and mark PLAN.

## Post-merge follow-ups, in order

1. Update the tracked `.claude/skills/bujo-conventions/SKILL.md`
   invariant from date queries to residency scopes over immutable
   `page_kind`/`page_on` placement and append-only movement. Refresh the
   local `.agents` mirror too if it remains the active Codex skill.
2. Hand Dan `kamal deploy`; do not deploy for him.
3. After deploy, inspect the few 1.4.1-era Future month-add rows. They
   backfilled as Daily residents. With Dan's go-ahead, deliberately
   move the intended rows to `page_kind: "future"`, `page_on: nil`,
   preserving `occurs_on`; do not bulk-guess.
4. Spec **1.5.2 Custom Collections + deliberate Index**. It must be a
   minimal writable Collection page plus explicit manual Index
   registration, with Daily Logs excluded and broad search deferred.

## Working loop

Spec → swarm → operator review → merge → Dan deploys. Kickoffs say
**"specify and drive"**, never "implement". Operator specs and plan
commits stay docs-only; pack roles obey their accepted slice scope. UI
changes are mocked first and Dan picks by eye. Existing canvases:
mockups `749c4391-…`, task actions `016d3b48-…`, placement gestures
`9299895f-…`, hand lettering `31d0cb57-…`. Trivial approved polish may
land directly with tests updated, never weakened.

## Deliberately deferred

- **Settings/session polish:** `/settings`, sign-out, preference
  controls, perhaps line toggle. It follows the method spine rather
  than interrupting it.
- **"Place from today" mock:** its Future scheduling portion is now
  specified narrowly for tasks/events; the coherent review experience
  belongs to 1.5.4 Daily Reflection.
- **Grammar expansion** (`docs/slices/1.4.3-*`) and parse preview remain
  parked. The narrow `!` source signifier is a separate 1.5.5 change,
  not authorization to revive date parsing.
- **Broad Index search** waits for dogfooding. The 1.5.2 Index is
  deliberately maintained, not an automatic search result page.
- **Yearly migration** should be specified after the monthly practice
  is proven. Generic Collections and Reflection carry the rest of Part
  III; do not create a bespoke subsystem for each chapter.
- **Passwordless auth** and multi-user assessment remain in PLAN open
  items. **PWA + font vendoring** is now 1.6.

## Infra quick facts

Droplet `bujo` (DigitalOcean nyc3, 174.138.85.202), Kamal + GHCR
(`gh` CLI needs `write:packages`), Litestream → R2 bucket
`bujo-litestream`, DNS token at
`~/.config/cloudflare/questlog-dns-token`. `doctl` is authenticated.
Cost is about $12/month flat. Use `kamal logs` / `kamal console` for
production diagnostics.
